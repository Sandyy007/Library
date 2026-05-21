import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/book_provider.dart';
import '../providers/issue_provider.dart';
import '../models/book.dart';
import '../widgets/book_dialog.dart';
import '../services/api_service.dart';
import '../utils/hindi_text.dart';
import '../utils/error_utils.dart';
import '../utils/color_extensions.dart';
import '../utils/responsive.dart';
import '../widgets/common_widgets.dart';
import '../screens/dashboard_screen.dart';

class BooksContent extends StatefulWidget {
  const BooksContent({super.key});

  @override
  State<BooksContent> createState() => _BooksContentState();
}

class _BooksContentState extends State<BooksContent>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;
  final Set<int> _selectedBookIds = <int>{};
  StreamSubscription<void>? _dataChangedSub;
  Timer? _searchDebounce;
  List<String> _apiCategories = [];
  int? _hoveredRowIndex;
  late final AnimationController _statusPulseController;
  late final Animation<double> _statusPulse;

  static const Duration _hoverDuration = Duration(milliseconds: 150);
  static const Duration _pulseDuration = Duration(seconds: 2);

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

    return base.copyWith(
      fontFamilyFallback: const [
        'NotoSansDevanagari',
        'Nirmala UI',
        'Mangal',
        'Noto Sans Devanagari',
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _statusPulseController = AnimationController(
      vsync: this,
      duration: _pulseDuration,
    )..repeat(reverse: true);
    _statusPulse = CurvedAnimation(
      parent: _statusPulseController,
      curve: Curves.easeInOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBooks();
      _loadApiCategories();
    });
    // Listen for data changes from other components
    _dataChangedSub = ApiService.dataChangedStream.listen((_) {
      _loadBooks();
    });
    // Listen for keyboard shortcut events
    DashboardScreen.shortcutEvent.addListener(_onShortcutEvent);
  }

  /// Load categories from the API, merge with book data
  Future<void> _loadApiCategories() async {
    try {
      final apiCats = await ApiService.getCategories(forceRefresh: true);
      if (mounted) {
        setState(() {
          _apiCategories = apiCats
              .map((c) => c.name)
              .where((n) => n.trim().isNotEmpty)
              .toList();
        });
      }
    } catch (_) {
      // Keep existing on error
    }
  }

  void _onShortcutEvent() {
    if (DashboardScreen.shortcutEvent.value == 'new-book') {
      _showBookDialog();
    }
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
              duration: const Duration(seconds: 3),
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
    // Merge API categories with any extra categories found on books
    final bookCategories = books
        .map((book) => book.category)
        .where((category) => category != null && category.isNotEmpty)
        .cast<String>()
        .toSet();

    final allCategories = <String>{
      ..._apiCategories,
      ...bookCategories,
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All Categories', ...allCategories];
  }

  Widget _buildHeaderLabel(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8)
        : const Color(0xFF6B7280);
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: color,
      ),
    );
  }

  Widget _wrapRowCell(int rowIndex, Widget child, {bool showAccent = false}) {
    final isHovered = _hoveredRowIndex == rowIndex;
    return MouseRegion(
      onEnter: (_) {
        if (_hoveredRowIndex != rowIndex) {
          setState(() => _hoveredRowIndex = rowIndex);
        }
      },
      child: AnimatedContainer(
        duration: _hoverDuration,
        padding: EdgeInsets.only(left: showAccent ? 6 : 0),
        decoration: showAccent
            ? BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color:
                        isHovered ? const Color(0xFF1D9E75) : Colors.transparent,
                    width: 3,
                  ),
                ),
              )
            : null,
        child: child,
      ),
    );
  }

  Widget _buildPagerIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color borderColor,
    required Color iconColor,
    required Color hoverFill,
    required Color disabledIconColor,
  }) {
    final enabled = onPressed != null;
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      style: ButtonStyle(
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        fixedSize: WidgetStateProperty.all(const Size(32, 32)),
        minimumSize: WidgetStateProperty.all(const Size(32, 32)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: enabled
                ? borderColor
                : borderColor.withValues(alpha: 0.45),
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (!enabled) return Colors.transparent;
          if (states.contains(WidgetState.hovered)) return hoverFill;
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (!enabled) return disabledIconColor;
          return iconColor;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = Provider.of<BookProvider>(context);
    final selectedCount = _selectedBookIds.length;
    final filteredBooks = getFilteredBooks(bookProvider.books);
    final r = Responsive(context);
    final screenWidth = r.width;
    final isVeryCompact = screenWidth < 600;
    final isMedium = screenWidth >= 600 && screenWidth < 900;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const accentTeal = Color(0xFF1D9E75);
    final headerAccent = isDark
      ? colorScheme.primary.withValues(alpha: 0.45)
      : const Color(0xFFBFE9E3);
    final rowHoverColor = isDark
      ? colorScheme.primary.withValues(alpha: 0.12)
      : const Color(0xFFF0FAF7);
    final zebraColor = isDark
      ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.18)
      : const Color(0xFFFAFAFA);
    final tableBorderColor = isDark
      ? colorScheme.outlineVariant.withValues(alpha: 0.55)
      : const Color(0xFFE5E7EB);
    final tableShadowColor = isDark
      ? Colors.black.withValues(alpha: 0.32)
      : Colors.black.withValues(alpha: 0.06);
    final headerBackground = isDark
      ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.65)
      : Colors.white.withValues(alpha: 0.9);
    final mutedText = isDark
      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.8)
      : const Color(0xFF6B7280);
    final titleTextColor =
      isDark ? colorScheme.onSurface : const Color(0xFF1A1A2E);
    final authorTextColor = isDark
      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.85)
      : const Color(0xFF666666);
    final categoryTextColor = isDark
      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.8)
      : const Color(0xFF777777);
    final isbnTextColor = isDark
      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.75)
      : const Color(0xFF888888);
    final searchFill = isDark
      ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
      : const Color(0xFFF7FAFB);
    final showIsbn = screenWidth >= 980;
    final showAuthor = screenWidth >= 840;
    final showRack = screenWidth >= 900;
    final showCategory = screenWidth >= 1050;
    const showCopies = true;
    final columnWidths = <double>[
      46,
      64,
      if (showIsbn) 130,
      screenWidth >= 1200 ? 280 : (screenWidth >= 900 ? 240 : 200),
      if (showAuthor) 180,
      if (showRack) 70,
      if (showCategory) 120,
      if (showCopies) 90,
      120,
      110,
    ];
    final minTableWidth =
      columnWidths.fold(0.0, (sum, width) => sum + width);
    const headingRowHeight = 54.0;

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(r.pagePadding),
        child: Column(
          children: [
            // Search, Filter, and Action buttons - all in one bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tableBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: tableShadowColor,
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _buildToolbar(
                bookProvider: bookProvider,
                selectedCount: selectedCount,
                screenWidth: screenWidth,
                isVeryCompact: isVeryCompact,
                isMedium: isMedium,
                accentTeal: accentTeal,
                tableBorderColor: tableBorderColor,
                searchFill: searchFill,
                mutedText: mutedText,
                colorScheme: colorScheme,
              ),
            ),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tableBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: tableShadowColor,
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: bookProvider.isLoading
                      ? const ShimmerTable(rows: 8, columns: 6)
                      : bookProvider.books.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.library_books_outlined,
                          title: 'No books found',
                          subtitle: 'Click "Add Book" to create a new book',
                          actionLabel: 'Retry',
                          onAction: _loadBooks,
                        )
                      : Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: isDark
                                ? colorScheme.outlineVariant
                                    .withValues(alpha: 0.35)
                                : const Color(0xFFF0F0F0),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            checkboxTheme: Theme.of(context)
                                .checkboxTheme
                                .copyWith(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  side: BorderSide(
                                    color: tableBorderColor,
                                    width: 1,
                                  ),
                                  fillColor:
                                      WidgetStateProperty.resolveWith(
                                    (states) {
                                      if (states
                                          .contains(WidgetState.selected)) {
                                        return accentTeal;
                                      }
                                      return Colors.transparent;
                                    },
                                  ),
                                  checkColor: WidgetStateProperty.all(
                                    Colors.white,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                          ),
                          child: MouseRegion(
                            onExit: (_) {
                              if (_hoveredRowIndex != null) {
                                setState(() => _hoveredRowIndex = null);
                              }
                            },
                            child: Stack(
                              children: [
                                DataTable2(
                                  columnSpacing: 12,
                                  horizontalMargin: 12,
                                  dataRowHeight: 72,
                                  headingRowHeight: headingRowHeight,
                                  showCheckboxColumn: false,
                                  minWidth: minTableWidth,
                                  fixedTopRows: 1,
                                  headingRowColor: WidgetStateProperty.all(
                                    headerBackground,
                                  ),
                                  dividerThickness: 0.5,
                                  columns: [
                                    DataColumn2(
                                      fixedWidth: 46,
                                      label: Center(
                                        child: Transform.scale(
                                          scale: 0.85,
                                          child: Checkbox(
                                            tristate: true,
                                            value: filteredBooks.isEmpty
                                                ? false
                                                : filteredBooks.every(
                                                    (b) => _selectedBookIds
                                                        .contains(b.id),
                                                  )
                                                ? true
                                                : filteredBooks.any(
                                                    (b) => _selectedBookIds
                                                        .contains(b.id),
                                                  )
                                                ? null
                                                : false,
                                            onChanged: (value) {
                                              setState(() {
                                                if (value == true) {
                                                  for (final b in
                                                      filteredBooks) {
                                                    _selectedBookIds
                                                        .add(b.id);
                                                  }
                                                } else {
                                                  for (final b in
                                                      filteredBooks) {
                                                    _selectedBookIds
                                                        .remove(b.id);
                                                  }
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataColumn2(
                                      label: _buildHeaderLabel('Cover'),
                                      fixedWidth: 64,
                                    ),
                                    if (showIsbn)
                                      DataColumn2(
                                        label: _buildHeaderLabel('ISBN'),
                                        fixedWidth: 130,
                                      ),
                                    DataColumn2(
                                      label: _buildHeaderLabel('Title'),
                                      fixedWidth: 240,
                                    ),
                                    if (showAuthor)
                                      DataColumn2(
                                        label: _buildHeaderLabel('Author'),
                                        fixedWidth: 180,
                                      ),
                                    if (showRack)
                                      DataColumn2(
                                        label: _buildHeaderLabel('Rack'),
                                        fixedWidth: 70,
                                      ),
                                    if (showCategory)
                                      DataColumn2(
                                        label: _buildHeaderLabel('Category'),
                                        fixedWidth: 120,
                                      ),
                                    if (showCopies)
                                      DataColumn2(
                                        label: _buildHeaderLabel('Copies'),
                                        fixedWidth: 90,
                                      ),
                                    DataColumn2(
                                      label: _buildHeaderLabel('Status'),
                                      fixedWidth: 120,
                                    ),
                                    DataColumn2(
                                      label: _buildHeaderLabel('Actions'),
                                      fixedWidth: 110,
                                    ),
                                  ],
                                  rows: filteredBooks
                                      .asMap()
                                      .entries
                                      .map(
                                        (entry) {
                                          final idx = entry.key;
                                          final book = entry.value;
                                          final baseRowColor = idx.isEven
                                              ? colorScheme.surface
                                              : zebraColor;
                                          final normalizedTitle =
                                              normalizeHindiForDisplay(
                                            book.title,
                                          );
                                          final normalizedAuthor =
                                              normalizeHindiForDisplay(
                                            book.author,
                                          );
                                          final normalizedDescription =
                                              normalizeHindiForDisplay(
                                            book.description ?? '',
                                          );
                                          final isbnValue =
                                              book.isbn.isEmpty ? '-' : book.isbn;
                                          final hasAuthor =
                                              normalizedAuthor.trim().isNotEmpty;
                                          final hasIsbn = isbnValue != '-';
                                          String? secondaryText;
                                          bool secondaryIsMono = false;
                                          if (!showAuthor && !showIsbn) {
                                            final parts = <String>[];
                                            if (hasAuthor) parts.add(normalizedAuthor);
                                            if (hasIsbn) parts.add(isbnValue);
                                            if (parts.isNotEmpty) {
                                              secondaryText = parts.join(' • ');
                                            }
                                          } else if (!showAuthor && hasAuthor) {
                                            secondaryText = normalizedAuthor;
                                          } else if (!showIsbn && hasIsbn) {
                                            secondaryText = isbnValue;
                                            secondaryIsMono = true;
                                          } else if (normalizedDescription.isNotEmpty) {
                                            secondaryText = normalizedDescription;
                                          }
                                          return DataRow(
                                            color:
                                                WidgetStateProperty.resolveWith(
                                              (states) {
                                                if (states.contains(
                                                  WidgetState.hovered,
                                                )) {
                                                  return rowHoverColor;
                                                }
                                                if (states.contains(
                                                  WidgetState.selected,
                                                )) {
                                                  return rowHoverColor
                                                      .withValues(alpha: 0.6);
                                                }
                                                return baseRowColor;
                                              },
                                            ),
                                            selected: _selectedBookIds
                                                .contains(book.id),
                                            onSelectChanged: (selected) {
                                              if (selected == null) return;
                                              setState(() {
                                                if (selected) {
                                                  _selectedBookIds
                                                      .add(book.id);
                                                } else {
                                                  _selectedBookIds
                                                      .remove(book.id);
                                                }
                                              });
                                            },
                                            cells: [
                                              DataCell(
                                                _wrapRowCell(
                                                  idx,
                                                  Center(
                                                    child: Transform.scale(
                                                      scale: 0.9,
                                                      child: Checkbox(
                                                        value:
                                                            _selectedBookIds
                                                                .contains(
                                                          book.id,
                                                        ),
                                                        onChanged: (checked) {
                                                          setState(() {
                                                            if (checked ==
                                                                true) {
                                                              _selectedBookIds
                                                                  .add(book
                                                                      .id);
                                                            } else {
                                                              _selectedBookIds
                                                                  .remove(book
                                                                      .id);
                                                            }
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                  showAccent: true,
                                                ),
                                              ),
                                              DataCell(
                                                _wrapRowCell(
                                                  idx,
                                                  _buildCoverCell(book),
                                                ),
                                              ),
                                              if (showIsbn)
                                                DataCell(
                                                  _wrapRowCell(
                                                    idx,
                                                    Text(
                                                      isbnValue,
                                                      style: GoogleFonts
                                                          .robotoMono(
                                                        fontSize: 12,
                                                        color: isbnTextColor,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              DataCell(
                                                _wrapRowCell(
                                                  idx,
                                                  Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        normalizedTitle,
                                                        style: _textStyleForHindi(
                                                          normalizedTitle,
                                                          GoogleFonts.inter(
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: titleTextColor,
                                                          ),
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      if (secondaryText != null)
                                                        Text(
                                                          secondaryText!,
                                                          style: secondaryIsMono
                                                              ? GoogleFonts
                                                                  .robotoMono(
                                                                  fontSize: 11,
                                                                  color:
                                                                      mutedText,
                                                                )
                                                              : _textStyleForHindi(
                                                                  secondaryText!,
                                                                  GoogleFonts
                                                                      .inter(
                                                                    fontSize:
                                                                        11,
                                                                    color:
                                                                        mutedText,
                                                                  ),
                                                                ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              if (showAuthor)
                                                DataCell(
                                                  _wrapRowCell(
                                                    idx,
                                                    Text(
                                                      normalizedAuthor,
                                                      style: _textStyleForHindi(
                                                        normalizedAuthor,
                                                        GoogleFonts.inter(
                                                          fontSize: 13,
                                                          color:
                                                              authorTextColor,
                                                        ),
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              if (showRack)
                                                DataCell(
                                                  _wrapRowCell(
                                                    idx,
                                                    Container(
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                        horizontal: 10,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFEEF2FF,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(999),
                                                        border: Border.all(
                                                          color: const Color(
                                                            0xFFC7D2FE,
                                                          ),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        (book.rackNumber ?? '-'),
                                                        style: GoogleFonts
                                                            .inter(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: const Color(
                                                            0xFF4338CA,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (showCategory)
                                                DataCell(
                                                  _wrapRowCell(
                                                    idx,
                                                    Text(
                                                      normalizeHindiForDisplay(
                                                        book.category ?? '-',
                                                      ),
                                                      style: _textStyleForHindi(
                                                        normalizeHindiForDisplay(
                                                          book.category ?? '-',
                                                        ),
                                                        GoogleFonts.inter(
                                                          fontSize: 13,
                                                          color:
                                                              categoryTextColor,
                                                        ),
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              if (showCopies)
                                                DataCell(
                                                  _wrapRowCell(
                                                    idx,
                                                    Container(
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFD1FAE5,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            '${book.availableCopies}/${book.totalCopies}',
                                                            style: GoogleFonts
                                                                .inter(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color:
                                                                  const Color(
                                                                0xFF065F46,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Text(
                                                            'avail.',
                                                            style: GoogleFonts
                                                                .inter(
                                                              fontSize: 10,
                                                              color: const Color(
                                                                0xFF3F8F72,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              DataCell(
                                                _wrapRowCell(
                                                  idx,
                                                  _buildStatusBadge(book),
                                                ),
                                              ),
                                              DataCell(
                                                _wrapRowCell(
                                                  idx,
                                                  SizedBox(
                                                    width: 100,
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .end,
                                                      children: [
                                                        _buildActionButton(
                                                          icon:
                                                              Icons.edit_rounded,
                                                          tooltip: 'Edit book',
                                                          onTap: () =>
                                                              _showBookDialog(
                                                            book: book,
                                                          ),
                                                          backgroundColor:
                                                              const Color(
                                                            0xFFFFF7ED,
                                                          ),
                                                          hoverColor:
                                                              const Color(
                                                            0xFFFEF3C7,
                                                          ),
                                                          borderColor:
                                                              const Color(
                                                            0xFFFDE68A,
                                                          ),
                                                          iconColor:
                                                              const Color(
                                                            0xFFD97706,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        _buildActionButton(
                                                          icon:
                                                              Icons.delete_rounded,
                                                          tooltip:
                                                              'Delete book',
                                                          onTap: () =>
                                                              _deleteBook(
                                                            book.id,
                                                          ),
                                                          backgroundColor:
                                                              const Color(
                                                            0xFFFFF1F2,
                                                          ),
                                                          hoverColor:
                                                              const Color(
                                                            0xFFFFE4E6,
                                                          ),
                                                          borderColor:
                                                              const Color(
                                                            0xFFFECDD3,
                                                          ),
                                                          iconColor:
                                                              const Color(
                                                            0xFFE11D48,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      )
                                      .toList(),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: headingRowHeight - 1,
                                  child: Container(
                                    height: 1,
                                    color: headerAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),

            // Pagination controls
            if (!bookProvider.isLoading && bookProvider.books.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: tableBorderColor,
                    ),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 760;
                    final footerTextStyle = GoogleFonts.inter(
                      fontSize: 13,
                      color: mutedText,
                    );
                    final pagePill = Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentTeal,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${bookProvider.currentPage}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    );
                    final pageIndicator = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Page', style: footerTextStyle),
                        const SizedBox(width: 6),
                        pagePill,
                        const SizedBox(width: 6),
                        Text(
                          'of ${bookProvider.totalPages}',
                          style: footerTextStyle,
                        ),
                      ],
                    );
                    final loadMoreButton = OutlinedButton(
                      onPressed: bookProvider.hasMore
                          ? () => bookProvider.loadMoreBooks()
                          : null,
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        side: WidgetStateProperty.all(
                          const BorderSide(color: accentTeal),
                        ),
                        backgroundColor:
                            WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return accentTeal;
                          }
                          return Colors.transparent;
                        }),
                        foregroundColor:
                            WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return Colors.white;
                          }
                          return accentTeal;
                        }),
                        textStyle: WidgetStateProperty.all(
                          GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      child: const Text('+ Load More'),
                    );
                    final pagerButtons = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPagerIconButton(
                          icon: Icons.chevron_left,
                          onPressed: bookProvider.currentPage > 1
                              ? () => bookProvider.loadPage(
                                    bookProvider.currentPage - 1,
                                  )
                              : null,
                          borderColor: tableBorderColor,
                          iconColor: const Color(0xFF475569),
                          hoverFill: rowHoverColor,
                          disabledIconColor: const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 8),
                        _buildPagerIconButton(
                          icon: Icons.chevron_right,
                          onPressed: bookProvider.hasMore
                              ? () => bookProvider.loadPage(
                                    bookProvider.currentPage + 1,
                                  )
                              : null,
                          borderColor: tableBorderColor,
                          iconColor: const Color(0xFF475569),
                          hoverFill: rowHoverColor,
                          disabledIconColor: const Color(0xFF94A3B8),
                        ),
                      ],
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Showing ${bookProvider.books.length} of ${bookProvider.totalBooks} books',
                            style: footerTextStyle,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [pageIndicator, pagerButtons],
                          ),
                          if (bookProvider.hasMore) ...[
                            const SizedBox(height: 10),
                            loadMoreButton,
                          ],
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Showing ${bookProvider.books.length} of ${bookProvider.totalBooks} books',
                            style: footerTextStyle,
                          ),
                        ),
                        Expanded(
                          child: Center(child: pageIndicator),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              pagerButtons,
                              if (bookProvider.hasMore) ...[
                                const SizedBox(width: 12),
                                loadMoreButton,
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Thin vertical divider for the toolbar.
  Widget _buildToolbarDivider(BuildContext context) {
    return Container(
      height: 20,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
    );
  }

  /// Toolbar IconButton with consistent styling
  Widget _buildToolbarIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  /// Table action button with consistent styling
  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color hoverColor,
    required Color borderColor,
    required Color iconColor,
  }) {
    return _ActionIconButton(
      icon: icon,
      tooltip: tooltip,
      onTap: onTap,
      backgroundColor: backgroundColor,
      hoverColor: hoverColor,
      borderColor: borderColor,
      iconColor: iconColor,
    );
  }

  /// Shared search field used across all toolbar layouts.
  Widget _buildSearchField({
    required TextEditingController controller,
    required Color tableBorderColor,
    required Color searchFill,
    required Color mutedText,
    required Color accentTeal,
    String hintText = 'Search books...',
  }) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(fontSize: 14),
      cursorColor: accentTeal,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  controller.clear();
                  _filterBooks();
                  setState(() {});
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tableBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tableBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentTeal, width: 1.2),
        ),
        filled: true,
        fillColor: searchFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
        hintStyle: GoogleFonts.inter(fontSize: 13, color: mutedText),
      ),
      onChanged: (value) {
        _searchDebounce?.cancel();
        _searchDebounce = Timer(const Duration(milliseconds: 350), _filterBooks);
        setState(() {});
      },
    );
  }

  /// Shared toolbar action buttons row used in compact and medium layouts.
  Widget _buildToolbarActions({
    required BookProvider bookProvider,
    required int selectedCount,
    required Color accentTeal,
    required ColorScheme colorScheme,
    bool compactLabels = false,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCategoryFilterPopup(bookProvider),
          const SizedBox(width: 4),
          if (selectedCount > 0) ...[
            _buildToolbarIconButton(
              icon: Icons.delete_forever,
              tooltip: 'Delete ($selectedCount)',
              onPressed: _deleteSelectedBooks,
              color: colorScheme.error,
            ),
            _buildToolbarIconButton(
              icon: Icons.clear,
              tooltip: 'Clear selection',
              onPressed: () => setState(_selectedBookIds.clear),
            ),
          ],
          _buildToolbarDivider(context),
          _buildToolbarIconButton(
            icon: Icons.category,
            tooltip: 'Manage Categories',
            onPressed: _showCategoryManagement,
            color: colorScheme.primary,
          ),
          _buildToolbarIconButton(
            icon: Icons.upload_file,
            tooltip: 'Import CSV/Excel',
            onPressed: _importBooks,
          ),
          _buildToolbarIconButton(
            icon: Icons.download,
            tooltip: 'Export CSV',
            onPressed: _exportBooksCsv,
          ),
          _buildToolbarIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh',
            onPressed: _loadBooks,
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _showBookDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: Text(compactLabels ? 'Add' : 'Add Book'),
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) return const Color(0xFF137A5A);
                if (states.contains(WidgetState.hovered)) return const Color(0xFF168B66);
                return accentTeal;
              }),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar({
    required BookProvider bookProvider,
    required int selectedCount,
    required double screenWidth,
    required bool isVeryCompact,
    required bool isMedium,
    required Color accentTeal,
    required Color tableBorderColor,
    required Color searchFill,
    required Color mutedText,
    required ColorScheme colorScheme,
  }) {
    if (isVeryCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchField(
            controller: _searchController,
            tableBorderColor: tableBorderColor,
            searchFill: searchFill,
            mutedText: mutedText,
            accentTeal: accentTeal,
          ),
          const SizedBox(height: 10),
          _buildToolbarActions(
            bookProvider: bookProvider,
            selectedCount: selectedCount,
            accentTeal: accentTeal,
            colorScheme: colorScheme,
            compactLabels: true,
          ),
        ],
      );
    }

    if (isMedium) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchField(
            controller: _searchController,
            tableBorderColor: tableBorderColor,
            searchFill: searchFill,
            mutedText: mutedText,
            accentTeal: accentTeal,
          ),
          const SizedBox(height: 10),
          _buildToolbarActions(
            bookProvider: bookProvider,
            selectedCount: selectedCount,
            accentTeal: accentTeal,
            colorScheme: colorScheme,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _buildSearchField(
            controller: _searchController,
            tableBorderColor: tableBorderColor,
            searchFill: searchFill,
            mutedText: mutedText,
            accentTeal: accentTeal,
          ),
        ),
        const SizedBox(width: 10),
        _buildCategoryFilterPopup(bookProvider),
        if (selectedCount > 0) ...[
          _buildToolbarDivider(context),
          _buildToolbarIconButton(
            icon: Icons.delete_forever,
            tooltip: 'Delete ($selectedCount)',
            onPressed: _deleteSelectedBooks,
            color: colorScheme.error,
          ),
          _buildToolbarIconButton(
            icon: Icons.clear,
            tooltip: 'Clear selection',
            onPressed: () => setState(_selectedBookIds.clear),
          ),
        ],
        _buildToolbarDivider(context),
        _buildToolbarIconButton(
          icon: Icons.category,
          tooltip: 'Manage Categories',
          onPressed: _showCategoryManagement,
          color: colorScheme.primary,
        ),
        _buildToolbarIconButton(
          icon: Icons.upload_file,
          tooltip: 'Import CSV/Excel',
          onPressed: _importBooks,
        ),
        _buildToolbarIconButton(
          icon: Icons.download,
          tooltip: 'Export CSV',
          onPressed: _exportBooksCsv,
        ),
        _buildToolbarIconButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onPressed: _loadBooks,
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => _showBookDialog(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Book'),
          style: ButtonStyle(
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) return const Color(0xFF137A5A);
              if (states.contains(WidgetState.hovered)) return const Color(0xFF168B66);
              return accentTeal;
            }),
            foregroundColor: WidgetStateProperty.all(Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilterPopup(BookProvider bookProvider) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: PopupMenuButton<String>(
        onSelected: (value) {
          setState(
            () => _selectedCategory =
                value == 'All Categories' ? null : value,
          );
          _filterBooks();
        },
        itemBuilder: (context) {
          final categories = getUniqueCategories(bookProvider.books);
          return categories.map((category) {
            final isSelected = (_selectedCategory == null &&
                    category == 'All Categories') ||
                (_selectedCategory == category);
            return PopupMenuItem<String>(
              value: category,
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    size: 20,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_list,
                  color: Theme.of(context).colorScheme.primary, size: 20),
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
              Icon(Icons.arrow_drop_down,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20),
            ],
          ),
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
          // Refresh categories and books to reflect changes
          _loadApiCategories();
          ApiService.clearCategoriesCache();
          _loadBooks();
        },
      ),
    );
  }

  void _showBookDialog({Book? book}) async {
    final bookProvider = context.read<BookProvider>();
    final issueProvider = context.read<IssueProvider>();
    final result = await showDialog(
      context: context,
      builder: (context) => BookDialog(book: book),
    );
    if (mounted && result == true) {
      await bookProvider.loadBooks();
      await issueProvider.loadStats();
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
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
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
        if (navigator.canPop()) navigator.pop();
        return;
      }

      // Use server-side export for better performance with large datasets
      // Server already adds BOM for UTF-8 compatibility
      final csvBytes = await ApiService.exportData('books', format: 'csv');
      await File(path).writeAsBytes(csvBytes, flush: true);

      if (!mounted) return;
      if (navigator.canPop()) navigator.pop();

      messenger.showSnackBar(SnackBar(content: Text('Exported CSV to: $path')));
    } catch (e) {
      if (!mounted) return;
      if (navigator.canPop()) navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(getOperationErrorMessage('Export', e))));
    }
  }

  void _deleteBook(int id) {
    final bookProvider = context.read<BookProvider>();
    final issueProvider = context.read<IssueProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: cs.error),
            const SizedBox(width: 8),
            const Text('Delete Book'),
          ],
        ),
        content: const Text('Are you sure you want to delete this book?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await bookProvider.deleteBook(id);

                if (!mounted) return;
                setState(() => _selectedBookIds.remove(id));

                // Reload books to reflect deletion in UI
                await bookProvider.loadBooks();
                await issueProvider.loadStats();
                if (!mounted) return;

                messenger.clearSnackBars();
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('Book deleted successfully'),
                    duration: const Duration(seconds: 5),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
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

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final bookProvider = context.read<BookProvider>();
    final issueProvider = context.read<IssueProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
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
      context: context,
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
      // Use optimized bulk delete API
      final result = await ApiService.bulkDeleteBooks(ids);
      final deletedCount = result['deleted'] ?? 0;

      if (!mounted) return;
      navigator.pop();

      // Refresh data after bulk delete
      await bookProvider.loadBooks();
      await issueProvider.loadStats();

      if (!mounted) return;
      setState(() => _selectedBookIds.clear());

      messenger.showSnackBar(
        SnackBar(
          content: Text('Deleted $deletedCount book(s) successfully.'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      navigator.maybePop();
      messenger.showSnackBar(SnackBar(content: Text(getOperationErrorMessage('Bulk delete', e))));
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

  Widget _buildStatusBadge(Book book) {
    final isAvailable = book.availableCopies > 0;
    final background =
        isAvailable ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    final border =
        isAvailable ? const Color(0xFF6EE7B7) : const Color(0xFFFECACA);
    final textColor =
        isAvailable ? const Color(0xFF059669) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _statusPulse,
            builder: (context, child) {
              final scale = 0.85 + (_statusPulse.value * 0.35);
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: textColor,
                boxShadow: [
                  BoxShadow(
                    color: textColor.withValues(alpha: 0.35),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isAvailable ? 'Available' : 'Unavailable',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverCell(Book book) {
    return Container(
      width: 40,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: book.coverImage != null && book.coverImage!.isNotEmpty
            ? Image.network(
                ApiService.resolvePublicUrl(book.coverImage!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildCoverPlaceholder(book),
              )
            : _buildCoverPlaceholder(book),
      ),
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
    _searchDebounce?.cancel();
    _dataChangedSub?.cancel();
    _searchController.dispose();
    _statusPulseController.dispose();
    DashboardScreen.shortcutEvent.removeListener(_onShortcutEvent);
    super.dispose();
  }
}

class _ActionIconButton extends StatefulWidget {
  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.backgroundColor,
    required this.hoverColor,
    required this.borderColor,
    required this.iconColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color hoverColor;
  final Color borderColor;
  final Color iconColor;

  @override
  State<_ActionIconButton> createState() => _ActionIconButtonState();
}

class _ActionIconButtonState extends State<_ActionIconButton> {
  bool _hovered = false;
  static const _duration = Duration(milliseconds: 150);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: _hovered ? 1.05 : 1.0,
          duration: _duration,
          curve: Curves.easeInOut,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: _duration,
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      _hovered ? widget.hoverColor : widget.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: widget.borderColor),
                ),
                child: Icon(
                  widget.icon,
                  size: 18,
                  color: widget.iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: cs.error),
              const SizedBox(width: 8),
              const Text('Delete Category'),
            ],
          ),
          content: Text('Are you sure you want to delete "${cat.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
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
                    Icon(Icons.category,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Manage Categories',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle,
                          color: Theme.of(context).colorScheme.onPrimary),
                      tooltip: 'Add Category',
                      onPressed: _addCategory,
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: Theme.of(context).colorScheme.onPrimary),
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
