import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../models/book.dart';
import '../providers/book_provider.dart';
import '../services/api_service.dart';
import '../utils/hindi_text.dart';

class BookDialog extends StatefulWidget {
  final Book? book;

  const BookDialog({super.key, this.book});

  @override
  State<BookDialog> createState() => _BookDialogState();
}

class _BookDialogState extends State<BookDialog> {
  final _formKey = GlobalKey<FormState>();
  final _isbnController = TextEditingController();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _rackNumberController = TextEditingController();
  final _publisherController = TextEditingController();
  final _yearController = TextEditingController();
  final _totalCopiesController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  String? _coverImageUrl;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isUploading = false;

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTextChanged);
    _authorController.addListener(_onTextChanged);
    _publisherController.addListener(_onTextChanged);
    _descriptionController.addListener(_onTextChanged);
    if (widget.book != null) {
      _isbnController.text = widget.book!.isbn;
      _titleController.text = normalizeHindiForDisplay(widget.book!.title);
      _authorController.text = normalizeHindiForDisplay(widget.book!.author);
      _rackNumberController.text = widget.book!.rackNumber ?? '';
      _publisherController.text = normalizeHindiForDisplay(
        widget.book!.publisher ?? '',
      );
      _yearController.text = widget.book!.yearPublished?.toString() ?? '';
      _selectedCategory = widget.book!.category;
      _totalCopiesController.text = widget.book!.totalCopies.toString();
      _descriptionController.text = normalizeHindiForDisplay(
        widget.book!.description ?? '',
      );
      _coverImageUrl = widget.book!.coverImage;
    } else {
      _totalCopiesController.text = '1';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.book != null;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 900;
    final maxWidth = (isSmallScreen ? screenSize.width * 0.95 : 900).toDouble();
    final maxHeight = (isSmallScreen ? screenSize.height * 0.95 : 800)
        .toDouble();

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEditing ? 'Edit Book' : 'Add Book',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: isSmallScreen
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCoverImagePicker(),
                                const SizedBox(height: 20),
                                _buildCopiesField(),
                                const SizedBox(height: 24),
                                _buildFormFields(),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    _buildCoverImagePicker(),
                                    const SizedBox(height: 20),
                                    _buildCopiesField(),
                                  ],
                                ),
                                const SizedBox(width: 24),
                                Expanded(child: _buildFormFields()),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              // Footer
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isUploading ? null : _saveBook,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(isEditing ? Icons.save : Icons.add),
                      label: Text(isEditing ? 'Update' : 'Add'),
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

  Widget _buildFormFields() {
    final baseFieldStyle = Theme.of(context).textTheme.bodyLarge ?? const TextStyle();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _isbnController,
          decoration: const InputDecoration(
            labelText: 'ISBN',
            prefixIcon: Icon(Icons.qr_code),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _titleController,
          style: hindiAwareTextStyle(
            context,
            text: _titleController.text,
            base: baseFieldStyle,
          ),
          decoration: const InputDecoration(
            labelText: 'Title',
            prefixIcon: Icon(Icons.book),
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Title is required';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _authorController,
          style: hindiAwareTextStyle(
            context,
            text: _authorController.text,
            base: baseFieldStyle,
          ),
          decoration: const InputDecoration(
            labelText: 'Author',
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Author is required';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _rackNumberController,
          decoration: const InputDecoration(
            labelText: 'Rack Number',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _getAllCategories().contains(_selectedCategory) ? _selectedCategory : null,
          decoration: const InputDecoration(
            labelText: 'Category',
            prefixIcon: Icon(Icons.category),
          ),
          items: _getAllCategories()
              .toSet() // Remove duplicates
              .map(
                (category) =>
                    DropdownMenuItem(value: category, child: Text(category)),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedCategory = value),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _publisherController,
                style: hindiAwareTextStyle(
                  context,
                  text: _publisherController.text,
                  base: baseFieldStyle,
                ),
                decoration: const InputDecoration(
                  labelText: 'Publisher',
                  prefixIcon: Icon(Icons.business),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 120,
              child: TextFormField(
                controller: _yearController,
                decoration: const InputDecoration(
                  labelText: 'Year',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          style: hindiAwareTextStyle(
            context,
            text: _descriptionController.text,
            base: baseFieldStyle,
          ),
          decoration: const InputDecoration(
            labelText: 'Description',
            prefixIcon: Icon(Icons.description),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildCoverImagePicker() {
    return Container(
      width: 160,
      height: 220,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: _buildImagePreview(),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Material(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _pickImage,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _coverImageUrl != null || _selectedImageBytes != null
                        ? Icons.edit
                        : Icons.add_photo_alternate,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          if (_coverImageUrl != null || _selectedImageBytes != null)
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() {
                      _coverImageUrl = null;
                      _selectedImageBytes = null;
                      _selectedImageName = null;
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImageBytes != null) {
      return Image.memory(
        _selectedImageBytes!,
        fit: BoxFit.cover,
        width: 160,
        height: 220,
      );
    } else if (_coverImageUrl != null && _coverImageUrl!.isNotEmpty) {
      return Image.network(
        ApiService.resolvePublicUrl(_coverImageUrl!),
        fit: BoxFit.cover,
        width: 160,
        height: 220,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 8),
          Text(
            'Book Cover',
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopiesField() {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Total Copies',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final current =
                          int.tryParse(_totalCopiesController.text) ?? 1;
                      if (current > 1) {
                        _totalCopiesController.text = (current - 1).toString();
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                    iconSize: 24,
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: TextFormField(
                    controller: _totalCopiesController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final current =
                          int.tryParse(_totalCopiesController.text) ?? 1;
                      _totalCopiesController.text = (current + 1).toString();
                      setState(() {});
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    iconSize: 24,
                  ),
                ),
              ],
            ),
          ),
          if (widget.book != null) ...[
            const SizedBox(height: 8),
            Text(
              'Available: ${widget.book!.availableCopies}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'bmp',
          'tif',
          'tiff',
          'ico',
          'svg',
        ],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final picked = result.files.first;
        final bytes = picked.bytes;
        const maxBytes = 10 * 1024 * 1024;
        if (picked.size > maxBytes) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image must be 10MB or smaller.')),
            );
          }
          return;
        }
        if (bytes == null || bytes.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not read the selected image.'),
              ),
            );
          }
          return;
        }
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = picked.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  void _saveBook() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    try {
      String? coverImagePath = _coverImageUrl;

      if (_selectedImageBytes != null && _selectedImageName != null) {
        coverImagePath = await ApiService.uploadBookCover(
          _selectedImageBytes!,
          _selectedImageName!,
        );
      }

        final title = normalizeHindiForDisplay(_titleController.text);
        final author = normalizeHindiForDisplay(_authorController.text);
        final publisher = normalizeHindiForDisplay(_publisherController.text);
        final description = normalizeHindiForDisplay(_descriptionController.text);

        final book = Book(
        id: widget.book?.id ?? 0,
        isbn: _isbnController.text,
        title: title,
        author: author,
        rackNumber: _rackNumberController.text.trim().isEmpty
            ? null
            : _rackNumberController.text.trim(),
        category: _selectedCategory,
        publisher: publisher.isEmpty ? null : publisher,
        yearPublished: _yearController.text.isEmpty
            ? null
            : int.parse(_yearController.text),
        status: widget.book?.status ?? 'available',
        addedDate: widget.book?.addedDate ?? DateTime.now().toIso8601String(),
        coverImage: coverImagePath,
        totalCopies: int.tryParse(_totalCopiesController.text) ?? 1,
        availableCopies:
            widget.book?.availableCopies ??
            (int.tryParse(_totalCopiesController.text) ?? 1),
        description: description.isEmpty ? null : description,
      );

      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      if (widget.book != null) {
        await bookProvider.updateBook(widget.book!.id, book);
      } else {
        await bookProvider.addBook(book);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Book ${widget.book != null ? 'updated' : 'added'} successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save book: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  static const List<String> _categories = [
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

  /// Get all categories including the current book's category if it's not in the list
  List<String> _getAllCategories() {
    final categories = List<String>.from(_categories);
    if (_selectedCategory != null && 
        _selectedCategory!.isNotEmpty && 
        !categories.contains(_selectedCategory)) {
      categories.insert(0, _selectedCategory!);
    }
    return categories;
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _authorController.removeListener(_onTextChanged);
    _publisherController.removeListener(_onTextChanged);
    _descriptionController.removeListener(_onTextChanged);
    _isbnController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _rackNumberController.dispose();
    _publisherController.dispose();
    _yearController.dispose();
    _totalCopiesController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
