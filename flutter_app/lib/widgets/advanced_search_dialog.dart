import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/book_provider.dart';
import '../providers/search_provider.dart';
import '../models/book.dart';
import '../services/api_service.dart';

class AdvancedSearchDialog extends StatefulWidget {
  const AdvancedSearchDialog({super.key});

  @override
  State<AdvancedSearchDialog> createState() => _AdvancedSearchDialogState();
}

class _AdvancedSearchDialogState extends State<AdvancedSearchDialog> {
  final _searchController = TextEditingController();
  late List<String> _categoryNames;
  bool _categoriesLoading = false;

  void _resetAll(SearchProvider provider) {
    _searchController.clear();
    provider.resetFilters();
    provider.clearSearch();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // Defaults so the dropdown is usable instantly.
    _categoryNames = [
      'Fiction',
      'Non-Fiction',
      'Science',
      'Technology',
      'History',
      'Biography',
      'Literature',
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategories();
    });
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() => _categoriesLoading = true);

    BookProvider? bookProvider;
    try {
      bookProvider = context.read<BookProvider>();
    } catch (_) {
      bookProvider = null;
    }

    try {
      final fromApi = await ApiService.getCategories();
      final names = <String>{
        ..._categoryNames,
        ...fromApi.map((c) => c.name).where((n) => n.trim().isNotEmpty),
      };

      // Also include any categories currently present on loaded books.
      // This ensures the dropdown reflects real data even if categories table is out of sync.
      try {
        for (final book in bookProvider?.books ?? const <Book>[]) {
          final cat = (book.category ?? '').trim();
          if (cat.isNotEmpty) names.add(cat);
        }
      } catch (_) {
        // If BookProvider is not in scope, ignore.
      }

      final sorted = names.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _categoryNames = sorted;
      });
    } catch (_) {
      // Keep defaults on error.
    } finally {
      if (mounted) setState(() => _categoriesLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 900;
    final maxWidth = (isSmallScreen ? screenSize.width * 0.95 : 900).toDouble();
    final maxHeight = (isSmallScreen ? screenSize.height * 0.95 : 800)
        .toDouble();

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Advanced Search',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Search & Filters
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search for books...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _performSearch,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (_) => _performSearch(),
                    ),
                    const SizedBox(height: 20),
                    // Filters row
                    Consumer<SearchProvider>(
                      builder: (context, provider, _) {
                        final categoryOptions = <String, String>{
                          'all': 'All Categories',
                        };
                        for (final name in _categoryNames) {
                          categoryOptions[name] = name;
                        }
                        // Ensure current selection always remains selectable.
                        if (provider.categoryFilter != 'all' &&
                            !categoryOptions.containsKey(
                              provider.categoryFilter,
                            )) {
                          categoryOptions[provider.categoryFilter] =
                              provider.categoryFilter;
                        }

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildFilterDropdown(
                              'Search In',
                              provider.searchType,
                              {
                                'all': 'All Fields',
                                'title': 'Title',
                                'author': 'Author',
                                'isbn': 'ISBN',
                              },
                              (value) => provider.setSearchType(value ?? 'all'),
                            ),
                            _buildFilterDropdown(
                              'Category',
                              provider.categoryFilter,
                              categoryOptions,
                              (value) =>
                                  provider.setCategoryFilter(value ?? 'all'),
                            ),
                            _buildFilterDropdown(
                              'Availability',
                              provider.availabilityFilter,
                              {
                                'all': 'All',
                                'available': 'Available',
                                'borrowed': 'Borrowed',
                              },
                              (value) => provider.setAvailabilityFilter(
                                value ?? 'all',
                              ),
                            ),
                            _buildFilterDropdown(
                              'Sort By',
                              provider.sortBy,
                              {
                                'title': 'Title',
                                'author': 'Author',
                                'year': 'Year',
                                'popularity': 'Popularity',
                              },
                              (value) => provider.setSortBy(value ?? 'title'),
                            ),
                            TextButton.icon(
                              onPressed: () => _resetAll(provider),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Reset Filters'),
                            ),
                            if (_categoriesLoading)
                              const Padding(
                                padding: EdgeInsets.only(left: 6, top: 2),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Results
              Flexible(
                child: Consumer<SearchProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (provider.lastQuery.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Enter a search term',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Use filters to narrow down your search',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (provider.searchBooks.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.search_off_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No results for "${provider.lastQuery}"',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Try different keywords or adjust filters',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Text(
                            '${provider.searchBooks.length} results found',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: provider.searchBooks.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.2),
                            ),
                            itemBuilder: (context, index) =>
                                _buildBookTile(provider.searchBooks[index]),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              // Footer
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String currentValue,
    Map<String, String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          isDense: true,
          items: options.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: onChanged,
          hint: Text(label),
        ),
      ),
    );
  }

  Widget _buildBookTile(Book book) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 50,
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        clipBehavior: Clip.antiAlias,
        child: book.coverImage != null && book.coverImage!.isNotEmpty
            ? Image.network(
                ApiService.resolvePublicUrl(book.coverImage!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildBookPlaceholder(),
              )
            : _buildBookPlaceholder(),
      ),
      title: Text(
        book.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('by ${book.author}'),
          const SizedBox(height: 4),
          Row(
            children: [
              if (book.category != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    book.category!,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              if (book.yearPublished != null)
                Text(
                  '${book.yearPublished}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
            ],
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: book.availableCopies > 0
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              book.availableCopies > 0 ? 'Available' : 'Borrowed',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: book.availableCopies > 0 ? Colors.green : Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${book.availableCopies}/${book.totalCopies} copies',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookPlaceholder() {
    return Center(
      child: Icon(
        Icons.book,
        size: 24,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      context.read<SearchProvider>().advancedSearch(query);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
