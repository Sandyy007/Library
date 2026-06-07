import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../providers/issue_provider.dart';
import '../providers/book_provider.dart';
import '../providers/member_provider.dart';
import '../providers/auth_provider.dart';
import '../models/book.dart';
import '../models/member.dart';
import '../utils/date_formatter.dart';
import '../utils/hindi_text.dart';
import '../utils/hindi_pdf_helper.dart';
import '../services/api_service.dart';
import '../utils/error_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/responsive.dart';
import '../widgets/common_widgets.dart';
import '../screens/dashboard_screen.dart';
import 'borrow_slip_preview.dart';

enum _IssueDialogActiveField { book, member }

class IssuesContent extends StatefulWidget {
  const IssuesContent({super.key});

  @override
  State<IssuesContent> createState() => _IssuesContentState();
}

class _IssuesContentState extends State<IssuesContent> {
  final TextEditingController _searchController = TextEditingController();
  List filteredIssues = [];
  Timer? _searchDebounceTimer;
  StreamSubscription<void>? _dataChangedSub;

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

  Future<T?> _showSearchPicker<T>({
    required BuildContext context,
    required String title,
    required List<T> items,
    required String Function(T item) labelFor,
    required bool Function(T item, String query) matches,
    String initialQuery = '',
    int maxInitialItems = 50,
  }) async {
    final queryController = TextEditingController(text: initialQuery);
    final focusNode = FocusNode();

    List<T> filtered(String q) {
      final query = q.trim().toLowerCase();
      if (query.isEmpty) {
        return items.take(maxInitialItems).toList();
      }
      return items.where((item) => matches(item, query)).toList();
    }

    T? selected;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final results = filtered(queryController.text);
          final pickerWidth = MediaQuery.of(context).size.width;
          final effectiveWidth = pickerWidth < 580 ? pickerWidth * 0.9 : 520.0;
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: effectiveWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: queryController,
                    focusNode: focusNode,
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Type to search...',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: results.isEmpty
                        ? const Center(child: Text('No matches'))
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: results.length,
                            separatorBuilder: (_, i) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = results[index];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  labelFor(item),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  selected = item;
                                  Navigator.of(context).pop();
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );

    queryController.dispose();
    focusNode.dispose();
    return selected;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
    // Listen for data changes from other components
    _dataChangedSub = ApiService.dataChangedStream.listen((_) {
      _loadAllData();
    });
    // Listen for keyboard shortcut events
    DashboardScreen.shortcutEvent.addListener(_onShortcutEvent);
  }

  void _onShortcutEvent() {
    if (DashboardScreen.shortcutEvent.value == 'new-issue') {
      final bookProvider = context.read<BookProvider>();
      final memberProvider = context.read<MemberProvider>();
      _showIssueDialog(context, bookProvider.books, memberProvider.members);
    }
  }

  void _loadAllData() {
    try {
      context.read<IssueProvider>().loadIssues().catchError((error) {
        if (kDebugMode) debugPrint('Error loading issues: $error');
      });
      context.read<BookProvider>().loadBooks().catchError((error) {
        if (kDebugMode) debugPrint('Error loading books: $error');
      });
      context.read<MemberProvider>().loadMembers().catchError((error) {
        if (kDebugMode) debugPrint('Error loading members: $error');
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error in loadAllData: $e');
    }
  }

  List getFilteredIssues(List issues, List books, List members) {
    final rawQuery = _searchController.text;
    if (rawQuery.trim().isEmpty) return issues;

    final query = rawQuery.toLowerCase();
    // Normalize query for Hindi matching (converts Krutidev query to Unicode)
    final normalizedQuery = normalizeHindiForDisplay(rawQuery).toLowerCase();
    // Convert Unicode Hindi query to KrutiDev for matching legacy data
    final krutiDevQuery = unicodeToKrutiDevApprox(rawQuery).toLowerCase();

    return issues.where((issue) {
      final book = books.firstWhere(
        (b) => b.id == issue.bookId,
        orElse: () => Book(
          id: 0,
          isbn: '',
          title: '',
          author: '',
          category: '',
          status: 'available',
          addedDate: '',
        ),
      );
      final member = members.firstWhere(
        (m) => m.id == issue.memberId,
        orElse: () => Member(
          id: 0,
          name: '',
          email: '',
          phone: '',
          memberType: 'student',
          membershipDate: '',
        ),
      );

      // Normalize book and member names for Hindi matching
      final normalizedTitle = normalizeHindiForDisplay(
        book.title,
      ).toLowerCase();
      final normalizedAuthor = normalizeHindiForDisplay(
        book.author,
      ).toLowerCase();
      final normalizedMemberName = normalizeHindiForDisplay(
        member.name,
      ).toLowerCase();
      final rawTitle = book.title.toLowerCase();
      final rawAuthor = book.author.toLowerCase();
      final rawMemberName = member.name.toLowerCase();

      // Comprehensive matching: support all Hindi encodings
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

      final matchesMember =
          rawMemberName.contains(query) ||
          normalizedMemberName.contains(query) ||
          normalizedMemberName.contains(normalizedQuery) ||
          rawMemberName.contains(krutiDevQuery);

      final matchesIsbn = book.isbn.toLowerCase().contains(query);
      final matchesPhone = (member.phone ?? '').contains(query);
      final matchesStatus = issue.status.toLowerCase().contains(query);

      return matchesTitle ||
          matchesAuthor ||
          matchesMember ||
          matchesIsbn ||
          matchesPhone ||
          matchesStatus;
    }).toList();
  }

  void _filterIssues() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _dataChangedSub?.cancel();
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    DashboardScreen.shortcutEvent.removeListener(_onShortcutEvent);
    super.dispose();
  }

  /// Table action button with consistent dark-theme-aware styling
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        child: StatefulBuilder(
          builder: (context, setHoverState) => Material(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReturnButtonFor(int issueId, ColorScheme colorScheme) {
    final returnColor = colorScheme.primary;
    return Tooltip(
      message: 'Return Book',
      child: Material(
        color: returnColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _returnBook(context, issueId),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            constraints: const BoxConstraints(minWidth: 70),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assignment_return, size: 14, color: returnColor),
                const SizedBox(width: 4),
                Text(
                  'Return',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: returnColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Toolbar IconButton with consistent styling (matching books/members)
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

  @override
  Widget build(BuildContext context) {
    final issueProvider = Provider.of<IssueProvider>(context);
    final bookProvider = Provider.of<BookProvider>(context);
    final memberProvider = Provider.of<MemberProvider>(context);
    final r = Responsive(context);
    final screenWidth = r.width;
    final isCompact = r.isCompact;
    final isMedium = r.isMedium;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const accentTeal = Color(0xFF1D9E75);
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
    final searchFill = isDark
      ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
      : const Color(0xFFF7FAFB);
    final rowHoverColor = isDark
      ? colorScheme.primary.withValues(alpha: 0.12)
      : const Color(0xFFF0FAF7);
    final zebraColor = isDark
      ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.18)
      : const Color(0xFFFAFAFA);
    final headerAccent = isDark
      ? colorScheme.primary.withValues(alpha: 0.45)
      : const Color(0xFFBFE9E3);

    final filteredIssues = getFilteredIssues(
      issueProvider.issues,
      bookProvider.books,
      memberProvider.members,
    );

    const headingRowHeight = 54.0;

    final showMember = screenWidth >= 780;
    final showIssueDate = screenWidth >= 640;
    final showDueDate = screenWidth >= 720;
    final showReturnDate = screenWidth >= 840;
    final showStatus = true;
    final columnWidths = <double>[
      240,
      if (showMember) 180,
      if (showIssueDate) 120,
      if (showDueDate) 120,
      if (showReturnDate) 120,
      if (showStatus) 105,
      240,
    ];
    final minTableWidth = columnWidths.fold(0.0, (sum, w) => sum + w);

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(r.pagePadding),
        child: Column(
          children: [
            // Search, Filter, and Action buttons
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
              child: _buildIssuesToolbar(
                bookProvider: bookProvider,
                memberProvider: memberProvider,
                isCompact: isCompact,
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
                  child: issueProvider.isLoading
                      ? const ShimmerTable(rows: 8, columns: 5)
                      : issueProvider.error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 72,
                                  color: colorScheme.error.withValues(alpha: 0.6),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Unable to load issues',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  issueProvider.error!,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    ElevatedButton(
                                      onPressed: _loadAllData,
                                      child: const Text('Retry'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => context.read<AuthProvider>().logout(),
                                      child: const Text('Login Again'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                      : filteredIssues.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.assignment_outlined,
                          title: 'No issues found',
                          subtitle: 'Click "Issue Book" to create a new issue',
                          actionLabel: 'Retry',
                          onAction: _loadAllData,
                        )
                      : Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: isDark
                                ? colorScheme.outlineVariant.withValues(alpha: 0.35)
                                : const Color(0xFFF0F0F0),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: MouseRegion(
                            onExit: (_) { if (_hoveredRowIndex != null) setState(() => _hoveredRowIndex = null); },
                            child: Stack(
                              children: [
                                DataTable2(
                                  columnSpacing: 12,
                                  horizontalMargin: 12,
                                  dataRowHeight: 70,
                                  headingRowHeight: headingRowHeight,
                                  showCheckboxColumn: false,
                                  minWidth: minTableWidth,
                                  fixedTopRows: 1,
                                  headingRowColor: WidgetStateProperty.all(headerBackground),
                                  dividerThickness: 0.5,
                                  columns: [
                                    DataColumn2(
                                      label: _buildIssuesHeaderLabel('Book'),
                                      fixedWidth: columnWidths[0],
                                    ),
                                    if (showMember)
                                      DataColumn2(
                                        label: _buildIssuesHeaderLabel('Member'),
                                        fixedWidth: columnWidths[1],
                                      ),
                                    if (showIssueDate)
                                      DataColumn2(
                                        label: _buildIssuesHeaderLabel('Issue Date'),
                                        fixedWidth: columnWidths[showMember ? 2 : 1],
                                      ),
                                    if (showDueDate)
                                      DataColumn2(
                                        label: _buildIssuesHeaderLabel('Due Date'),
                                        fixedWidth: columnWidths[showMember && showIssueDate ? 3 : (showMember || showIssueDate ? 2 : 1)],
                                      ),
                                    if (showReturnDate)
                                      DataColumn2(
                                        label: _buildIssuesHeaderLabel('Return'),
                                        fixedWidth: columnWidths[showMember && showIssueDate && showDueDate ? 4 : 3],
                                      ),
                                    if (showStatus)
                                      DataColumn2(
                                        label: _buildIssuesHeaderLabel('Status'),
                                        fixedWidth: 105,
                                      ),
                                    DataColumn2(
                                      label: Align(
                                        alignment: Alignment.centerRight,
                                        child: _buildIssuesHeaderLabel('Actions'),
                                      ),
                                      fixedWidth: 240,
                                    ),
                                  ],
                                  rows: filteredIssues.toList().asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final issue = entry.value;
                                    final statusColor = issue.status == 'returned'
                                        ? const Color(0xFF10B981)
                                        : (issue.status == 'overdue'
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFFF59E0B));
                                    final baseRowColor = idx.isEven ? colorScheme.surface : zebraColor;

                                    String? secondaryText;
                                    String? metaText;
                                    if (!showMember) {
                                      secondaryText = normalizeHindiForDisplay(issue.memberName);
                                    }
                                    if (!showIssueDate) {
                                      metaText = 'Issued: ${DateFormatter.formatDateIndian(issue.issueDate)}';
                                    } else if (!showDueDate) {
                                      metaText = 'Due: ${DateFormatter.formatDateIndian(issue.dueDate)}';
                                    }

                                    return DataRow(
                                      color: WidgetStateProperty.resolveWith((states) {
                                        if (states.contains(WidgetState.hovered)) return rowHoverColor;
                                        return baseRowColor;
                                      }),
                                      cells: [
                                        DataCell(
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                          Text(
                                                normalizeHindiForDisplay(issue.bookTitle),
                                                style: _textStyleForHindi(
                                                  normalizeHindiForDisplay(issue.bookTitle),
                                                  TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: isDark ? colorScheme.onSurface : const Color(0xFF1A1A2E),
                                                  ),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (secondaryText != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Text(
                                                    secondaryText,
                                                    style: _textStyleForHindi(
                                                      secondaryText,
                                                      TextStyle(
                                                        fontSize: 11,
                                                        color: mutedText,
                                                      ),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              if (metaText != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 1),
                                                  child: Text(
                                                    metaText,
                                                    style: _textStyleForHindi(
                                                      metaText,
                                                      TextStyle(fontSize: 10, color: mutedText.withValues(alpha: 0.7)),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                        if (showMember)
                                          DataCell(
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 180),
                                              child: Text(
                                                normalizeHindiForDisplay(issue.memberName),
                                                style: _textStyleForHindi(
                                                  normalizeHindiForDisplay(issue.memberName),
                                                  TextStyle(
                                                    fontSize: 13,
                                                    color: isDark ? colorScheme.onSurfaceVariant.withValues(alpha: 0.85) : const Color(0xFF666666),
                                                  ),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        if (showIssueDate)
                                          DataCell(Text(
                                            DateFormatter.formatDateIndian(issue.issueDate),
                                            style: TextStyle(fontSize: 12, color: mutedText),
                                          )),
                                        if (showDueDate)
                                          DataCell(Text(
                                            DateFormatter.formatDateIndian(issue.dueDate),
                                            style: TextStyle(fontSize: 12, color: mutedText),
                                          )),
                                        if (showReturnDate)
                                          DataCell(Text(
                                            issue.returnDate != null
                                                ? DateFormatter.formatDateIndian(issue.returnDate)
                                                : '-',
                                            style: TextStyle(fontSize: 12, color: mutedText),
                                          )),
                                        if (showStatus)
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 6, height: 6,
                                                    decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    issue.status[0].toUpperCase() + issue.status.substring(1),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: statusColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        DataCell(
                                          SizedBox(
                                            width: 230,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                _buildActionButton(
                                                  icon: Icons.description_outlined,
                                                  color: accentTeal,
                                                  tooltip: 'Generate Slip',
                                                  onTap: () => _generateBorrowSlip(context, issue),
                                                ),
                                                const SizedBox(width: 4),
                                                _buildActionButton(
                                                  icon: Icons.edit_outlined,
                                                  color: const Color(0xFFD97706),
                                                  tooltip: 'Edit Issue',
                                                  onTap: () => _showEditIssueDialog(context, issue),
                                                ),
                                                const SizedBox(width: 4),
                                                _buildActionButton(
                                                  icon: Icons.delete_outlined,
                                                  color: const Color(0xFFE11D48),
                                                  tooltip: 'Delete Issue',
                                                  onTap: () => _showDeleteIssueDialog(context, issue),
                                                ),
                                                const SizedBox(width: 4),
                                                if (issue.status == 'issued' || issue.status == 'overdue')
                                                  _buildReturnButtonFor(issue.id, colorScheme)
                                                else
                                                  const SizedBox(width: 0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                                Positioned(
                                  left: 0, right: 0,
                                  top: headingRowHeight - 1,
                                  child: Container(height: 1, color: headerAccent),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),

            // Pagination controls
            if (!issueProvider.isLoading && issueProvider.issues.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(top: BorderSide(color: tableBorderColor)),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 760;
                    final footerTextStyle = TextStyle(fontSize: 13, color: mutedText);
                    final pagePill = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: accentTeal, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        '${issueProvider.currentPage}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    );
                    final pageIndicator = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Page', style: footerTextStyle),
                        const SizedBox(width: 6),
                        pagePill,
                        const SizedBox(width: 6),
                        Text('of ${issueProvider.totalPages}', style: footerTextStyle),
                      ],
                    );
                    final loadMoreButton = OutlinedButton(
                      onPressed: issueProvider.hasMore ? () => issueProvider.loadMoreIssues() : null,
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        side: WidgetStateProperty.all(const BorderSide(color: accentTeal)),
                        backgroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.hovered)) return accentTeal;
                          return Colors.transparent;
                        }),
                        foregroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.hovered)) return Colors.white;
                          return accentTeal;
                        }),
                        textStyle: WidgetStateProperty.all(TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      child: const Text('+ Load More'),
                    );
                    final pagerButtons = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPagerIconButton(
                          icon: Icons.chevron_left,
                          onPressed: issueProvider.currentPage > 1
                              ? () => issueProvider.loadPage(issueProvider.currentPage - 1) : null,
                          borderColor: tableBorderColor,
                          iconColor: const Color(0xFF475569),
                          hoverFill: rowHoverColor,
                          disabledIconColor: const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 8),
                        _buildPagerIconButton(
                          icon: Icons.chevron_right,
                          onPressed: issueProvider.hasMore
                              ? () => issueProvider.loadPage(issueProvider.currentPage + 1) : null,
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
                          Text('Showing ${filteredIssues.length} of ${issueProvider.totalIssues} issues', style: footerTextStyle),
                          const SizedBox(height: 10),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [pageIndicator, pagerButtons]),
                          if (issueProvider.hasMore) ...[const SizedBox(height: 10), loadMoreButton],
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: Text('Showing ${filteredIssues.length} of ${issueProvider.totalIssues} issues', style: footerTextStyle)),
                        Expanded(child: Center(child: pageIndicator)),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              pagerButtons,
                              if (issueProvider.hasMore) ...[const SizedBox(width: 12), loadMoreButton],
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

  int? _hoveredRowIndex;

  Widget _buildIssuesHeaderLabel(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8)
        : const Color(0xFF6B7280);
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: color,
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
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        side: WidgetStateProperty.resolveWith((states) => BorderSide(
          color: enabled ? borderColor : borderColor.withValues(alpha: 0.45),
        )),
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

  Widget _buildIssuesSearchField({
    required TextEditingController controller,
    required Color tableBorderColor,
    required Color searchFill,
    required Color mutedText,
    required Color accentTeal,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(fontSize: 14),
      cursorColor: accentTeal,
      decoration: InputDecoration(
        hintText: 'Search issues...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  controller.clear();
                  _filterIssues();
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
        hintStyle: TextStyle(fontSize: 13, color: mutedText),
      ),
      onChanged: (value) => _filterIssues(),
    );
  }

  Widget _buildIssuesToolbarActions({
    required BookProvider bookProvider,
    required MemberProvider memberProvider,
    required Color accentTeal,
    required ColorScheme colorScheme,
    bool compactLabels = false,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildToolbarIconButton(
            icon: Icons.picture_as_pdf_rounded,
            tooltip: 'Export PDF',
            onPressed: () => _exportIssuesPdf(context),
            color: colorScheme.error,
          ),
          _buildToolbarIconButton(
            icon: Icons.table_view_rounded,
            tooltip: 'Export CSV',
            onPressed: () => _exportIssuesCsv(context),
            color: colorScheme.tertiary,
          ),
          _buildToolbarIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh',
            onPressed: _loadAllData,
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _showIssueDialog(
              context,
              bookProvider.books,
              memberProvider.members,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(compactLabels ? 'Issue' : 'Issue Book'),
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

  Widget _buildIssuesToolbar({
    required BookProvider bookProvider,
    required MemberProvider memberProvider,
    required bool isCompact,
    required bool isMedium,
    required Color accentTeal,
    required Color tableBorderColor,
    required Color searchFill,
    required Color mutedText,
    required ColorScheme colorScheme,
  }) {
    final searchField = _buildIssuesSearchField(
      controller: _searchController,
      tableBorderColor: tableBorderColor,
      searchFill: searchFill,
      mutedText: mutedText,
      accentTeal: accentTeal,
    );
    final actions = _buildIssuesToolbarActions(
      bookProvider: bookProvider,
      memberProvider: memberProvider,
      accentTeal: accentTeal,
      colorScheme: colorScheme,
      compactLabels: isCompact,
    );

    if (isCompact || isMedium) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchField,
          const SizedBox(height: 10),
          actions,
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 3, child: searchField),
        const SizedBox(width: 10),
        actions,
      ],
    );
  }

  Future<void> _showIssueDialog(
    BuildContext context,
    List<Book> books, // ignored - we fetch all books directly
    List<Member> members,
  ) async {
    final issueProvider = context.read<IssueProvider>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    int? selectedBookId;
    int? selectedMemberId;
    final selectedBookController = TextEditingController();
    final selectedMemberController = TextEditingController();

    var activeField = _IssueDialogActiveField.book;

    String dueDate = DateTime.now()
        .add(const Duration(days: 14))
        .toIso8601String()
        .split('T')[0];
    final dueController = TextEditingController(text: dueDate);

    // Fetch ALL available books directly to ensure all Hindi books are included
    List<Book> allBooks;
    try {
      allBooks = await ApiService.getBooks(available: true);
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching all books: $e');
      // Fallback to passed books if API fails
      allBooks = books;
    }
    final availableBooks = allBooks.where((b) => b.status == 'available').toList();

    Future<void> pickBook({String initialQuery = ''}) async {
      final picked = await _showSearchPicker<Book>(
        context: context,
        title: 'Select Book',
        items: availableBooks,
        labelFor: (b) {
          // Display normalized Hindi text
          final title = normalizeHindiForDisplay(b.title);
          final author = normalizeHindiForDisplay(b.author);
          return '$title by $author';
        },
        matches: (b, q) {
          // Raw and normalized text for comprehensive Hindi matching
          final rawTitle = b.title.toLowerCase();
          final rawAuthor = b.author.toLowerCase();
          final rawIsbn = b.isbn.toLowerCase();
          final rawCategory = (b.category ?? '').toLowerCase();
          
          // Normalize for Hindi text matching
          final normalizedTitle = normalizeHindiForDisplay(b.title).toLowerCase();
          final normalizedAuthor = normalizeHindiForDisplay(b.author).toLowerCase();
          final normalizedCategory = normalizeHindiForDisplay(b.category ?? '').toLowerCase();
          final normalizedQuery = normalizeHindiForDisplay(q).toLowerCase();
          final krutiDevQuery = unicodeToKrutiDevApprox(q).toLowerCase();
          
          // Match raw, normalized, and krutidev variants
          return rawTitle.contains(q) ||
              rawAuthor.contains(q) ||
              rawIsbn.contains(q) ||
              rawCategory.contains(q) ||
              normalizedTitle.contains(q) ||
              normalizedAuthor.contains(q) ||
              normalizedCategory.contains(q) ||
              normalizedTitle.contains(normalizedQuery) ||
              normalizedAuthor.contains(normalizedQuery) ||
              rawTitle.contains(krutiDevQuery) ||
              rawAuthor.contains(krutiDevQuery);
        },
        initialQuery: initialQuery,
      );
      if (picked == null) return;
      selectedBookId = picked.id;
      selectedBookController.text = '${picked.title} by ${picked.author}';
    }

    Future<void> pickMember({String initialQuery = ''}) async {
      final picked = await _showSearchPicker<Member>(
        context: context,
        title: 'Select Member',
        items: members,
        labelFor: (m) => m.name,
        matches: (m, q) {
          final name = m.name.toLowerCase();
          final email = (m.email ?? '').toLowerCase();
          final phone = (m.phone ?? '').toLowerCase();
          return name.contains(q) || email.contains(q) || phone.contains(q);
        },
        initialQuery: initialQuery,
      );
      if (picked == null) return;
      selectedMemberId = picked.id;
      selectedMemberController.text = picked.name;
    }

    try {
      if (!mounted) return;
      await showDialog<void>(
        // ignore: use_build_context_synchronously
        context: this.context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setState) => Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;

              final pressed = HardwareKeyboard.instance.logicalKeysPressed;
              final ctrlPressed =
                  pressed.contains(LogicalKeyboardKey.controlLeft) ||
                  pressed.contains(LogicalKeyboardKey.controlRight);
              final altPressed =
                  pressed.contains(LogicalKeyboardKey.altLeft) ||
                  pressed.contains(LogicalKeyboardKey.altRight);
              final metaPressed =
                  pressed.contains(LogicalKeyboardKey.metaLeft) ||
                  pressed.contains(LogicalKeyboardKey.metaRight);

              // Convenience shortcuts
              if (ctrlPressed && event.logicalKey == LogicalKeyboardKey.keyB) {
                activeField = _IssueDialogActiveField.book;
                pickBook().then((_) {
                  if (mounted) setState(() {});
                });
                return KeyEventResult.handled;
              }
              if (ctrlPressed && event.logicalKey == LogicalKeyboardKey.keyM) {
                activeField = _IssueDialogActiveField.member;
                pickMember().then((_) {
                  if (mounted) setState(() {});
                });
                return KeyEventResult.handled;
              }

              final ch = event.character;
              final isPrintable =
                  ch != null && ch.isNotEmpty && ch.codeUnitAt(0) >= 32;
              if (isPrintable && !ctrlPressed && !metaPressed && !altPressed) {
                final initial = ch.trim();
                if (initial.isNotEmpty) {
                  if (activeField == _IssueDialogActiveField.member) {
                    pickMember(initialQuery: initial).then((_) {
                      if (mounted) setState(() {});
                    });
                  } else {
                    pickBook(initialQuery: initial).then((_) {
                      if (mounted) setState(() {});
                    });
                  }
                  return KeyEventResult.handled;
                }
              }

              return KeyEventResult.ignored;
            },
            child: Dialog(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(dialogContext).size.width < 600
                      ? MediaQuery.of(dialogContext).size.width * 0.95
                      : 500,
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.8,
                ),
                child: Card(
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
                                'Issue Book',
                                style: Theme.of(
                                  dialogContext,
                                ).textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextFormField(
                                controller: selectedBookController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Book',
                                  hintText:
                                      'Type to search (or click to select)',
                                  suffixIcon: Icon(Icons.arrow_drop_down),
                                ),
                                onTap: () async {
                                  activeField = _IssueDialogActiveField.book;
                                  await pickBook();
                                  if (!mounted) return;
                                  setState(() {});
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: selectedMemberController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Member',
                                  hintText:
                                      'Type to search (or click to select)',
                                  suffixIcon: Icon(Icons.arrow_drop_down),
                                ),
                                onTap: () async {
                                  activeField = _IssueDialogActiveField.member;
                                  await pickMember();
                                  if (!mounted) return;
                                  setState(() {});
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: dueController,
                                decoration: const InputDecoration(
                                  labelText: 'Due Date',
                                ),
                                readOnly: true,
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: dialogContext,
                                    initialDate: DateTime.now().add(
                                      const Duration(days: 14),
                                    ),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 365),
                                    ),
                                  );
                                  if (date != null) {
                                    setState(() {
                                      dueDate = date.toIso8601String().split(
                                        'T',
                                      )[0];
                                      dueController.text = dueDate;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
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
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                if (selectedBookId != null &&
                                    selectedMemberId != null) {
                                  final int bookId = selectedBookId!;
                                  final int memberId = selectedMemberId!;
                                  Navigator.of(dialogContext).pop();
                                  try {
                                    await issueProvider
                                        .issueBook(bookId, memberId, dueDate);
                                    if (mounted) {
                                      messenger?.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Book issued successfully! Use the slip button to generate a borrow slip.',
                                          ),
                                          duration: Duration(seconds: 4),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      messenger?.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            getOperationErrorMessage('Issue book', e),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              child: const Text('Issue'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      selectedBookController.dispose();
      selectedMemberController.dispose();
      dueController.dispose();
    }
  }

  Future<void> _exportIssuesCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    // Show loading dialog for large exports
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Exporting issues data...\nThis may take a while for large datasets.',
              ),
            ),
          ],
        ),
      ),
    );

    try {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close dialog temporarily

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Issues Export (CSV)',
        fileName:
            'issues_export_${DateTime.now().toIso8601String().split('T')[0]}.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (path == null || path.isEmpty) return;

      // Show loading dialog again
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Exporting issues data...\nThis may take a while for large datasets.',
                ),
              ),
            ],
          ),
        ),
      );

      // Use server-side export for large datasets
      final bytes = await ApiService.exportData('issues', format: 'csv');
      await File(path).writeAsBytes(bytes, flush: true);

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      messenger.showSnackBar(SnackBar(content: Text('Exported CSV to: $path')));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      messenger.showSnackBar(SnackBar(content: Text(getOperationErrorMessage('Export', e))));
    }
  }

  Future<void> _exportIssuesPdf(BuildContext context) async {
    final issues = context.read<IssueProvider>().issues;
    if (issues.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No issues to export')));
      return;
    }

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Issues Export (PDF)',
      fileName:
          'issues_export_${DateTime.now().toIso8601String().split('T')[0]}.pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (path == null || path.isEmpty) return;

    // Initialize Hindi PDF helper for font support
    await HindiPdfHelper.initialize();
    final baseFont = HindiPdfHelper.baseFont;
    final boldFont = HindiPdfHelper.boldFont;

    // Load organization logo
    final logoBytes = await _loadPdfLogo();

    final doc = pw.Document();

    // Normalize Hindi text in data
    final normalizedIssues = issues.map((i) => [
      i.id.toString(),
      HindiPdfHelper.normalizeForPdf(i.bookTitle),
      HindiPdfHelper.normalizeForPdf(i.bookAuthor),
      HindiPdfHelper.normalizeForPdf(i.memberName),
      DateFormatter.formatDateIndian(i.issueDate),
      DateFormatter.formatDateIndian(i.dueDate),
      i.returnDate == null
          ? '-'
          : DateFormatter.formatDateIndian(i.returnDate),
      i.status,
    ]).toList();

    final hindiCache = await HindiPdfHelper.preRenderHindiTexts(
      normalizedIssues.expand((row) => row),
      fontSize: 9,
      fontWeight: pw.FontWeight.normal,
      color: PdfColors.black,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (context) {
          final cellStyle = pw.TextStyle(
            font: baseFont,
            fontSize: 9,
            fontFallback: HindiPdfHelper.baseFontFallback,
          );
          final headerStyle = pw.TextStyle(
            font: boldFont,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            fontFallback: HindiPdfHelper.boldFontFallback,
          );

          return [
            // Organization Header
            _buildOrgHeader(logoBytes, boldFont, baseFont),
            pw.SizedBox(height: 16),

            // Document Title
            pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue800,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'Issues & Returns Report',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontFallback: HindiPdfHelper.boldFontFallback,
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Generated: ${DateFormatter.formatDateTimeIndian(DateTime.now().toIso8601String())}',
              style: pw.TextStyle(
                font: baseFont,
                fontSize: 10,
                fontFallback: HindiPdfHelper.baseFontFallback,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: const [
                'ID',
                'Book Title',
                'Author',
                'Member',
                'Issue Date',
                'Due Date',
                'Return Date',
                'Status',
              ],
              data: normalizedIssues,
              cellStyle: cellStyle,
              cellBuilder: (index, data, rowNum) {
                return HindiPdfHelper.buildCachedText(
                  data.toString(),
                  style: cellStyle,
                  cache: hindiCache,
                );
              },
              headerStyle: headerStyle,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellAlignment: pw.Alignment.centerLeft,
              headerHeight: 22,
              cellHeight: 20,
            ),
          ];
        },
      ),
    );

    final bytes = await doc.save();
    await File(path).writeAsBytes(bytes, flush: true);

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Exported PDF to: $path')));
  }

  Future<void> _generateBorrowSlip(BuildContext context, dynamic issue) async {
    final messenger = ScaffoldMessenger.of(context);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Generating borrow slip...')),
          ],
        ),
      ),
    );

    try {
      // Check if slip already exists
      final existingSlip = await ApiService.getBorrowSlipByIssue(issue.id);

      Map<String, dynamic> slipData;
      if (existingSlip != null) {
        // Use existing slip
        slipData = existingSlip;
      } else {
        // Generate new slip
        slipData = await ApiService.generateBorrowSlip(issue.id);
      }

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Show the slip preview
      await showBorrowSlipPreview(context, slipData);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      messenger.showSnackBar(
        SnackBar(content: Text(getOperationErrorMessage('Generate slip', e))),
      );
    }
  }

  void _returnBook(BuildContext context, int issueId) async {
    final issueProvider = Provider.of<IssueProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await issueProvider.returnBook(issueId);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Book returned successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(getOperationErrorMessage('Return book', e))),
        );
      }
    }
  }

  void _showEditIssueDialog(BuildContext context, dynamic issue) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final issueProvider = context.read<IssueProvider>();
    String selectedStatus = issue.status;
    String? dueDateIso = issue.dueDate != null
        ? (issue.dueDate as String).split('T')[0]
        : null;
    String? returnDateIso = issue.returnDate != null
        ? (issue.returnDate as String).split('T')[0]
        : null;

    final dueController = TextEditingController(
      text: DateFormatter.formatDateIndian(dueDateIso ?? ''),
    );
    final returnController = TextEditingController(
      text: returnDateIso != null
          ? DateFormatter.formatDateIndian(returnDateIso)
          : '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => _EditIssueDialog(
        issue: issue,
        navigator: navigator,
        messenger: messenger,
        issueProvider: issueProvider,
        initialSelectedStatus: selectedStatus,
        initialDueDateIso: dueDateIso,
        initialReturnDateIso: returnDateIso,
        dueController: dueController,
        returnController: returnController,
        formKey: formKey,
      ),
    );
  }

  void _showDeleteIssueDialog(BuildContext context, dynamic issue) {
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete Issue'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this issue record?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    normalizeHindiForDisplay(issue.bookTitle),
                    style: _textStyleForHindi(
                      normalizeHindiForDisplay(issue.bookTitle),
                      const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Issued to: ${normalizeHindiForDisplay(issue.memberName)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Status: ${issue.status}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await ApiService.deleteIssue(issue.id);
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Issue deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadAllData();
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(getOperationErrorMessage('Delete issue', e)),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _loadPdfLogo() async {
    try {
      final logoData = await rootBundle.load('assets/images/Office_Logo.png');
      return logoData.buffer.asUint8List();
    } catch (e) {
      debugPrint('Could not load logo: $e');
    }
    return null;
  }

  pw.Widget _buildOrgHeader(Uint8List? logoBytes, pw.Font boldFont, pw.Font baseFont) {
    if (logoBytes != null) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          children: [
            pw.Image(pw.MemoryImage(logoBytes), width: 70, height: 70),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Uttar Pradesh State Tax Training',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      font: boldFont,
                      fontFallback: HindiPdfHelper.boldFontFallback,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    'and Research Institute',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      font: boldFont,
                      fontFallback: HindiPdfHelper.boldFontFallback,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Lucknow',
                    style: pw.TextStyle(
                      fontSize: 11,
                      font: baseFont,
                      color: PdfColors.grey600,
                      fontFallback: HindiPdfHelper.baseFontFallback,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
          ],
        ),
      );
    } else {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                'Uttar Pradesh State Tax Training',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  fontFallback: HindiPdfHelper.boldFontFallback,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'and Research Institute',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  fontFallback: HindiPdfHelper.boldFontFallback,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }
}

class _EditIssueDialog extends StatefulWidget {
  const _EditIssueDialog({
    required this.issue,
    required this.navigator,
    required this.messenger,
    required this.issueProvider,
    required this.initialSelectedStatus,
    required this.initialDueDateIso,
    required this.initialReturnDateIso,
    required this.dueController,
    required this.returnController,
    required this.formKey,
  });

  final dynamic issue;
  final NavigatorState navigator;
  final ScaffoldMessengerState messenger;
  final IssueProvider issueProvider;
  final String initialSelectedStatus;
  final String? initialDueDateIso;
  final String? initialReturnDateIso;
  final TextEditingController dueController;
  final TextEditingController returnController;
  final GlobalKey<FormState> formKey;

  @override
  State<_EditIssueDialog> createState() => _EditIssueDialogState();
}

class _EditIssueDialogState extends State<_EditIssueDialog> {
  late String selectedStatus;
  String? dueDateIso;
  String? returnDateIso;

  @override
  void initState() {
    super.initState();
    selectedStatus = widget.initialSelectedStatus;
    dueDateIso = widget.initialDueDateIso;
    returnDateIso = widget.initialReturnDateIso;
  }

  @override
  void dispose() {
    widget.dueController.dispose();
    widget.returnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width < 600
              ? MediaQuery.of(context).size.width * 0.95
              : 500,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Edit Issue',
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: widget.formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: widget.dueController,
                          decoration: const InputDecoration(labelText: 'Due Date'),
                          readOnly: true,
                          onTap: () async {
                            DateTime initialDate;
                            try {
                              initialDate = dueDateIso != null
                                  ? DateTime.parse(dueDateIso!)
                                  : DateTime.now();
                            } catch (e) {
                              initialDate = DateTime.now();
                            }
                            final date = await showDatePicker(
                              context: context,
                              initialDate: initialDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() {
                                dueDateIso = date.toIso8601String().split('T')[0];
                                widget.dueController.text =
                                    DateFormatter.formatDateIndian(dueDateIso ?? '');
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        if (selectedStatus == 'returned')
                          TextFormField(
                            controller: widget.returnController,
                            decoration: const InputDecoration(labelText: 'Return Date'),
                            readOnly: true,
                            validator: (value) {
                              if (selectedStatus == 'returned' &&
                                  (value == null || value.isEmpty)) {
                                return 'Return date required';
                              }
                              return null;
                            },
                            onTap: () async {
                              DateTime initialDate;
                              try {
                                final r = returnDateIso;
                                initialDate = r != null
                                    ? DateTime.parse(r)
                                    : DateTime.now();
                              } catch (e) {
                                initialDate = DateTime.now();
                              }
                              final date = await showDatePicker(
                                context: context,
                                initialDate: initialDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() {
                                  returnDateIso = date.toIso8601String().split('T')[0];
                                  widget.returnController.text =
                                      DateFormatter.formatDateIndian(returnDateIso ?? '');
                                });
                              }
                            },
                          ),
                        if (selectedStatus == 'returned')
                          const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: selectedStatus,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(value: 'issued', child: Text('Issued')),
                            DropdownMenuItem(value: 'returned', child: Text('Returned')),
                            DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                          ],
                          onChanged: (value) => setState(() {
                            if (value == null) return;
                            selectedStatus = value;
                            if (selectedStatus != 'returned') {
                              returnDateIso = null;
                              widget.returnController.text = '';
                            }
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        if (widget.formKey.currentState?.validate() ?? true) {
                          try {
                            final due = dueDateIso ?? '';
                            final String? dueToSend = due.isNotEmpty ? due : null;
                            final ret = returnDateIso ?? '';
                            final String? returnToSend = ret.isNotEmpty ? ret : null;
                            await ApiService.updateIssue(
                              widget.issue.id,
                              dueDate: dueToSend,
                              returnDate: returnToSend,
                              status: selectedStatus,
                            );
                            if (mounted) {
                              widget.navigator.pop();
                              widget.messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Issue updated successfully'),
                                ),
                              );
                              widget.issueProvider.loadIssues();
                            }
                          } catch (e) {
                            if (mounted) {
                              widget.messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Failed to update issue: $e'),
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: const Text('Update'),
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
}
