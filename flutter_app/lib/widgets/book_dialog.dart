import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../models/book.dart';
import '../providers/book_provider.dart';
import '../services/api_service.dart';
import '../utils/hindi_text.dart';
import '../utils/error_utils.dart';

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
  List<String> _dynamicCategories = [];
  bool _categoriesLoading = true;
  bool _isInitialized = false;

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
      _publisherController.text = normalizeHindiForDisplay(widget.book!.publisher ?? '');
      _yearController.text = widget.book!.yearPublished?.toString() ?? '';
      _selectedCategory = widget.book!.category;
      _totalCopiesController.text = widget.book!.totalCopies.toString();
      _descriptionController.text = normalizeHindiForDisplay(widget.book!.description ?? '');
      _coverImageUrl = widget.book!.coverImage;
    } else {
      _totalCopiesController.text = '1';
    }
    _loadCategories();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    });
  }

  Future<void> _loadCategories() async {
    try {
      final apiCategories = await ApiService.getCategories(forceRefresh: true);
      if (mounted) {
        setState(() {
          _dynamicCategories = apiCategories.map((c) => c.name).where((n) => n.trim().isNotEmpty).toList();
          _categoriesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _categoriesLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.book != null;
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isVerySmallScreen = screenSize.width < 480;
    final isSmallScreen = screenSize.width < 700;
    final maxWidth = isVerySmallScreen
        ? screenSize.width * 0.95
        : (isSmallScreen ? screenSize.width * 0.98 : 820).toDouble();
    final maxHeight = screenSize.height * 0.92;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isVerySmallScreen ? 4 : (isSmallScreen ? 8 : 24),
        vertical: isVerySmallScreen ? 8 : 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.15),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(colorScheme, isEditing),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isVerySmallScreen ? 16 : 24),
                    child: Form(
                      key: _formKey,
                      child: isVerySmallScreen
                          ? _buildCompactLayout(colorScheme, veryCompact: true)
                          : (isSmallScreen ? _buildCompactLayout(colorScheme) : _buildWideLayout(colorScheme)),
                    ),
                ),
              ),
              _buildFooter(colorScheme, isEditing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, bool isEditing) {
    final isVerySmallScreen = MediaQuery.of(context).size.width < 480;
    return Container(
      padding: EdgeInsets.fromLTRB(
        isVerySmallScreen ? 16 : 24,
        isVerySmallScreen ? 14 : 20,
        isVerySmallScreen ? 8 : 16,
        isVerySmallScreen ? 14 : 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isVerySmallScreen ? 8 : 12),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Icon(isEditing ? Icons.edit_square : Icons.library_add, color: colorScheme.onPrimary, size: isVerySmallScreen ? 20 : 24),
          ),
          SizedBox(width: isVerySmallScreen ? 10 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Edit Book' : 'Add New Book',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer, fontSize: isVerySmallScreen ? 16 : null),
                ),
                if (!isVerySmallScreen) ...[
                  const SizedBox(height: 2),
                  Text(
                    isEditing ? 'Update book information and details' : 'Fill in the details to add a new book',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8)),
                  ),
                ],
              ],
            ),
          ),
          if (!isVerySmallScreen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_stories, size: 16, color: colorScheme.onPrimaryContainer),
                  const SizedBox(width: 6),
                  Text('Library', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onPrimaryContainer)),
                ],
              ),
            ),
          SizedBox(width: isVerySmallScreen ? 4 : 8),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Container(
              padding: EdgeInsets.all(isVerySmallScreen ? 4 : 6),
              decoration: BoxDecoration(color: colorScheme.surface.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.close, size: isVerySmallScreen ? 18 : 20, color: colorScheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout(ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 210,
          child: Column(
            children: [
              _buildCoverCard(colorScheme),
              const SizedBox(height: 20),
              if (_isInitialized) _buildCopiesCard(colorScheme),
            ],
          ),
        ),
        const SizedBox(width: 32),
        Expanded(child: _buildFormSection(colorScheme)),
      ],
    );
  }

  Widget _buildCompactLayout(ColorScheme colorScheme, {bool veryCompact = false}) {
    return Column(
      children: [
        if (veryCompact)
          Column(
            children: [
              Center(child: _buildCoverCard(colorScheme, compact: true)),
              const SizedBox(height: 16),
              if (_isInitialized) _buildCopiesCard(colorScheme),
              const SizedBox(height: 16),
              _buildFormSection(colorScheme, compact: true),
            ],
          )
        else
          Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCoverCard(colorScheme, compact: true),
                  const SizedBox(width: 20),
                  Expanded(child: _buildFormSection(colorScheme, compact: true)),
                ],
              ),
              const SizedBox(height: 24),
              if (_isInitialized) _buildCopiesCard(colorScheme),
            ],
          ),
      ],
    );
  }

  Widget _buildCoverCard(ColorScheme colorScheme, {bool compact = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: compact ? 110 : 170,
                height: compact ? 150 : 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colorScheme.primary.withValues(alpha: 0.08), colorScheme.tertiary.withValues(alpha: 0.08)],
                  ),
                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2), width: 2),
                ),
                child: ClipRRect(borderRadius: BorderRadius.circular(14), child: _buildImagePreview(compact: compact)),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Icon(_coverImageUrl != null || _selectedImageBytes != null ? Icons.edit : Icons.add_a_photo, color: colorScheme.onPrimary, size: compact ? 16 : 20),
                  ),
                ),
              ),
            ],
          ),
          if ((_coverImageUrl != null || _selectedImageBytes != null) && !compact) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => setState(() { _coverImageUrl = null; _selectedImageBytes = null; _selectedImageName = null; }),
              icon: Icon(Icons.delete_outline, size: 16, color: colorScheme.error),
              label: Text('Remove', style: TextStyle(color: colorScheme.error, fontSize: 12)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCopiesCard(ColorScheme colorScheme) {
    final total = int.tryParse(_totalCopiesController.text) ?? 1;
    final available = widget.book?.availableCopies ?? total;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primaryContainer.withValues(alpha: 0.4), colorScheme.primaryContainer.withValues(alpha: 0.2)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCounterButton(Icons.remove_circle_outline, () {
                if (total > 1) _totalCopiesController.text = (total - 1).toString();
                setState(() {});
              }, colorScheme),
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  _totalCopiesController.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.primary),
                ),
              ),
              _buildCounterButton(Icons.add_circle_outline, () {
                _totalCopiesController.text = (total + 1).toString();
                setState(() {});
              }, colorScheme),
            ],
          ),
          const SizedBox(height: 8),
          Text('Total Copies', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colorScheme.primary)),
          if (widget.book != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.withValues(alpha: 0.3))),
              child: Text('$available available', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCounterButton(IconData icon, VoidCallback onPressed, ColorScheme colorScheme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 28, color: colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildFormSection(ColorScheme colorScheme, {bool compact = false}) {
    final baseFieldStyle = Theme.of(context).textTheme.bodyLarge ?? const TextStyle();
    final sp = compact ? 12.0 : 16.0;
    final sectionSp = compact ? 24.0 : 32.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Book Information', Icons.book_outlined),
        SizedBox(height: sp),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: compact ? 2 : 3, child: _buildTextField(controller: _titleController, label: 'Title', hint: 'Enter book title', icon: Icons.book_outlined, validator: (v) => (v?.isEmpty ?? true) ? 'Title is required' : null, style: hindiAwareTextStyle(context, text: _titleController.text, base: baseFieldStyle))),
            if (!compact) ...[
              const SizedBox(width: 20),
              Expanded(flex: 2, child: _buildTextField(controller: _isbnController, label: 'ISBN', hint: 'Enter ISBN', icon: Icons.qr_code)),
            ],
          ],
        ),
        if (compact) ...[
          SizedBox(height: sp),
          _buildTextField(controller: _isbnController, label: 'ISBN', hint: 'Enter ISBN', icon: Icons.qr_code),
        ],
        SizedBox(height: sp),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildTextField(controller: _authorController, label: 'Author', hint: 'Enter author name', icon: Icons.person_outline, validator: (v) => (v?.isEmpty ?? true) ? 'Author is required' : null, style: hindiAwareTextStyle(context, text: _authorController.text, base: baseFieldStyle))),
            const SizedBox(width: 20),
            Expanded(child: _buildTextField(controller: _rackNumberController, label: 'Rack No.', hint: 'A-12', icon: Icons.location_on_outlined)),
          ],
        ),
        SizedBox(height: sp),
        Row(
          children: [
            Expanded(flex: 2, child: _buildTextField(controller: _publisherController, label: 'Publisher', hint: 'Enter publisher', icon: Icons.business, style: hindiAwareTextStyle(context, text: _publisherController.text, base: baseFieldStyle))),
            const SizedBox(width: 20),
            Expanded(child: _buildTextField(controller: _yearController, label: 'Year', hint: '2024', icon: Icons.calendar_today, keyboardType: TextInputType.number)),
          ],
        ),
        SizedBox(height: sectionSp),
        _buildSectionTitle('Classification', Icons.category_outlined),
        SizedBox(height: sp),
        if (!_categoriesLoading) _buildCategorySelector(colorScheme) else const LinearProgressIndicator(),
        SizedBox(height: sectionSp),
        _buildSectionTitle('Additional Details', Icons.description_outlined),
        SizedBox(height: sp),
        _buildTextField(controller: _descriptionController, label: 'Description', hint: 'Enter book description', icon: Icons.description, maxLines: 3, style: hindiAwareTextStyle(context, text: _descriptionController.text, base: baseFieldStyle)),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primaryContainer,
                colorScheme.primaryContainer.withValues(alpha: 0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: colorScheme.primary),
        ),
        const SizedBox(width: 14),
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextStyle? style,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: style,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      validator: validator,
    );
  }

  Widget _buildCategorySelector(ColorScheme colorScheme) {
    final allCategories = _getAllCategories();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                ),
                hint: const Text('Select category'),
                items: allCategories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat, style: const TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                },
              ),
            ),
          ],
        ),
        if (allCategories.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Quick Select:',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...allCategories.map((category) {
                final isSelected = _selectedCategory == category;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.white : colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              }),
              GestureDetector(
                onTap: () => _showAddCategoryDialog(colorScheme),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorScheme.primary, style: BorderStyle.solid),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'New',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _showAddCategoryDialog(ColorScheme colorScheme) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _AddCategoryDialog(colorScheme: colorScheme),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        if (!_dynamicCategories.contains(result)) {
          _dynamicCategories.add(result);
        }
        _selectedCategory = result;
      });
    }
  }

  Widget _buildFooter(ColorScheme colorScheme, bool isEditing) {
    final isVerySmallScreen = MediaQuery.of(context).size.width < 480;
    return Container(
      padding: EdgeInsets.fromLTRB(
        isVerySmallScreen ? 16 : 24,
        isVerySmallScreen ? 14 : 20,
        isVerySmallScreen ? 16 : 24,
        isVerySmallScreen ? 14 : 20,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: _isUploading ? null : _saveBook,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: _isUploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(isEditing ? Icons.save : Icons.add),
            label: Text(isEditing ? 'Update Book' : 'Add Book'),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview({bool compact = false}) {
    final width = compact ? 110.0 : 170.0;
    final height = compact ? 150.0 : 220.0;
    if (_selectedImageBytes != null) return Image.memory(_selectedImageBytes!, fit: BoxFit.cover, width: width, height: height);
    if (_coverImageUrl != null && _coverImageUrl!.isNotEmpty) {
      return Image.network(ApiService.resolvePublicUrl(_coverImageUrl!), fit: BoxFit.cover, width: width, height: height, loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null, strokeWidth: 2));
      }, errorBuilder: (context, error, stackTrace) => _buildPlaceholder());
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 40, color: colorScheme.outline),
          const SizedBox(height: 8),
          Text('Book Cover', style: TextStyle(fontSize: 12, color: colorScheme.outline)),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tif', 'tiff', 'ico'],
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final picked = result.files.first;
        final bytes = picked.bytes;
        const maxBytes = 10 * 1024 * 1024;
        if (picked.size > maxBytes) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image must be 10MB or smaller.')));
          return;
        }
        if (bytes == null || bytes.isEmpty) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read the selected image.')));
          return;
        }
        setState(() { _selectedImageBytes = bytes; _selectedImageName = picked.name; });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick image')));
    }
  }

  void _saveBook() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isUploading = true);
    try {
      String? coverImagePath = _coverImageUrl;
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      if (_selectedImageBytes != null && _selectedImageName != null) {
        coverImagePath = await ApiService.uploadBookCover(_selectedImageBytes!, _selectedImageName!);
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
        rackNumber: _rackNumberController.text.trim().isEmpty ? null : _rackNumberController.text.trim(),
        category: _selectedCategory,
        publisher: publisher.isEmpty ? null : publisher,
        yearPublished: _yearController.text.isEmpty ? null : int.tryParse(_yearController.text),
        status: widget.book?.status ?? 'available',
        addedDate: widget.book?.addedDate ?? DateTime.now().toIso8601String(),
        coverImage: coverImagePath,
        totalCopies: int.tryParse(_totalCopiesController.text) ?? 1,
        availableCopies: widget.book?.availableCopies ?? (int.tryParse(_totalCopiesController.text) ?? 1),
        description: description.isEmpty ? null : description,
      );

      if (widget.book != null) {
        await bookProvider.updateBook(widget.book!.id, book);
      } else {
        await bookProvider.addBook(book);
      }
      if (mounted) {
        navigator.pop(true);
        messenger.showSnackBar(SnackBar(content: Text('Book ${widget.book != null ? 'updated' : 'added'} successfully')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getOperationErrorMessage('Save book', e))));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  static const List<String> _fallbackCategories = [
    'Fiction', 'Non-Fiction', 'Science', 'History', 'Biography', 'Literature', 'Philosophy', 'Psychology', 'Art', 'Music',
    'Technology', 'Mathematics', 'Physics', 'Chemistry', 'Biology', 'Medicine', 'Engineering', 'Computer Science', 'Business', 'Economics',
    'GST',
  ];

  List<String> _getAllCategories() {
    final base = _dynamicCategories.isNotEmpty ? _dynamicCategories : _fallbackCategories;
    final categories = <String>{...base};
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) categories.add(_selectedCategory!);
    final sorted = categories.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
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

class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.add_circle, color: widget.colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Add New Category'),
        ],
      ),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: 'Category Name',
          hintText: 'Enter category name',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.category),
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
