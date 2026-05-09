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
import '../screens/dashboard_screen.dart';

enum MemberStatusFilter { all, active, inactive }

class MembersContent extends StatefulWidget {
  const MembersContent({super.key});

  @override
  State<MembersContent> createState() => _MembersContentState();
}

class _MembersContentState extends State<MembersContent> {
  final TextEditingController _searchController = TextEditingController();
  MemberStatusFilter _statusFilter = MemberStatusFilter.all;
  final Set<int> _selectedMemberIds = <int>{};
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
    // Listen for keyboard shortcut events
    DashboardScreen.shortcutEvent.addListener(_onShortcutEvent);
  }

  void _onShortcutEvent() {
    if (DashboardScreen.shortcutEvent.value == 'new-member') {
      _showMemberDialog();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _dataChangedSub?.cancel();
    _searchController.dispose();
    DashboardScreen.shortcutEvent.removeListener(_onShortcutEvent);
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

  /// Status filter chips widget (extracted for reuse in both layouts).
  Widget _buildStatusChips() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChoiceChip(
          label: const Text('All'),
          selected: _statusFilter == MemberStatusFilter.all,
          onSelected: (_) => setState(() => _statusFilter = MemberStatusFilter.all),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 6),
        ChoiceChip(
          label: const Text('Active'),
          selected: _statusFilter == MemberStatusFilter.active,
          onSelected: (_) => setState(() => _statusFilter = MemberStatusFilter.active),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 6),
        ChoiceChip(
          label: const Text('Inactive'),
          selected: _statusFilter == MemberStatusFilter.inactive,
          onSelected: (_) => setState(() => _statusFilter = MemberStatusFilter.inactive),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  /// Thin vertical divider for the toolbar.
  Widget _buildToolbarDivider(BuildContext context) {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memberProvider = Provider.of<MemberProvider>(context);
    final selectedCount = _selectedMemberIds.length;
    final filteredMembers = getFilteredMembers(memberProvider.members);
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
                  if (isCompact) ...[
                    // ── Compact layout (<600px): search on top, chips + actions below ──
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(const Duration(milliseconds: 350), _filterMembers);
                      },
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatusChips(),
                          if (selectedCount > 0) ...[
                            _buildToolbarDivider(context),
                            IconButton(
                              tooltip: 'Delete ($selectedCount)',
                              onPressed: _deleteSelectedMembers,
                              icon: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error, size: 20),
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              tooltip: 'Clear selection',
                              onPressed: () => setState(_selectedMemberIds.clear),
                              icon: const Icon(Icons.clear, size: 20),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                          _buildToolbarDivider(context),
                          IconButton(
                            tooltip: 'Export CSV',
                            onPressed: _exportMembersActivityCsv,
                            icon: const Icon(Icons.download, size: 20),
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            tooltip: 'Refresh',
                            onPressed: _loadMembers,
                            icon: const Icon(Icons.refresh, size: 20),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _showMemberDialog(),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // ── Wide layout (>=600px): everything in a single row ──
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search members...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                            onChanged: (value) {
                              _searchDebounce?.cancel();
                              _searchDebounce = Timer(const Duration(milliseconds: 350), _filterMembers);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildStatusChips(),
                        if (selectedCount > 0) ...[
                          _buildToolbarDivider(context),
                          IconButton(
                            tooltip: 'Delete ($selectedCount)',
                            onPressed: _deleteSelectedMembers,
                            icon: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error, size: 20),
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            tooltip: 'Clear selection',
                            onPressed: () => setState(_selectedMemberIds.clear),
                            icon: const Icon(Icons.clear, size: 20),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                        _buildToolbarDivider(context),
                        IconButton(
                          tooltip: 'Export CSV',
                          onPressed: _exportMembersActivityCsv,
                          icon: const Icon(Icons.download, size: 20),
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: _loadMembers,
                          icon: const Icon(Icons.refresh, size: 20),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showMemberDialog(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Member'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ],
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
                    : Theme(
                        data: Theme.of(context).copyWith(
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          checkboxTheme: Theme.of(context).checkboxTheme.copyWith(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        child: DataTable2(
                        columnSpacing: 8,
                        horizontalMargin: 12,
                        dataRowHeight: 65,
                        headingRowHeight: 48,
                        showCheckboxColumn: false,
                        minWidth: 740,
                        scrollController: ScrollController(),
                        columns: [
                          DataColumn2(
                            fixedWidth: 40,
                            label: Center(
                              child: Transform.scale(
                                scale: 0.8,
                                child: Checkbox(
                                  tristate: true,
                                  value: filteredMembers.isEmpty
                                      ? false
                                      : filteredMembers.every((m) => _selectedMemberIds.contains((m as Member).id))
                                          ? true
                                          : filteredMembers.any((m) => _selectedMemberIds.contains((m as Member).id))
                                              ? null
                                              : false,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        for (final m in filteredMembers) {
                                          _selectedMemberIds.add((m as Member).id);
                                        }
                                      } else {
                                        for (final m in filteredMembers) {
                                          _selectedMemberIds.remove((m as Member).id);
                                        }
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                          const DataColumn2(label: Text('Photo'), fixedWidth: 54),
                          const DataColumn2(label: Text('Name'), size: ColumnSize.L),
                          const DataColumn2(label: Text('Email'), size: ColumnSize.M),
                          const DataColumn2(label: Text('Phone'), size: ColumnSize.S),
                          const DataColumn2(label: Text('Type'), fixedWidth: 105),
                          const DataColumn2(label: Text('Borrowed'), fixedWidth: 85),
                          const DataColumn2(label: Text('Status'), fixedWidth: 80),
                          const DataColumn2(label: Text('Actions'), fixedWidth: 120),
                        ],
                        rows: filteredMembers
                            .asMap()
                            .entries
                            .map(
                              (entry) {
                                final idx = entry.key;
                                final member = entry.value as Member;
                                return DataRow(
                                color: idx.isEven
                                    ? WidgetStateProperty.all(
                                        Theme.of(context).colorScheme.zebraStripe)
                                    : null,
                                selected: _selectedMemberIds.contains(member.id),
                                onSelectChanged: (selected) {
                                  if (selected == null) return;
                                  setState(() {
                                    if (selected) {
                                      _selectedMemberIds.add(member.id);
                                    } else {
                                      _selectedMemberIds.remove(member.id);
                                    }
                                  });
                                },
                                cells: [
                                  DataCell(
                                    Center(
                                      child: Transform.scale(
                                        scale: 0.82,
                                        child: Checkbox(
                                          value: _selectedMemberIds.contains(member.id),
                                          onChanged: (checked) {
                                            setState(() {
                                              if (checked == true) {
                                                _selectedMemberIds.add(member.id);
                                              } else {
                                                _selectedMemberIds.remove(member.id);
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
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
      case 'additional_director':
        color = Colors.purple;
        icon = Icons.apartment;
        label = 'Additional Director';
        break;
      case 'joint_director':
        color = Colors.deepPurple;
        icon = Icons.apartment_outlined;
        label = 'Joint Director';
        break;
      case 'deputy_director':
        color = Colors.indigo;
        icon = Icons.badge;
        label = 'Deputy Director';
        break;
      case 'assistant_commissioner':
        color = Colors.teal;
        icon = Icons.account_balance;
        label = 'Assistant Commissioner';
        break;
      case 'state_tax_officer':
        color = Colors.green;
        icon = Icons.account_balance_wallet;
        label = 'State Tax Officer';
        break;
      case 'assistant':
        color = Colors.blueGrey;
        icon = Icons.person;
        label = 'Assistant';
        break;
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

  Future<void> _deleteSelectedMembers() async {
    final ids = _selectedMemberIds.toList()..sort();
    if (ids.isEmpty) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final memberProvider = context.read<MemberProvider>();
    final issueProvider = context.read<IssueProvider>();
    final cs = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete selected members'),
        content: Text('Delete ${ids.length} selected member(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
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
            Expanded(child: Text('Deleting ${ids.length} members...')),
          ],
        ),
      ),
    );

    try {
      final result = await ApiService.bulkDeleteMembers(ids);
      final deletedCount = result['deleted'] ?? 0;

      if (!mounted) return;
      navigator.pop();

      await memberProvider.loadMembers();
      await issueProvider.loadStats();

      if (!mounted) return;
      setState(() => _selectedMemberIds.clear());

      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text('Deleted $deletedCount member(s) successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      navigator.maybePop();
      messenger.showSnackBar(SnackBar(content: Text(getOperationErrorMessage('Bulk delete', e))));
    }
  }

  void _deleteMember(int id) {
    final memberProvider = context.read<MemberProvider>();
    final issueProvider = context.read<IssueProvider>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: cs.error),
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
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await memberProvider.deleteMember(id);
                await issueProvider.loadStats();
                if (mounted) {
                  messenger?.clearSnackBars();
                  messenger?.showSnackBar(
                    SnackBar(
                      content: const Text('Member deleted successfully'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () {
                          memberProvider.loadMembers();
                          issueProvider.loadStats();
                        },
                      ),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger?.showSnackBar(
                    SnackBar(
                      content: Text(getOperationErrorMessage('Delete member', e)),
                      backgroundColor: cs.error,
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
