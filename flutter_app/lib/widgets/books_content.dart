import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/book_provider.dart';
import '../providers/issue_provider.dart';
import '../models/book.dart';
import '../widgets/book_dialog.dart';
import '../services/api_service.dart';
import '../utils/hindi_text.dart';
import '../utils/error_utils.dart';

class BooksContent extends StatefulWidget {
  const BooksContent({super.key});

  @override
  State<BooksContent> createState() => _BooksContentState();
}

class _BooksContentState extends State<BooksContent> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;
  final Set<int> _selectedBookIds = <int>{};
  StreamSubscription<void>? _dataChangedSub;

  bool _containsDevanagari(String text) {
    return RegExp(r'[\u0900-\u097F]').hasMatch(text);
  }

  bool _looksLikeLegacyHindi(String text) {
    final s = text.trim();
    if (s.isEmpty) return false;
    if (_containsDevanagari(s)) return false;

    final letters = RegExp(r'[A-Za-z]').allMatches(s).length;
    if (letters < 6) return false;
    final special = RegExp(r'[;*]').allMatches(s).length;
    if (special < 1) return false;
    final ratio = letters / s.length.clamp(1, 1 << 30);
    return ratio >= 0.55;
  }

  TextStyle _textStyleForHindi(String text, TextStyle base) {
    final defaultSize = DefaultTextStyle.of(context).style.fontSize ?? 14;
    final effectiveSize = base.fontSize ?? defaultSize;

    // If the content is already Unicode Hindi, just help Windows pick a good font.
    if (_containsDevanagari(text)) {
      return base.copyWith(
        // Devanagari often looks optically smaller at the same point size.
        fontSize: (effectiveSize * 1.12).clamp(10, 30).toDouble(),
        fontFamilyFallback: const [
          'Nirmala UI',
          'Mangal',
          'Noto Sans Devanagari',
        ],
      );
    }

    // If it looks like legacy Hindi (KrutiDev-style), try to render it using the bundled font
    // with fallback to system fonts when not available.
    if (_looksLikeLegacyHindi(text)) {
      return base.copyWith(
        fontSize: (effectiveSize * 1.10).clamp(10, 30).toDouble(),
        fontFamily: 'KrutiDev', // Bundled font
        fontFamilyFallback: const [
          'KrutiDev',
          'Kruti Dev 010',
          'NotoSansDevanagari',
          'Nirmala UI',
          'Mangal',
        ],
      );
    }

    return base;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBooks();
    });
    // Listen for data changes from other components
    _dataChangedSub = ApiService.dataChangedStream.listen((_) {
      _loadBooks();
    });
  }

  void _loadBooks() {
    try {
      if (kDebugMode) debugPrint('DEBUG [BooksContent]: Calling loadBooks');
      context.read<BookProvider>().loadBooks().catchError((error) {
        if (kDebugMode) {
          debugPrint(
            'DEBUG [BooksContent]: Error caught in catchError: $error',
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading books: $error'),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DEBUG [BooksContent]: Error in try block: $e');
      }
    }
  }

  List<String> getUniqueCategories(List<Book> books) {
    final predefinedCategories = [
      'Fiction',
      'Non-Fiction',
      'Science',
      'History',
      'Biography',
      'Literature',
      'Philosophy',
      'Psychology',
      'Art',
      'Music',
      'Technology',
      'Mathematics',
      'Physics',
      'Chemistry',
      'Biology',
      'Medicine',
      'Engineering',
      'Computer Science',
      'Business',
      'Economics',
      'Politics',
      'Law',
      'Religion',
      'Education',
      'Sports',
      'Travel',
      'Cooking',
      'Health',
      'Self-Help',
      'Poetry',
      'Drama',
      'Romance',
      'Mystery',
      'Thriller',
      'Fantasy',
      'Science Fiction',
      'Horror',
      'Adventure',
      'Children',
      'Young Adult',
      'Reference',
      'Dictionary',
      'Encyclopedia',
      'Atlas',
      'Periodicals',
      'Comics',
      'Graphic Novels',
      'GST',
    ];

    final bookCategories = books
        .map((book) => book.category)
        .where((category) => category != null && category.isNotEmpty)
        .cast<String>()
        .toSet();

    final allCategories = {...predefinedCategories, ...bookCategories}.toList()
      ..sort();
    return ['All Categories', ...allCategories];
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = Provider.of<BookProvider>(context);
    final selectedCount = _selectedBookIds.length;
    final filteredBooks = getFilteredBooks(bookProvider.books);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 800;

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 20),
        child: Column(
          children: [
            // Search, Filter, and Action buttons - all in one bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Search field
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search books...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) => _filterBooks(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Category filter
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    child: PopupMenuButton<String>(
                      onSelected: (value) {
                        setState(
                          () => _selectedCategory = value == 'All Categories'
                              ? null
                              : value,
                        );
                        _filterBooks();
                      },
                      itemBuilder: (context) {
                        final categories = getUniqueCategories(
                          bookProvider.books,
                        );
                        return categories.map((category) {
                          final isSelected =
                              (_selectedCategory == null &&
                                  category == 'All Categories') ||
                              (_selectedCategory == category);
                          return PopupMenuItem<String>(
                            value: category,
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  size: 20,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  category,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.filter_list,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _selectedCategory ?? 'All Categories',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Selection actions
                  if (selectedCount > 0) ...[
                    IconButton(
                      tooltip: 'Delete ($selectedCount)',
                      onPressed: _deleteSelectedBooks,
                      icon: Icon(
                        Icons.delete_forever,
                        color: Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      tooltip: 'Clear selection',
                      onPressed: () => setState(_selectedBookIds.clear),
                      icon: const Icon(Icons.clear, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                  ],
                  // Category management
                  IconButton(
                    tooltip: 'Manage Categories',
                    onPressed: _showCategoryManagement,
                    icon: Icon(
                      Icons.category,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  // Import
                  IconButton(
                    tooltip: 'Import CSV/Excel',
                    onPressed: _importBooks,
                    icon: const Icon(Icons.upload_file, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                  // Export
                  IconButton(
                    tooltip: 'Export CSV',
                    onPressed: _exportBooksCsv,
                    icon: const Icon(Icons.download, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  // Add Book button
                  ElevatedButton.icon(
                    onPressed: () => _showBookDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(isCompact ? 'Add' : 'Add Book'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: bookProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : bookProvider.books.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.library_books_outlined,
                              size: 80,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No books found',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Click "Add Book" to create a new book',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _loadBooks,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : Theme(
                        data: Theme.of(context).copyWith(
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          checkboxTheme: Theme.of(context).checkboxTheme
                              .copyWith(
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                        ),
                        child: DataTable2(
                          columnSpacing: 6,
                          horizontalMargin: 10,
                          dataRowHeight: 60,
                          headingRowHeight: 48,
                          showCheckboxColumn: false,
                          minWidth: 850,
                          columns: [
                            DataColumn2(
                              fixedWidth: 40,
                              label: Center(
                                child: Transform.scale(
                                  scale: 0.8,
                                  child: Checkbox(
                                    tristate: true,
                                    value: filteredBooks.isEmpty
                                        ? false
                                        : filteredBooks.every(
                                            (b) =>
                                                _selectedBookIds.contains(b.id),
                                          )
                                        ? true
                                        : filteredBooks.any(
                                            (b) =>
                                                _selectedBookIds.contains(b.id),
                                          )
                                        ? null
                                        : false,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          for (final b in filteredBooks) {
                                            _selectedBookIds.add(b.id);
                                          }
                                        } else {
                                          for (final b in filteredBooks) {
                                            _selectedBookIds.remove(b.id);
                                          }
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const DataColumn2(
                              label: Text('Cover'),
                              fixedWidth: 50,
                            ),
                            const DataColumn2(
                              label: Text('ISBN'),
                              size: ColumnSize.S,
                            ),
                            const DataColumn2(
                              label: Text('Title'),
                              size: ColumnSize.L,
                            ),
                            const DataColumn2(
                              label: Text('Author'),
                              size: ColumnSize.M,
                            ),
                            const DataColumn2(
                              label: Text('Rack'),
                              size: ColumnSize.S,
                            ),
                            const DataColumn2(
                              label: Text('Category'),
                              size: ColumnSize.S,
                            ),
                            const DataColumn2(
                              label: Text('Copies'),
                              fixedWidth: 65,
                            ),
                            const DataColumn2(
                              label: Text('Status'),
                              fixedWidth: 100,
                            ),
                            const DataColumn2(
                              label: Text('Actions'),
                              fixedWidth: 100,
                            ),
                          ],
                          rows: filteredBooks
                              .map(
                                (book) => DataRow(
                                  selected: _selectedBookIds.contains(book.id),
                                  onSelectChanged: (selected) {
                                    if (selected == null) return;
                                    setState(() {
                                      if (selected) {
                                        _selectedBookIds.add(book.id);
                                      } else {
                                        _selectedBookIds.remove(book.id);
                                      }
                                    });
                                  },
                                  cells: [
                                    DataCell(
                                      Center(
                                        child: Transform.scale(
                                          scale: 0.82,
                                          child: Checkbox(
                                            value: _selectedBookIds.contains(
                                              book.id,
                                            ),
                                            onChanged: (checked) {
                                              setState(() {
                                                if (checked == true) {
                                                  _selectedBookIds.add(book.id);
                                                } else {
                                                  _selectedBookIds.remove(
                                                    book.id,
                                                  );
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(_buildCoverCell(book)),
                                    DataCell(
                                      Text(book.isbn.isEmpty ? '-' : book.isbn),
                                    ),
                                    DataCell(
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            normalizeHindiForDisplay(
                                              book.title,
                                            ),
                                            style: _textStyleForHindi(
                                              normalizeHindiForDisplay(
                                                book.title,
                                              ),
                                              const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (book.description != null &&
                                              book.description!.isNotEmpty)
                                            Text(
                                              normalizeHindiForDisplay(
                                                book.description!,
                                              ),
                                              style: _textStyleForHindi(
                                                normalizeHindiForDisplay(
                                                  book.description!,
                                                ),
                                                TextStyle(
                                                  fontSize: 11,
                                                  color: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall?.color,
                                                ),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        normalizeHindiForDisplay(book.author),
                                        style: _textStyleForHindi(
                                          normalizeHindiForDisplay(book.author),
                                          const TextStyle(),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        (book.rackNumber ?? '').isEmpty
                                            ? '-'
                                            : book.rackNumber!,
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        (book.category ?? '').isEmpty
                                            ? '-'
                                            : book.category!,
                                      ),
                                    ),
                                    DataCell(
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '${book.availableCopies}/${book.totalCopies}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: book.availableCopies > 0
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          ),
                                          Text(
                                            'avail.',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: book.availableCopies > 0
                                              ? Colors.green.withValues(alpha: 0.08)
                                              : Colors.orange.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: book.availableCopies > 0
                                                ? Colors.green.withValues(alpha: 0.25)
                                                : Colors.orange.withValues(alpha: 0.25),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: book.availableCopies > 0
                                                    ? Colors.green
                                                    : Colors.orange,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              book.availableCopies > 0
                                                  ? 'Available'
                                                  : 'Borrowed',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: book.availableCopies > 0
                                                    ? Colors.green
                                                    : Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              icon: Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                                color: Colors.amber.shade700,
                                              ),
                                              tooltip: 'Edit',
                                              onPressed: () =>
                                                  _showBookDialog(book: book),
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              icon: Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                                color: Colors.red.shade400,
                                              ),
                                              tooltip: 'Delete',
                                              onPressed: () =>
                                                  _deleteBook(book.id),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
              ),
            ),

            // Pagination controls
            if (!bookProvider.isLoading && bookProvider.books.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${bookProvider.books.length} of ${bookProvider.totalBooks} books',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Row(
                      children: [
                        Text(
                          'Page ${bookProvider.currentPage} of ${bookProvider.totalPages}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: bookProvider.currentPage > 1
                              ? () => bookProvider.loadPage(
                                  bookProvider.currentPage - 1,
                                )
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: bookProvider.hasMore
                              ? () => bookProvider.loadPage(
                                  bookProvider.currentPage + 1,
                                )
                              : null,
                        ),
                        if (bookProvider.hasMore)
                          TextButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Load More'),
                            onPressed: () => bookProvider.loadMoreBooks(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _filterBooks() {
    final bookProvider = Provider.of<BookProvider>(context, listen: false);
    final searchText = _searchController.text;

    // If search contains Devanagari (Hindi), fetch ALL books and filter locally
    // because the backend may have legacy-encoded data that won't match Unicode search
    final containsHindi = RegExp(r'[\u0900-\u097F]').hasMatch(searchText);

    if (containsHindi && searchText.isNotEmpty) {
      // Fetch ALL books for local Hindi filtering - bypasses pagination
      bookProvider.loadAllBooksForLocalSearch(category: _selectedCategory);
    } else if (searchText.isEmpty) {
      // Empty search - load paginated books
      bookProvider.loadBooks(category: _selectedCategory);
    } else {
      // For non-Hindi search, use backend search with pagination
      bookProvider.loadBooks(
        search: searchText,
        category: _selectedCategory,
      );
    }
  }

  void _showCategoryManagement() {
    showDialog(
      context: context,
      builder: (context) => _CategoryManagementDialog(
        onChanged: () {
          // Refresh books to reflect category changes
          _loadBooks();
        },
      ),
    );
  }

  void _showBookDialog({Book? book}) async {
    final result = await showDialog(
      context: context,
      builder: (context) => BookDialog(book: book),
    );
    if (mounted && result == true) {
      await context.read<BookProvider>().loadBooks();
      await context.read<IssueProvider>().loadStats();
    }
  }

  Future<void> _importBooks() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx', 'xls'],
      withData: false,
    );

    if (!mounted || result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null || path.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read selected file path.')),
        );
      }
      return;
    }

    // Loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('Importing books...')),
            ],
          ),
        ),
      );
    }

    try {
      final summary = await ApiService.importBooksFile(filePath: path);

      if (!mounted) return;

      final navigator = Navigator.of(context);
      final bookProvider = context.read<BookProvider>();
      final issueProvider = context.read<IssueProvider>();

      navigator.pop();
      await bookProvider.loadBooks();
      await issueProvider.loadStats();

      if (!mounted) return;

      final inserted = summary['inserted'];
      final updated = summary['updated'];
      final skipped = summary['skipped'];
      final totalRows = summary['totalRows'];
      final errors = summary['errors'];
      final legacyHindiRows = summary['legacyHindiRows'];

      final errorText = (errors is List && errors.isNotEmpty)
          ? errors.take(10).join('\n')
          : null;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import complete'),
          content: SelectableText(
            [
              if (totalRows != null) 'Rows: $totalRows',
              if (inserted != null) 'Inserted: $inserted',
              if (updated != null) 'Updated: $updated',
              if (skipped != null) 'Skipped: $skipped',
              if (legacyHindiRows is int && legacyHindiRows > 0) '',
              if (legacyHindiRows is int && legacyHindiRows > 0)
                'Note: $legacyHindiRows row(s) look like legacy Hindi (KrutiDev-style) text. The app will automatically convert most such text to Unicode for display (no Kruti Dev font installation required). For best long-term results, convert your file to Unicode Hindi (UTF-8) before importing.',
              if (errorText != null) '',
              if (errorText != null) 'Errors (first 10):\n$errorText',
            ].where((s) => s.isNotEmpty).join('\n'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(getOperationErrorMessage('Import', e))));
    }
  }

  Future<void> _exportBooksCsv() async {
    final pageContext = context;
    try {
      // Show loading indicator
      showDialog(
        context: pageContext,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text(
                'Exporting books... This may take a moment for large datasets.',
              ),
            ],
          ),
        ),
      );

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Books Export (CSV)',
        fileName:
            'books_export_${DateTime.now().toIso8601String().split('T')[0]}.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );

      if (path == null || path.isEmpty) {
        if (Navigator.of(pageContext).canPop()) Navigator.of(pageContext).pop();
        return;
      }

      // Use server-side export for better performance with large datasets
      // Server already adds BOM for UTF-8 compatibility
      final csvBytes = await ApiService.exportData('books', format: 'csv');
      await File(path).writeAsBytes(csvBytes, flush: true);

      if (!mounted) return;
      if (Navigator.of(pageContext).canPop()) Navigator.of(pageContext).pop();

      ScaffoldMessenger.of(
        pageContext,
      ).showSnackBar(SnackBar(content: Text('Exported CSV to: $path')));
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(pageContext).canPop()) Navigator.of(pageContext).pop();
      ScaffoldMessenger.of(
        pageContext,
      ).showSnackBar(SnackBar(content: Text(getOperationErrorMessage('Export', e))));
    }
  }

  void _deleteBook(int id) {
    final pageContext = context;
    showDialog(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Book'),
        content: const Text('Are you sure you want to delete this book?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await pageContext.read<BookProvider>().deleteBook(id);

                if (!mounted) return;
                setState(() => _selectedBookIds.remove(id));

                await pageContext.read<IssueProvider>().loadStats();
                if (!mounted) return;

                ScaffoldMessenger.of(pageContext).showSnackBar(
                  const SnackBar(content: Text('Book deleted successfully')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(pageContext).showSnackBar(
                  SnackBar(content: Text(getOperationErrorMessage('Delete book', e))),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelectedBooks() async {
    final ids = _selectedBookIds.toList()..sort();
    if (ids.isEmpty) return;

    final pageContext = context;
    final confirmed = await showDialog<bool>(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete selected books'),
        content: Text('Delete ${ids.length} selected book(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    showDialog(
      context: pageContext,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Deleting ${ids.length} books...')),
          ],
        ),
      ),
    );

    try {
      final navigator = Navigator.of(pageContext);
      final messenger = ScaffoldMessenger.of(pageContext);

      // Use optimized bulk delete API
      final result = await ApiService.bulkDeleteBooks(ids);
      final deletedCount = result['deleted'] ?? 0;

      if (!mounted) return;
      navigator.pop();

      // Refresh data after bulk delete
      await pageContext.read<BookProvider>().loadBooks();
      await pageContext.read<IssueProvider>().loadStats();

      if (!mounted) return;
      setState(() => _selectedBookIds.clear());

      messenger.showSnackBar(
        SnackBar(content: Text('Deleted $deletedCount book(s) successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(pageContext).maybePop();
      ScaffoldMessenger.of(
        pageContext,
      ).showSnackBar(SnackBar(content: Text(getOperationErrorMessage('Bulk delete', e))));
    }
  }

  List<Book> getFilteredBooks(List<Book> books) {
    final rawQuery = _searchController.text;
    if (rawQuery.trim().isEmpty) {
      final category = _selectedCategory;
      if (category == null) return books;
      return books.where((book) => book.category == category).toList();
    }

    final query = rawQuery.toLowerCase();
    // Also normalize the query from legacy Hindi to Unicode for proper matching
    final normalizedQuery = normalizeHindiForDisplay(rawQuery).toLowerCase();
    // Convert Unicode Hindi query to KrutiDev for matching legacy data
    final krutiDevQuery = unicodeToKrutiDevApprox(rawQuery).toLowerCase();
    final category = _selectedCategory;

    return books.where((book) {
      // Normalize title and author from legacy Hindi to Unicode
      final normalizedTitle = normalizeHindiForDisplay(
        book.title,
      ).toLowerCase();
      final normalizedAuthor = normalizeHindiForDisplay(
        book.author,
      ).toLowerCase();
      final normalizedCategory = normalizeHindiForDisplay(
        book.category ?? '',
      ).toLowerCase();

      // Also keep raw title/author for legacy matching
      final rawTitle = book.title.toLowerCase();
      final rawAuthor = book.author.toLowerCase();
      final rawCategory = (book.category ?? '').toLowerCase();
      final lowerIsbn = book.isbn.toLowerCase();
      final lowerRack = (book.rackNumber ?? '').toLowerCase();

      // Comprehensive matching: support all Hindi encodings in both query and data
      // 1. Direct match (raw query vs raw data)
      // 2. Normalized query vs normalized data (handles Krutidev data)
      // 3. KrutiDev query vs raw data (handles Unicode query against Krutidev data)
      // 4. Raw query vs normalized data (handles Krutidev query against Unicode data)
      final matchesTitle =
          rawTitle.contains(query) ||
          normalizedTitle.contains(query) ||
          normalizedTitle.contains(normalizedQuery) ||
          rawTitle.contains(krutiDevQuery);

      final matchesAuthor =
          rawAuthor.contains(query) ||
          normalizedAuthor.contains(query) ||
          normalizedAuthor.contains(normalizedQuery) ||
          rawAuthor.contains(krutiDevQuery);

      final matchesIsbn = lowerIsbn.contains(query);
      final matchesRack = lowerRack.contains(query);

      final matchesCategorySearch =
          rawCategory.contains(query) ||
          normalizedCategory.contains(query) ||
          normalizedCategory.contains(normalizedQuery) ||
          rawCategory.contains(krutiDevQuery);

      final matchesQuery =
          matchesTitle ||
          matchesAuthor ||
          matchesIsbn ||
          matchesRack ||
          matchesCategorySearch;

      final matchesCategoryFilter =
          category == null || book.category == category;
      return matchesQuery && matchesCategoryFilter;
    }).toList();
  }

  Widget _buildCoverCell(Book book) {
    return Container(
      width: 40,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      clipBehavior: Clip.antiAlias,
      child: book.coverImage != null && book.coverImage!.isNotEmpty
          ? Image.network(
              ApiService.resolvePublicUrl(book.coverImage!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildCoverPlaceholder(book),
            )
          : _buildCoverPlaceholder(book),
    );
  }

  Widget _buildCoverPlaceholder(Book book) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Image.asset(
            'assets/images/App_Logo.png',
            fit: BoxFit.contain,
            opacity: const AlwaysStoppedAnimation(0.75),
            errorBuilder: (context, error, stackTrace) => Center(
              child: Icon(
                Icons.menu_book,
                size: 20,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _dataChangedSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}

// ==================== Category Management Dialog ====================

class _CategoryManagementDialog extends StatefulWidget {
  final VoidCallback onChanged;

  const _CategoryManagementDialog({required this.onChanged});

  @override
  State<_CategoryManagementDialog> createState() =>
      _CategoryManagementDialogState();
}

class _CategoryManagementDialogState extends State<_CategoryManagementDialog> {
  List<dynamic> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final categories = await ApiService.getCategories(forceRefresh: true);
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addCategory() async {
    final result = await _showCategoryEditDialog(name: '', description: '');
    if (result != null) {
      try {
        await ApiService.addCategory(result['name']!, result['description']);
        _loadCategories();
        widget.onChanged();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding category: $e')),
          );
        }
      }
    }
  }

  Future<void> _editCategory(dynamic cat) async {
    final result = await _showCategoryEditDialog(
      name: cat.name,
      description: '',
    );
    if (result != null) {
      try {
        await ApiService.updateCategory(cat.id, result['name']!, result['description']);
        _loadCategories();
        widget.onChanged();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating category: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteCategory(dynamic cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${cat.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ApiService.deleteCategory(cat.id);
        _loadCategories();
        widget.onChanged();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting category: $e')),
          );
        }
      }
    }
  }

  Future<Map<String, String?>?> _showCategoryEditDialog({
    required String name,
    String? description,
  }) async {
    final nameController = TextEditingController(text: name);
    final descController = TextEditingController(text: description ?? '');
    final isNew = name.isEmpty;

    return showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isNew ? 'Add Category' : 'Edit Category'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final n = nameController.text.trim();
              if (n.isEmpty) return;
              Navigator.of(context).pop({
                'name': n,
                'description':
                    descController.text.trim().isEmpty
                        ? null
                        : descController.text.trim(),
              });
            },
            child: Text(isNew ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
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
                    const Icon(Icons.category, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Manage Categories',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.white),
                      tooltip: 'Add Category',
                      onPressed: _addCategory,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text('Error: $_error'),
                            ),
                          )
                        : _categories.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.category_outlined,
                                        size: 48,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.3),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text('No categories yet'),
                                      const SizedBox(height: 12),
                                      ElevatedButton.icon(
                                        onPressed: _addCategory,
                                        icon: const Icon(Icons.add),
                                        label: const Text('Add Category'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                itemCount: _categories.length,
                                separatorBuilder: (_, i) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final cat = _categories[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      child: Text(
                                        cat.name.isNotEmpty
                                            ? cat.name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      cat.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 18,
                                          ),
                                          tooltip: 'Edit',
                                          onPressed: () =>
                                              _editCategory(cat),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete,
                                            size: 18,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
                                          ),
                                          tooltip: 'Delete',
                                          onPressed: () =>
                                              _deleteCategory(cat),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
