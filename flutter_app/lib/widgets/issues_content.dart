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
import 'package:printing/printing.dart' show PdfGoogleFonts;
import '../providers/issue_provider.dart';
import '../providers/book_provider.dart';
import '../providers/member_provider.dart';
import '../providers/auth_provider.dart';
import '../models/book.dart';
import '../models/member.dart';
import '../utils/date_formatter.dart';
import '../utils/hindi_text.dart';
import '../services/api_service.dart';

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
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 520,
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
    final query = rawQuery.toLowerCase();
    if (query.isEmpty) return issues;

    // Normalize query for Hindi matching
    final normalizedQuery = normalizeHindiForDisplay(rawQuery).toLowerCase();
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

      return book.title.toLowerCase().contains(query) ||
          normalizedTitle.contains(query) ||
          normalizedTitle.contains(normalizedQuery) ||
          book.title.toLowerCase().contains(krutiDevQuery) ||
          book.author.toLowerCase().contains(query) ||
          normalizedAuthor.contains(query) ||
          normalizedAuthor.contains(normalizedQuery) ||
          book.isbn.toLowerCase().contains(query) ||
          member.name.toLowerCase().contains(query) ||
          normalizedMemberName.contains(query) ||
          normalizedMemberName.contains(normalizedQuery) ||
          member.name.toLowerCase().contains(krutiDevQuery) ||
          (member.phone ?? '').contains(query) ||
          issue.status.toLowerCase().contains(query);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final issueProvider = Provider.of<IssueProvider>(context);
    final bookProvider = Provider.of<BookProvider>(context);
    final memberProvider = Provider.of<MemberProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCompact ? 'Issues' : 'Issues & Returns'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: () => _exportIssuesPdf(context),
          ),
          IconButton(
            tooltip: 'Export Excel (CSV)',
            icon: const Icon(Icons.table_view_rounded),
            onPressed: () => _exportIssuesCsv(context),
          ),
          if (isCompact)
            IconButton(
              tooltip: 'Issue Book',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _showIssueDialog(
                context,
                bookProvider.books,
                memberProvider.members,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _showIssueDialog(
                context,
                bookProvider.books,
                memberProvider.members,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Issue Book'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 20),
        child: Column(
          children: [
            // Search Bar
            Container(
              padding: EdgeInsets.all(isCompact ? 12 : 16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search issues...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: (value) => _filterIssues(),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                elevation: 4,
                child: issueProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
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
                                color: Colors.red[300],
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
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
                    : issueProvider.issues.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 80,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No issues found',
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
                              'Click "Issue Book" to create a new issue',
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
                              onPressed: _loadAllData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : DataTable2(
                        columnSpacing: 8,
                        horizontalMargin: 10,
                        dataRowHeight: 68,
                        minWidth: 800,
                        columns: const [
                          DataColumn2(label: Text('Book'), size: ColumnSize.L),
                          DataColumn2(
                            label: Text('Member'),
                            size: ColumnSize.M,
                          ),
                          DataColumn2(label: Text('Issue'), size: ColumnSize.S),
                          DataColumn2(label: Text('Due'), size: ColumnSize.S),
                          DataColumn2(
                            label: Text('Return'),
                            size: ColumnSize.S,
                          ),
                          DataColumn2(label: Text('Status'), fixedWidth: 85),
                          DataColumn2(label: Text('Actions'), fixedWidth: 130),
                        ],
                        rows:
                            getFilteredIssues(
                              issueProvider.issues,
                              bookProvider.books,
                              memberProvider.members,
                            ).map((issue) {
                              final statusColor = issue.status == 'returned'
                                  ? Colors.green
                                  : (issue.status == 'overdue'
                                        ? Colors.red
                                        : Colors.orange);

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          normalizeHindiForDisplay(
                                            issue.bookTitle,
                                          ),
                                          style: const TextStyle(
                                            fontFamilyFallback: [
                                              'Nirmala UI',
                                              'Mangal',
                                              'Noto Sans Devanagari',
                                            ],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'by ${normalizeHindiForDisplay(issue.bookAuthor)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6),
                                            fontFamilyFallback: const [
                                              'Nirmala UI',
                                              'Mangal',
                                              'Noto Sans Devanagari',
                                            ],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      normalizeHindiForDisplay(
                                        issue.memberName,
                                      ),
                                      style: const TextStyle(
                                        fontFamilyFallback: [
                                          'Nirmala UI',
                                          'Mangal',
                                          'Noto Sans Devanagari',
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      DateFormatter.formatDateIndian(
                                        issue.issueDate,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      DateFormatter.formatDateIndian(
                                        issue.dueDate,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      issue.returnDate != null
                                          ? DateFormatter.formatDateIndian(
                                              issue.returnDate,
                                            )
                                          : '-',
                                    ),
                                  ),
                                  DataCell(
                                    Chip(
                                      label: Text(issue.status),
                                      backgroundColor: statusColor,
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 16,
                                          ),
                                          onPressed: () => _showEditIssueDialog(
                                            context,
                                            issue,
                                          ),
                                          tooltip: 'Edit Issue',
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        const SizedBox(width: 8),
                                        issue.status == 'issued'
                                            ? SizedBox(
                                                width: 72,
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 6,
                                                        ),
                                                    minimumSize: const Size(
                                                      48,
                                                      32,
                                                    ),
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                  ),
                                                  onPressed: () => _returnBook(
                                                    context,
                                                    issue.id,
                                                  ),
                                                  child: const FittedBox(
                                                    child: Text('Return'),
                                                  ),
                                                ),
                                              )
                                            : const Text('-'),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                      ),
              ),
            ),

            // Pagination controls
            if (!issueProvider.isLoading && issueProvider.issues.isNotEmpty)
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
                      'Showing ${issueProvider.issues.length} of ${issueProvider.totalIssues} issues',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Row(
                      children: [
                        Text(
                          'Page ${issueProvider.currentPage} of ${issueProvider.totalPages}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: issueProvider.currentPage > 1
                              ? () => issueProvider.loadPage(
                                  issueProvider.currentPage - 1,
                                )
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: issueProvider.hasMore
                              ? () => issueProvider.loadPage(
                                  issueProvider.currentPage + 1,
                                )
                              : null,
                        ),
                        if (issueProvider.hasMore)
                          TextButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Load More'),
                            onPressed: () => issueProvider.loadMoreIssues(),
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

  Future<void> _showIssueDialog(
    BuildContext context,
    List<Book> books,
    List<Member> members,
  ) async {
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

    final availableBooks = books.where((b) => b.status == 'available').toList();

    Future<void> pickBook({String initialQuery = ''}) async {
      final picked = await _showSearchPicker<Book>(
        context: context,
        title: 'Select Book',
        items: availableBooks,
        labelFor: (b) => '${b.title} by ${b.author}',
        matches: (b, q) {
          final title = b.title.toLowerCase();
          final author = b.author.toLowerCase();
          final isbn = b.isbn.toLowerCase();
          final category = (b.category ?? '').toLowerCase();
          return title.contains(q) ||
              author.contains(q) ||
              isbn.contains(q) ||
              category.contains(q);
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
      await showDialog<void>(
        context: context,
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
                                    await context
                                        .read<IssueProvider>()
                                        .issueBook(bookId, memberId, dueDate);
                                    if (mounted) {
                                      ScaffoldMessenger.maybeOf(
                                        context,
                                      )?.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Book issued successfully',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.maybeOf(
                                        context,
                                      )?.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to issue book: $e',
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
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
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

    // Embed a font that supports Hindi/Devanagari so text renders correctly.
    final baseFont = await PdfGoogleFonts.notoSansDevanagariRegular();
    final boldFont = await PdfGoogleFonts.notoSansDevanagariBold();

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (context) {
          return [
            pw.Text(
              'Issues & Returns Export',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Generated: ${DateFormatter.formatDateTimeIndian(DateTime.now().toIso8601String())}',
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: const [
                'ID',
                'Book',
                'Member',
                'Issue',
                'Due',
                'Return',
                'Status',
              ],
              data: issues.map((i) {
                return [
                  i.id.toString(),
                  '${i.bookTitle}\nby ${i.bookAuthor}',
                  i.memberName,
                  DateFormatter.formatDateIndian(i.issueDate),
                  DateFormatter.formatDateIndian(i.dueDate),
                  i.returnDate == null
                      ? '-'
                      : DateFormatter.formatDateIndian(i.returnDate),
                  i.status,
                ];
              }).toList(),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(),
              cellAlignment: pw.Alignment.centerLeft,
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

  void _returnBook(BuildContext context, int issueId) async {
    try {
      await Provider.of<IssueProvider>(
        context,
        listen: false,
      ).returnBook(issueId);
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book returned successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to return book: $e')));
      }
    }
  }

  void _showEditIssueDialog(BuildContext context, dynamic issue) {
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
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
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
                  // Header
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
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: dueController,
                              decoration: const InputDecoration(
                                labelText: 'Due Date',
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
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 365),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (date != null) {
                                  setState(() {
                                    dueDateIso = date.toIso8601String().split(
                                      'T',
                                    )[0];
                                    dueController.text =
                                        DateFormatter.formatDateIndian(
                                          dueDateIso ?? '',
                                        );
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            if (selectedStatus == 'returned')
                              TextFormField(
                                controller: returnController,
                                decoration: const InputDecoration(
                                  labelText: 'Return Date',
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
                                      returnDateIso = date
                                          .toIso8601String()
                                          .split('T')[0];
                                      returnController.text =
                                          DateFormatter.formatDateIndian(
                                            returnDateIso ?? '',
                                          );
                                    });
                                  }
                                },
                              ),
                            if (selectedStatus == 'returned')
                              const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: selectedStatus,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'issued',
                                  child: Text('Issued'),
                                ),
                                DropdownMenuItem(
                                  value: 'returned',
                                  child: Text('Returned'),
                                ),
                                DropdownMenuItem(
                                  value: 'overdue',
                                  child: Text('Overdue'),
                                ),
                              ],
                              onChanged: (value) => setState(() {
                                if (value == null) return;
                                selectedStatus = value;
                                if (selectedStatus != 'returned') {
                                  returnDateIso = null;
                                  returnController.text = '';
                                }
                              }),
                            ),
                          ],
                        ),
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
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState?.validate() ?? true) {
                              try {
                                final due = dueDateIso ?? '';
                                final String? dueToSend = due.isNotEmpty
                                    ? due
                                    : null;
                                final ret = returnDateIso ?? '';
                                final String? returnToSend = ret.isNotEmpty
                                    ? ret
                                    : null;
                                await ApiService.updateIssue(
                                  issue.id,
                                  dueDate: dueToSend,
                                  returnDate: returnToSend,
                                  status: selectedStatus,
                                );
                                if (mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Issue updated successfully',
                                      ),
                                    ),
                                  );
                                  context.read<IssueProvider>().loadIssues();
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to update issue: $e',
                                      ),
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
        ),
      ),
    );
  }
}
