import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../utils/responsive.dart';
import '../utils/theme.dart';
import '../widgets/common_widgets.dart';
import 'dashboard_screen.dart';
import '../widgets/premium_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/borrow_slip_preview.dart';

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

  TextStyle _textStyleForHindi(String text, TextStyle base) {
    return hindiAwareTextStyle(context, text: text, base: base);
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
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          hoverColor: color.withValues(alpha: 0.2),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: color),
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
          hoverColor: returnColor.withValues(alpha: 0.15),
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
    final iconColor =
        color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          hoverColor: iconColor.withValues(alpha: 0.1),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: iconColor),
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
      210, // actions column
    ];
    final minTableWidth = columnWidths.fold(0.0, (sum, w) => sum + w);

    // When the pagination bar is shown it sits directly beneath the table, so
    // the table only rounds its top corners and the two pieces read as one card.
    final showPagination =
        !issueProvider.isLoading && issueProvider.issues.isNotEmpty;
    final tableRadius = showPagination
        ? const BorderRadius.vertical(top: Radius.circular(16))
        : BorderRadius.circular(16);

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
                  borderRadius: tableRadius,
                  border: showPagination
                      ? Border(
                          top: BorderSide(color: tableBorderColor),
                          left: BorderSide(color: tableBorderColor),
                          right: BorderSide(color: tableBorderColor),
                        )
                      : Border.all(color: tableBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: tableShadowColor,
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: tableRadius,
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
                                  color: colorScheme.error.withValues(
                                    alpha: 0.6,
                                  ),
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
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.6,
                                        ),
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
                                      onPressed: () =>
                                          context.read<AuthProvider>().logout(),
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
                                ? colorScheme.outlineVariant.withValues(
                                    alpha: 0.35,
                                  )
                                : const Color(0xFFF0F0F0),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
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
                                      label: _buildIssuesHeaderLabel('Book'),
                                    ),
                                    if (showMember)
                                      DataColumn2(
                                        label: _buildIssuesHeaderLabel(
                                          'Member',
                                        ),
                                      ),
                                    if (showIssueDate)
                                      DataColumn2(
                                        label: _buildIssuesHeaderLabel(
                                          'Issue Date',
                                        ),
                                      ),
                                    if (showDueDate)
                                      DataColumn2(
                                        label: _buildIssuesHeaderLabel(
                                          'Due Date',
                                        ),
                                      ),
                                    if (showReturnDate)
                                      DataColumn2(
                                        label: _buildIssuesHeaderLabel(
                                          'Return',
                                        ),
                                      ),
                                    if (showStatus)
                                      DataColumn2(
                                        label: _buildIssuesHeaderLabel(
                                          'Status',
                                        ),
                                      ),
                                    DataColumn2(
                                      fixedWidth: 210,
                                      label: Align(
                                        alignment: Alignment.center,
                                        child: _buildIssuesHeaderLabel(
                                          'Actions',
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: filteredIssues.toList().asMap().entries.map((
                                    entry,
                                  ) {
                                    final idx = entry.key;
                                    final issue = entry.value;
                                    final semantic = context.semantic;
                                    final statusColor =
                                        issue.status == 'returned'
                                        ? semantic.success
                                        : (issue.status == 'overdue'
                                              ? semantic.danger
                                              : semantic.warning);
                                    final baseRowColor = idx.isEven
                                        ? colorScheme.surface
                                        : zebraColor;

                                    String? secondaryText;
                                    String? metaText;
                                    if (!showMember) {
                                      secondaryText = normalizeHindiForDisplay(
                                        issue.memberName,
                                      );
                                    }
                                    if (!showIssueDate) {
                                      metaText =
                                          'Issued: ${DateFormatter.formatDateIndian(issue.issueDate)}';
                                    } else if (!showDueDate) {
                                      metaText =
                                          'Due: ${DateFormatter.formatDateIndian(issue.dueDate)}';
                                    }

                                    return DataRow(
                                      color: WidgetStateProperty.resolveWith((
                                        states,
                                      ) {
                                        if (states.contains(
                                          WidgetState.hovered,
                                        )) {
                                          return rowHoverColor;
                                        }
                                        return baseRowColor;
                                      }),
                                      cells: [
                                        DataCell(
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                normalizeHindiForDisplay(
                                                  issue.bookTitle,
                                                ),
                                                style: _textStyleForHindi(
                                                  normalizeHindiForDisplay(
                                                    issue.bookTitle,
                                                  ),
                                                  TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: isDark
                                                        ? colorScheme.onSurface
                                                        : const Color(
                                                            0xFF1A1A2E,
                                                          ),
                                                  ),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (secondaryText != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 2,
                                                      ),
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
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              if (metaText != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 1,
                                                      ),
                                                  child: Text(
                                                    metaText,
                                                    style: _textStyleForHindi(
                                                      metaText,
                                                      TextStyle(
                                                        fontSize: 10,
                                                        color: mutedText
                                                            .withValues(
                                                              alpha: 0.7,
                                                            ),
                                                      ),
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (showMember)
                                          DataCell(
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 180,
                                              ),
                                              child: Text(
                                                normalizeHindiForDisplay(
                                                  issue.memberName,
                                                ),
                                                style: _textStyleForHindi(
                                                  normalizeHindiForDisplay(
                                                    issue.memberName,
                                                  ),
                                                  TextStyle(
                                                    fontSize: 13,
                                                    color: isDark
                                                        ? colorScheme
                                                              .onSurfaceVariant
                                                              .withValues(
                                                                alpha: 0.85,
                                                              )
                                                        : const Color(
                                                            0xFF666666,
                                                          ),
                                                  ),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        if (showIssueDate)
                                          DataCell(
                                            Text(
                                              DateFormatter.formatDateIndian(
                                                issue.issueDate,
                                              ),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: mutedText,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        if (showDueDate)
                                          DataCell(
                                            Text(
                                              DateFormatter.formatDateIndian(
                                                issue.dueDate,
                                              ),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: mutedText,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        if (showReturnDate)
                                          DataCell(
                                            Text(
                                              issue.returnDate != null
                                                  ? DateFormatter.formatDateIndian(
                                                      issue.returnDate,
                                                    )
                                                  : '-',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: mutedText,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        if (showStatus)
                                          DataCell(
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: statusColor.withValues(
                                                    alpha: 0.25,
                                                  ),
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
                                                      color: statusColor,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      issue.status[0]
                                                              .toUpperCase() +
                                                          issue.status
                                                              .substring(1),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: statusColor,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        DataCell(
                                          Align(
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                _buildActionButton(
                                                  icon: Icons
                                                      .description_outlined,
                                                  color: accentTeal,
                                                  tooltip: 'Generate Slip',
                                                  onTap: () =>
                                                      _generateBorrowSlip(
                                                        context,
                                                        issue,
                                                      ),
                                                ),
                                                const SizedBox(width: 6),
                                                _buildActionButton(
                                                  icon: Icons.edit_outlined,
                                                  color: const Color(
                                                    0xFFD97706,
                                                  ),
                                                  tooltip: 'Edit Issue',
                                                  onTap: () =>
                                                      _showEditIssueDialog(
                                                        context,
                                                        issue,
                                                      ),
                                                ),
                                                const SizedBox(width: 6),
                                                _buildActionButton(
                                                  icon: Icons.delete_outlined,
                                                  color: const Color(
                                                    0xFFE11D48,
                                                  ),
                                                  tooltip: 'Delete Issue',
                                                  onTap: () =>
                                                      _showDeleteIssueDialog(
                                                        context,
                                                        issue,
                                                      ),
                                                ),
                                                const SizedBox(width: 6),
                                                if (issue.status == 'issued' ||
                                                    issue.status == 'overdue')
                                                  _buildReturnButtonFor(
                                                    issue.id,
                                                    colorScheme,
                                                  )
                                                else
                                                  const SizedBox.shrink(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
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
            if (showPagination)
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
                    top: BorderSide(color: tableBorderColor),
                    left: BorderSide(color: tableBorderColor),
                    right: BorderSide(color: tableBorderColor),
                    bottom: BorderSide(color: tableBorderColor),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 760;
                    final footerTextStyle = TextStyle(
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
                        '${issueProvider.currentPage}',
                        style: TextStyle(
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
                          'of ${issueProvider.totalPages}',
                          style: footerTextStyle,
                        ),
                      ],
                    );
                    final loadMoreButton = OutlinedButton(
                      onPressed: issueProvider.hasMore
                          ? () => issueProvider.loadMoreIssues()
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
                        backgroundColor: WidgetStateProperty.resolveWith((
                          states,
                        ) {
                          if (states.contains(WidgetState.hovered)) {
                            return accentTeal;
                          }
                          return Colors.transparent;
                        }),
                        foregroundColor: WidgetStateProperty.resolveWith((
                          states,
                        ) {
                          if (states.contains(WidgetState.hovered)) {
                            return Colors.white;
                          }
                          return accentTeal;
                        }),
                        textStyle: WidgetStateProperty.all(
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      child: const Text('+ Load More'),
                    );
                    final pagerButtons = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPagerIconButton(
                          icon: Icons.chevron_left,
                          onPressed: issueProvider.currentPage > 1
                              ? () => issueProvider.loadPage(
                                  issueProvider.currentPage - 1,
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
                          onPressed: issueProvider.hasMore
                              ? () => issueProvider.loadPage(
                                  issueProvider.currentPage + 1,
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
                            'Showing ${filteredIssues.length} of ${issueProvider.totalIssues} issues',
                            style: footerTextStyle,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(child: pageIndicator),
                              pagerButtons,
                            ],
                          ),
                          if (issueProvider.hasMore) ...[
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
                            'Showing ${filteredIssues.length} of ${issueProvider.totalIssues} issues',
                            style: footerTextStyle,
                          ),
                        ),
                        Expanded(child: Center(child: pageIndicator)),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              pagerButtons,
                              if (issueProvider.hasMore) ...[
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

  int? _hoveredRowIndex;

  Widget _buildIssuesHeaderLabel(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8)
        : const Color(0xFF6B7280);
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.dmSans(
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
      tooltip: icon == Icons.chevron_left ? 'Previous page' : 'Next page',
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
            color: enabled ? borderColor : borderColor.withValues(alpha: 0.45),
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
                tooltip: 'Clear search',
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
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
                if (states.contains(WidgetState.pressed)) {
                  return const Color(0xFF137A5A);
                }
                if (states.contains(WidgetState.hovered)) {
                  return const Color(0xFF168B66);
                }
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
        children: [searchField, const SizedBox(height: 10), actions],
      );
    }

    return Row(
      children: [
        Expanded(flex: 3, child: searchField),
        const SizedBox(width: 10),
        Flexible(child: actions),
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
    final dueController = TextEditingController(
      text: DateFormatter.formatDateIndian(dueDate),
    );

    // Fetch ALL available books directly to ensure all Hindi books are included
    List<Book> allBooks;
    try {
      allBooks = await ApiService.getBooks(available: true);
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching all books: $e');
      // Fallback to passed books if API fails
      allBooks = books;
    }
    final availableBooks = allBooks
        .where((b) => b.status == 'available')
        .toList();

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
          final normalizedTitle = normalizeHindiForDisplay(
            b.title,
          ).toLowerCase();
          final normalizedAuthor = normalizeHindiForDisplay(
            b.author,
          ).toLowerCase();
          final normalizedCategory = normalizeHindiForDisplay(
            b.category ?? '',
          ).toLowerCase();
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
            child: PremiumDialogShell(
              icon: Icons.assignment_add,
              title: 'Issue Book',
              subtitle: 'Assign a book to a member and set the due date',
              maxWidth: 540,
              onClose: () => Navigator.of(dialogContext).pop(),
              body: PremiumSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PremiumSectionTitle(
                      title: 'Issue Details',
                      icon: Icons.assignment_outlined,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: selectedBookController,
                      readOnly: true,
                      decoration: premiumInputDecoration(
                        dialogContext,
                        label: 'Book',
                        hint: 'Type to search (or click to select)',
                        icon: Icons.menu_book_rounded,
                        suffixIcon: const Icon(Icons.arrow_drop_down),
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
                      decoration: premiumInputDecoration(
                        dialogContext,
                        label: 'Member',
                        hint: 'Type to search (or click to select)',
                        icon: Icons.person_outline_rounded,
                        suffixIcon: const Icon(Icons.arrow_drop_down),
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
                      readOnly: true,
                      decoration: premiumInputDecoration(
                        dialogContext,
                        label: 'Due Date',
                        icon: Icons.event_rounded,
                      ),
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
                            dueDate = date.toIso8601String().split('T')[0];
                            dueController.text =
                                DateFormatter.formatDateIndian(dueDate);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                PremiumDialogButton.secondary(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                PremiumDialogButton.primary(
                  label: 'Issue',
                  icon: Icons.check_rounded,
                  onPressed: () async {
                    if (selectedBookId != null && selectedMemberId != null) {
                      final int bookId = selectedBookId!;
                      final int memberId = selectedMemberId!;
                      Navigator.of(dialogContext).pop();
                      try {
                        await issueProvider.issueBook(
                          bookId,
                          memberId,
                          dueDate,
                        );
                        if (mounted && messenger != null) {
                          AppToast.showOnMessenger(
                            messenger,
                            message:
                                'Book issued successfully. Use the slip button to generate a borrow slip.',
                            type: ToastType.success,
                            duration: const Duration(seconds: 4),
                          );
                        }
                      } catch (e) {
                        if (mounted && messenger != null) {
                          AppToast.showOnMessenger(
                            messenger,
                            message: getOperationErrorMessage('Issue book', e),
                            type: ToastType.error,
                          );
                        }
                      }
                    }
                  },
                ),
              ],
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
      AppToast.showOnMessenger(messenger,
          message: 'Exported CSV to: $path', type: ToastType.success);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      AppToast.showOnMessenger(messenger,
          message: getOperationErrorMessage('Export', e),
          type: ToastType.error);
    }
  }

  Future<void> _exportIssuesPdf(BuildContext context) async {
    final issues = context.read<IssueProvider>().issues;
    if (issues.isEmpty) {
      AppToast.warning(context, 'No issues to export');
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
    final normalizedIssues = issues
        .map(
          (i) => [
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
          ],
        )
        .toList();

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
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
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
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
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
    AppToast.success(context, 'Exported PDF to: $path');
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
      AppToast.showOnMessenger(messenger,
          message: getOperationErrorMessage('Generate slip', e),
          type: ToastType.error);
    }
  }

  void _returnBook(BuildContext context, int issueId) async {
    final issueProvider = Provider.of<IssueProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await issueProvider.returnBook(issueId);
      if (mounted) {
        AppToast.showOnMessenger(
          messenger,
          message: 'Book returned successfully',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showOnMessenger(
          messenger,
          message: getOperationErrorMessage('Return book', e),
          type: ToastType.error,
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
    final issueProvider = context.read<IssueProvider>();
    () async {
      // Optimistically remove the row and offer Undo; defer the real delete
      // until the undo window closes (mirrors the books flow).
      final removed = issueProvider.removeIssueLocally(issue.id);
      if (removed == null || !mounted) return;

      var undone = false;
      showAppSnack(
        context,
        message: 'Issue deleted',
        type: AppSnackType.success,
        actionLabel: 'Undo',
        duration: const Duration(seconds: 4),
        onAction: () {
          undone = true;
          issueProvider.restoreIssueLocally(removed.issue, removed.index);
        },
      );

      await Future.delayed(const Duration(seconds: 4, milliseconds: 250));
      if (undone || !mounted) return;

      try {
        await issueProvider.commitDeleteIssue(removed.issue.id);
        await issueProvider.loadStats();
      } catch (e) {
        if (!context.mounted) return;
        issueProvider.restoreIssueLocally(removed.issue, removed.index);
        showAppSnack(
          context,
          message: getOperationErrorMessage('Delete issue', e),
          type: AppSnackType.error,
        );
      }
    }();
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

  pw.Widget _buildOrgHeader(
    Uint8List? logoBytes,
    pw.Font boldFont,
    pw.Font baseFont,
  ) {
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
  bool _saving = false;

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

  Future<void> _save() async {
    if (!(widget.formKey.currentState?.validate() ?? true)) return;
    setState(() => _saving = true);
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
        AppToast.showOnMessenger(
          widget.messenger,
          message: 'Issue updated successfully',
          type: ToastType.success,
        );
        widget.issueProvider.loadIssues();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.showOnMessenger(
          widget.messenger,
          message: 'Failed to update issue: $e',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumDialogShell(
      icon: Icons.event_repeat_rounded,
      title: 'Edit Issue',
      subtitle: 'Update due date, return date, and status',
      maxWidth: 520,
      body: Form(
        key: widget.formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: widget.dueController,
              decoration: premiumInputDecoration(
                context,
                label: 'Due Date',
                icon: Icons.event_rounded,
              ),
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
                    widget.dueController.text = DateFormatter.formatDateIndian(
                      dueDateIso ?? '',
                    );
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            if (selectedStatus == 'returned') ...[
              TextFormField(
                controller: widget.returnController,
                decoration: premiumInputDecoration(
                  context,
                  label: 'Return Date',
                  icon: Icons.assignment_turned_in_rounded,
                ),
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
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
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
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              initialValue: selectedStatus,
              decoration: premiumInputDecoration(
                context,
                label: 'Status',
                icon: Icons.flag_rounded,
              ),
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
      actions: [
        PremiumDialogButton.secondary(
          label: 'Cancel',
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        PremiumDialogButton.primary(
          label: 'Update',
          icon: Icons.save_rounded,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
