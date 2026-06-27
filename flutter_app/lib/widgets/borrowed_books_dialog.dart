import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../utils/date_formatter.dart';
import '../utils/hindi_text.dart';
import '../utils/theme.dart';
import 'common_widgets.dart';

class BorrowedBooksDialog extends StatefulWidget {
  final int memberId;
  final String memberName;
  final int borrowCount;

  const BorrowedBooksDialog({
    super.key,
    required this.memberId,
    required this.memberName,
    required this.borrowCount,
  });

  @override
  State<BorrowedBooksDialog> createState() => _BorrowedBooksDialogState();
}

class _BorrowedBooksDialogState extends State<BorrowedBooksDialog> {
  List<dynamic> _borrowedBooks = [];
  bool _isLoading = true;
  String? _error;
  int _maxAllowed = 5;

  @override
  void initState() {
    super.initState();
    _loadBorrowedBooks();
  }

  Future<void> _loadBorrowedBooks() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final data = await ApiService.getMemberBorrowedBooks(widget.memberId);
      setState(() {
        _borrowedBooks = data['borrowed_books'] as List<dynamic>? ?? [];
        _maxAllowed = data['max_allowed'] ?? 5;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  bool _containsDevanagari(String text) {
    return text.codeUnits.any((c) => c >= 0x0900 && c <= 0x097F);
  }

  bool _looksLikeLegacyHindi(String text) {
    return text.codeUnits.where((c) => c >= 0x20 && c <= 0x7E).length > text.length * 0.4 &&
        text.codeUnits.any((c) => c >= 0x0900 && c <= 0x097F);
  }

  TextStyle _textStyleForHindi(String text, TextStyle base) {
    final defaultSize = DefaultTextStyle.of(context).style.fontSize ?? 14;
    final effectiveSize = base.fontSize ?? defaultSize;

    if (_containsDevanagari(text)) {
      final devanagariBase = GoogleFonts.notoSansDevanagari(textStyle: base);
      return devanagariBase.copyWith(
        fontSize: (effectiveSize * 1.15).clamp(10, 30).toDouble(),
        letterSpacing: 0.5,
        height: 1.5,
        fontFamilyFallback: const [
          'NotoSansDevanagari',
          'Nirmala UI',
          'Mangal',
          'Noto Sans Devanagari',
        ],
      );
    }

    if (_looksLikeLegacyHindi(text)) {
      return base.copyWith(
        fontSize: (effectiveSize * 1.12).clamp(10, 30).toDouble(),
        letterSpacing: 0.3,
        height: 1.4,
        fontFamily: 'KrutiDev',
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
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 800;
    final isVerySmallScreen = screenSize.width < 480;
    final maxWidth = (isSmallScreen ? screenSize.width * 0.95 : 750).toDouble();
    final maxHeight =
        (isSmallScreen ? screenSize.height * 0.9 : 600).toDouble();
    final colorScheme = Theme.of(context).colorScheme;

    final limitReached = widget.borrowCount >= _maxAllowed;
    final limitWarning = widget.borrowCount >= _maxAllowed - 1;
    final limitColor = limitReached
        ? context.semantic.danger
        : (limitWarning ? context.semantic.warning : context.semantic.success);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isVerySmallScreen ? 4 : 16,
        vertical: isVerySmallScreen ? 8 : 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(isVerySmallScreen ? 14 : 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.primaryContainer.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isVerySmallScreen ? 8 : 12),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: colorScheme.onPrimary,
                        size: isVerySmallScreen ? 20 : 28,
                      ),
                    ),
                    SizedBox(width: isVerySmallScreen ? 8 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Currently Borrowed Books',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontSize: isVerySmallScreen ? 15 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!isVerySmallScreen) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.memberName,
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Borrow limit indicator
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: limitColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: limitColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '${widget.borrowCount} / $_maxAllowed',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: limitColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: colorScheme.onPrimaryContainer),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Limit indicator bar
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isVerySmallScreen ? 14 : 20,
                  vertical: isVerySmallScreen ? 8 : 12,
                ),
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          limitReached
                              ? Icons.warning_amber_rounded
                              : Icons.info_outline,
                          size: 16,
                          color: limitColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            limitReached
                                ? 'Borrowing limit reached! Must return books before borrowing more.'
                                : 'Can borrow ${_maxAllowed - widget.borrowCount} more book(s)',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: isVerySmallScreen ? 11 : 13,
                              fontWeight: FontWeight.w500,
                              color: limitColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _maxAllowed > 0
                            ? widget.borrowCount / _maxAllowed
                            : 0,
                        minHeight: 6,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(limitColor),
                      ),
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
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error_outline,
                                      size: 48, color: colorScheme.error),
                                  const SizedBox(height: 16),
                                  Text('Error: $_error',
                                    style: TextStyle(color: colorScheme.onSurface),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadBorrowedBooks,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _borrowedBooks.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.book_outlined,
                                        size: 64,
                                        color: colorScheme.onSurface.withValues(alpha: 0.3),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No books currently borrowed',
                                        style: TextStyle(
                                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: EdgeInsets.all(isVerySmallScreen ? 8 : 16),
                                itemCount: _borrowedBooks.length,
                                separatorBuilder: (c, i) => Divider(
                                  height: 1,
                                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                                ),
                                itemBuilder: (context, index) {
                                  final book = _borrowedBooks[index]
                                      as Map<String, dynamic>;
                                  return _buildBookTile(book, isVerySmallScreen);
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookTile(Map<String, dynamic> book, bool isVerySmallScreen) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = book['title'] ?? 'Unknown';
    final author = book['author'] ?? 'Unknown';
    final isbn = book['isbn'] ?? '';
    final category = book['category'] ?? '';
    final issueDate = book['issue_date'] ?? '';
    final dueDate = book['due_date'] ?? '';
    final status = book['status'] ?? 'issued';
    final coverImage = book['cover_image'];

    final isOverdue = status == 'overdue' ||
        (dueDate.isNotEmpty &&
            DateTime.tryParse(dueDate)?.isBefore(DateTime.now()) == true);
    final overdueColor = context.semantic.danger;
    final issuedColor = colorScheme.primary;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isVerySmallScreen ? 4 : 0,
        vertical: isVerySmallScreen ? 4 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image
          Container(
            width: 40,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: colorScheme.surfaceContainerHighest,
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            clipBehavior: Clip.antiAlias,
            child: coverImage != null && coverImage.toString().isNotEmpty
                ? AppCachedImage(
                    url: ApiService.resolvePublicUrl(coverImage.toString()),
                    fit: BoxFit.cover,
                    memCacheWidth: 160,
                    fallback: Center(
                      child: Icon(Icons.book, size: 20, color: colorScheme.outline),
                    ),
                  )
                : Center(child: Icon(Icons.book, size: 20, color: colorScheme.outline)),
          ),
          const SizedBox(width: 12),
          // Book info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  normalizeHindiForDisplay(title),
                  style: _textStyleForHindi(
                    normalizeHindiForDisplay(title),
                    TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isVerySmallScreen ? 13 : 14,
                      color: isDark ? colorScheme.onSurface : const Color(0xFF1A1A2E),
                    ),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'by ${normalizeHindiForDisplay(author)}',
                  style: _textStyleForHindi(
                    normalizeHindiForDisplay(author),
                    TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                if (!isVerySmallScreen)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (isbn.isNotEmpty)
                        _infoChip('ISBN: $isbn', Icons.qr_code,
                            colorScheme.onSurface.withValues(alpha: 0.5)),
                      if (category.isNotEmpty)
                        _infoChip(category, Icons.category,
                            colorScheme.primary),
                    ],
                  ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _infoChip(
                      'Issued: ${DateFormatter.formatDateIndian(issueDate)}',
                      Icons.calendar_today,
                      context.semantic.success,
                    ),
                    _infoChip(
                      'Due: ${DateFormatter.formatDateIndian(dueDate)}',
                      Icons.event,
                      isOverdue ? overdueColor : context.semantic.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Status badge
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isOverdue
                  ? overdueColor.withValues(alpha: 0.1)
                  : issuedColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOverdue
                    ? overdueColor.withValues(alpha: 0.3)
                    : issuedColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              isOverdue ? 'OVERDUE' : 'ISSUED',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isOverdue ? overdueColor : issuedColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String text, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
