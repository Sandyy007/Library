import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/member_provider.dart';
import '../providers/issue_provider.dart';
import '../models/member.dart';
import '../widgets/member_dialog.dart';
import '../widgets/member_history_dialog.dart';
import '../widgets/borrowed_books_dialog.dart';
import '../services/api_service.dart';
import '../utils/hindi_text.dart';
import '../utils/error_utils.dart';
import '../utils/color_extensions.dart';
import '../widgets/common_widgets.dart';

enum MemberStatusFilter { all, active, inactive }

class MembersContent extends StatefulWidget {
  const MembersContent({super.key});

  @override
  State<MembersContent> createState() => _MembersContentState();
}

class _MembersContentState extends State<MembersContent> {
  final TextEditingController _searchController = TextEditingController();
  MemberStatusFilter _statusFilter = MemberStatusFilter.all;
  StreamSubscription<void>? _dataChangedSub;
  Timer? _searchDebounce;

  TextStyle _textStyleForHindi(String text, TextStyle base) {
    if (containsDevanagari(text) || looksLikeLegacyHindi(text)) {
      return base.copyWith(
        fontFamilyFallback: const [
          'KrutiDev',
          'NotoSansDevanagari',
          'Nirmala UI',
          'Mangal',
          'Noto Sans Devanagari',
        ],
      );
    }
    return base;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMembers();
    });
    // Listen for data changes from other components
    _dataChangedSub = ApiService.dataChangedStream.listen((_) {
      _loadMembers();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _dataChangedSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _loadMembers() {
    try {
      context.read<MemberProvider>().loadMembers().catchError((error) {
        if (kDebugMode) debugPrint('Error loading members: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(getOperationErrorMessage('Load members', error))),
          );
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error in loadMembers: $e');
    }
  }

  List getFilteredMembers(List members) {
    final rawQuery = _searchController.text;

    final filteredByStatus = members.where((member) {
      final m = member as Member;
      switch (_statusFilter) {
        case MemberStatusFilter.active:
          return m.isActive;
        case MemberStatusFilter.inactive:
          return !m.isActive;
        case MemberStatusFilter.all:
          return true;
      }
    }).toList();

    if (rawQuery.trim().isEmpty) return filteredByStatus;

    final query = rawQuery.toLowerCase();
    // Normalize query for Hindi matching (converts Krutidev query to Unicode)
    final normalizedQuery = normalizeHindiForDisplay(rawQuery).toLowerCase();
    // Convert Unicode Hindi query to KrutiDev for matching legacy data
    final krutiDevQuery = unicodeToKrutiDevApprox(rawQuery).toLowerCase();

    return filteredByStatus.where((member) {
      final m = member as Member;
      // Normalize member name for Hindi matching
      final normalizedName = normalizeHindiForDisplay(m.name).toLowerCase();
      final rawName = m.name.toLowerCase();

      // Comprehensive matching: support all Hindi encodings
      // 1. Direct match (raw query vs raw data)
      // 2. Normalized query vs normalized data
      // 3. KrutiDev query vs raw data (handles Unicode query against Krutidev data)
      // 4. Raw query vs normalized data (handles Krutidev query against Unicode data)
      final matchesName =
          rawName.contains(query) ||
          normalizedName.contains(query) ||
          normalizedName.contains(normalizedQuery) ||
          rawName.contains(krutiDevQuery);

      final matchesEmail = (m.email ?? '').toLowerCase().contains(query);
      final matchesPhone = (m.phone ?? '').contains(query);

      // Also match member type (might be in Hindi)
      final normalizedType = normalizeHindiForDisplay(
        m.memberType,
      ).toLowerCase();
      final rawType = m.memberType.toLowerCase();
      final matchesType =
          rawType.contains(query) ||
          normalizedType.contains(query) ||
          normalizedType.contains(normalizedQuery) ||
          rawType.contains(krutiDevQuery);

      return matchesName || matchesEmail || matchesPhone || matchesType;
    }).toList();
  }

  void _filterMembers() {
    setState(() {});
  }

  Future<void> _exportMembersActivityCsv() async {
    final messenger = ScaffoldMessenger.of(context);

    // Show loading dialog for large exports
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Exporting members data...\nThis may take a while for large datasets.',
              ),
            ),
          ],
        ),
      ),
    );

    try {
      // Get path first so user doesn't wait if they cancel
      if (!mounted) return;
      Navigator.of(context).pop(); // Close dialog temporarily

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Members Export (CSV)',
        fileName:
            'members_activity_${DateTime.now().toIso8601String().split('T')[0]}.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (path == null || path.isEmpty) return;

      // Show loading dialog again
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Exporting members data...\nThis may take a while for large datasets.',
                ),
              ),
            ],
          ),
        ),
      );

      // Use server-side export for large datasets
      final bytes = await ApiService.exportData('members', format: 'csv');
      await File(path).writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      messenger.showSnackBar(SnackBar(content: Text('Exported CSV to: $path')));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      messenger.showSnackBar(SnackBar(content: Text(getOperationErrorMessage('Export', e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberProvider = Provider.of<MemberProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(isCompact ? 8 : 20),
        child: Column(
          children: [
            // Search Bar, Status Filters, and Action buttons - all in one bar
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
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                  // Search bar
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search...',
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
                      onChanged: (value) {
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 350),
                          _filterMembers,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Status filter chips
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: _statusFilter == MemberStatusFilter.all,
                            onSelected: (_) => setState(() {
                              _statusFilter = MemberStatusFilter.all;
                            }),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Active'),
                            selected: _statusFilter == MemberStatusFilter.active,
                            onSelected: (_) => setState(() {
                              _statusFilter = MemberStatusFilter.active;
                            }),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Inactive'),
                            selected: _statusFilter == MemberStatusFilter.inactive,
                            onSelected: (_) => setState(() {
                              _statusFilter = MemberStatusFilter.inactive;
                            }),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ),
                    ],
                  ),
                  if (isCompact) const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                  // Export
                  IconButton(
                    tooltip: 'Export CSV',
                    onPressed: _exportMembersActivityCsv,
                    icon: const Icon(Icons.download, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loadMembers,
                    icon: const Icon(Icons.refresh, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  // Add Member button
                  ElevatedButton.icon(
                    onPressed: () => _showMemberDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(isCompact ? 'Add' : 'Add Member'),
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
                child: memberProvider.isLoading
                    ? const ShimmerTable(rows: 8, columns: 5)
                    : memberProvider.members.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.people_outline,
                        title: 'No members found',
                        subtitle: 'Click "Add Member" to create a new member',
                        actionLabel: 'Retry',
                        onAction: _loadMembers,
                      )
                    : DataTable2(
                        columnSpacing: 8,
                        horizontalMargin: 12,
                        dataRowHeight: 65,
                        minWidth: 700,
                        scrollController: ScrollController(),
                        columns: const [
                          DataColumn2(label: Text('Photo'), fixedWidth: 54),
                          DataColumn2(label: Text('Name'), size: ColumnSize.L),
                          DataColumn2(label: Text('Email'), size: ColumnSize.M),
                          DataColumn2(label: Text('Phone'), size: ColumnSize.S),
                          DataColumn2(label: Text('Type'), fixedWidth: 105),
                          DataColumn2(label: Text('Borrowed'), fixedWidth: 85),
                          DataColumn2(label: Text('Status'), fixedWidth: 80),
                          DataColumn2(label: Text('Actions'), fixedWidth: 120),
                        ],
                        rows: getFilteredMembers(memberProvider.members)
                            .asMap()
                            .entries
                            .map(
                              (entry) {
                                final idx = entry.key;
                                final member = entry.value;
                                return DataRow(
                                color: idx.isEven
                                    ? WidgetStateProperty.all(
                                        Theme.of(context).colorScheme.zebraStripe)
                                    : null,
                                cells: [
                                  DataCell(_buildPhotoCell(member)),
                                  DataCell(
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          normalizeHindiForDisplay(member.name),
                                          style: _textStyleForHindi(
                                            normalizeHindiForDisplay(
                                              member.name,
                                            ),
                                            const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (member.address != null &&
                                            member.address!.isNotEmpty)
                                          Text(
                                            normalizeHindiForDisplay(
                                              member.address!,
                                            ),
                                            style: _textStyleForHindi(
                                              normalizeHindiForDisplay(
                                                member.address!,
                                              ),
                                              TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall?.color,
                                              ),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      (member.email ?? '').isEmpty
                                          ? '-'
                                          : member.email!,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      (member.phone ?? '').isEmpty
                                          ? '-'
                                          : member.phone!,
                                    ),
                                  ),
                                  DataCell(_buildTypeChip(member.memberType)),
                                  DataCell(_buildBorrowCountBadge(member)),
                                  DataCell(_buildStatusChip(member.isActive)),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: Icon(
                                              Icons.history_rounded,
                                              size: 18,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                            tooltip: 'View History',
                                            onPressed: () =>
                                                _showMemberHistory(member),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
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
                                            onPressed: () => _showMemberDialog(
                                              member: member,
                                            ),
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
                                                _deleteMember(member.id),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                              },
                            )
                            .toList(),
                      ),
              ),
            ),

            // Pagination controls
            if (!memberProvider.isLoading && memberProvider.members.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${memberProvider.members.length} of ${memberProvider.totalMembers} members',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Row(
                      children: [
                        Text(
                          'Page ${memberProvider.currentPage} of ${memberProvider.totalPages}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: memberProvider.currentPage > 1
                              ? () => memberProvider.loadPage(
                                  memberProvider.currentPage - 1,
                                )
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: memberProvider.hasMore
                              ? () => memberProvider.loadPage(
                                  memberProvider.currentPage + 1,
                                )
                              : null,
                        ),
                        if (memberProvider.hasMore)
                          TextButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Load More'),
                            onPressed: () => memberProvider.loadMoreMembers(),
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

  void _showMemberDialog({Member? member}) async {
    final memberProvider = context.read<MemberProvider>();
    final issueProvider = context.read<IssueProvider>();
    final result = await showDialog(
      context: context,
      builder: (ctx) => MemberDialog(member: member),
    );
    if (mounted && result == true) {
      await memberProvider.loadMembers();
      await issueProvider.loadStats();
    }
  }

  void _showMemberHistory(Member member) {
    showDialog(
      context: context,
      builder: (context) =>
          MemberHistoryDialog(memberId: member.id, memberName: member.name),
    );
  }

  Widget _buildPhotoCell(Member member) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border.all(
          color: member.isActive ? Colors.green : Colors.grey,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: member.profilePhoto != null && member.profilePhoto!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                ApiService.resolvePublicUrl(member.profilePhoto!),
                fit: BoxFit.cover,
                width: 45,
                height: 45,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPhotoPlaceholder(),
              ),
            )
          : _buildPhotoPlaceholder(),
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Center(
      child: Icon(
        Icons.person,
        size: 24,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    Color color;
    IconData icon;
    String label;
    switch (type.toLowerCase()) {
      case 'faculty':
        color = Colors.purple;
        icon = Icons.school;
        label = 'Faculty';
        break;
      case 'staff':
        color = Colors.teal;
        icon = Icons.work;
        label = 'Staff';
        break;
      case 'guest':
        color = Colors.orange;
        icon = Icons.person_outline;
        label = 'Guest';
        break;
      default: // student
        color = Colors.blue;
        icon = Icons.menu_book;
        label = 'Student';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorrowCountBadge(Member member) {
    final count = member.borrowCount;
    final maxBooks = member.maxBooks;
    final isAtLimit = count >= maxBooks;
    final isNearLimit = count >= maxBooks - 1;

    Color badgeColor;
    if (isAtLimit) {
      badgeColor = Colors.red;
    } else if (isNearLimit) {
      badgeColor = Colors.orange;
    } else if (count > 0) {
      badgeColor = Colors.blue;
    } else {
      badgeColor = Colors.grey;
    }

    return InkWell(
      onTap: () => _showBorrowedBooks(member),
      borderRadius: BorderRadius.circular(12),
      child: Tooltip(
        message: count > 0
            ? 'Click to view borrowed books ($count/$maxBooks)'
            : 'No books borrowed (0/$maxBooks)',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book, size: 12, color: badgeColor),
              const SizedBox(width: 4),
              Text(
                '$count/$maxBooks',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBorrowedBooks(Member member) {
    showDialog(
      context: context,
      builder: (context) => BorrowedBooksDialog(
        memberId: member.id,
        memberName: member.name,
        borrowCount: member.borrowCount,
      ),
    );
  }

  Widget _buildStatusChip(bool isActive) {
    final color = isActive ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _deleteMember(int id) {
    final memberProvider = context.read<MemberProvider>();
    final issueProvider = context.read<IssueProvider>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
            const SizedBox(width: 8),
            const Text('Delete Member'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this member? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await memberProvider.deleteMember(id);
                await issueProvider.loadStats();
                if (mounted) {
                  messenger?.showSnackBar(
                    const SnackBar(
                      content: Text('Member deleted successfully'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger?.showSnackBar(
                    SnackBar(
                      content: Text(getOperationErrorMessage('Delete member', e)),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
