import 'dart:convert';
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
import '../services/api_service.dart';
import '../utils/hindi_text.dart';

enum MemberStatusFilter { all, active, inactive }

class MembersContent extends StatefulWidget {
  const MembersContent({super.key});

  @override
  State<MembersContent> createState() => _MembersContentState();
}

class _MembersContentState extends State<MembersContent> {
  final TextEditingController _searchController = TextEditingController();
  MemberStatusFilter _statusFilter = MemberStatusFilter.all;

  TextStyle _textStyleForHindi(String text, TextStyle base) {
    if (containsDevanagari(text) || looksLikeLegacyHindi(text)) {
      return base.copyWith(
        fontFamilyFallback: const [
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
  }

  void _loadMembers() {
    try {
      context.read<MemberProvider>().loadMembers().catchError((error) {
        if (kDebugMode) debugPrint('Error loading members: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading members: $error')),
          );
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error in loadMembers: $e');
    }
  }

  List getFilteredMembers(List members) {
    final rawQuery = _searchController.text;
    final query = rawQuery.toLowerCase();
    // Normalize query for Hindi matching
    final normalizedQuery = normalizeHindiForDisplay(rawQuery).toLowerCase();
    // Convert to KrutiDev for matching legacy data
    final krutiDevQuery = unicodeToKrutiDevApprox(rawQuery).toLowerCase();

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

    if (query.isEmpty) return filteredByStatus;
    return filteredByStatus.where((member) {
      final m = member as Member;
      // Normalize member name for Hindi matching
      final normalizedName = normalizeHindiForDisplay(m.name).toLowerCase();
      final rawName = m.name.toLowerCase();
      return normalizedName.contains(query) ||
          normalizedName.contains(normalizedQuery) ||
          rawName.contains(krutiDevQuery) ||
          m.name.toLowerCase().contains(query) ||
          (m.email ?? '').toLowerCase().contains(query) ||
          (m.phone ?? '').contains(query);
    }).toList();
  }

  void _filterMembers() {
    setState(() {});
  }

  Future<void> _exportMembersActivityCsv() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final members = await ApiService.getMembers();
      final issues = await ApiService.getIssues();

      if (!mounted) return;

      if (members.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No members to export')),
        );
        return;
      }

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Members Export (CSV)',
        fileName:
            'members_activity_${DateTime.now().toIso8601String().split('T')[0]}.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (path == null || path.isEmpty) return;

      String csvEscape(String value) {
        final safe = value.replaceAll('"', '""');
        if (safe.contains(',') ||
            safe.contains('\n') ||
            safe.contains('\r') ||
            safe.contains('"')) {
          return '"$safe"';
        }
        return safe;
      }

      final totalByMember = <int, int>{};
      final issuedByMember = <int, int>{};
      final returnedByMember = <int, int>{};
      final overdueByMember = <int, int>{};
      final lastActivityByMember = <int, DateTime>{};

      DateTime? tryParseDate(String? s) {
        if (s == null) return null;
        final t = s.trim();
        if (t.isEmpty) return null;
        return DateTime.tryParse(t);
      }

      for (final issue in issues) {
        final mid = issue.memberId;
        totalByMember[mid] = (totalByMember[mid] ?? 0) + 1;

        if (issue.status == 'returned') {
          returnedByMember[mid] = (returnedByMember[mid] ?? 0) + 1;
        } else {
          issuedByMember[mid] = (issuedByMember[mid] ?? 0) + 1;
          if (issue.status == 'overdue' || issue.isOverdue) {
            overdueByMember[mid] = (overdueByMember[mid] ?? 0) + 1;
          }
        }

        final date =
            tryParseDate(issue.returnDate) ??
            tryParseDate(issue.issueDate) ??
            tryParseDate(issue.dueDate);
        if (date != null) {
          final prev = lastActivityByMember[mid];
          if (prev == null || date.isAfter(prev)) {
            lastActivityByMember[mid] = date;
          }
        }
      }

      final buffer = StringBuffer();
      buffer.writeln(
        [
          'Member ID',
          'Name',
          'Email',
          'Phone',
          'Type',
          'Active',
          'Membership Date',
          'Expiry Date',
          'Total Issues',
          'Currently Issued',
          'Returned',
          'Overdue',
          'Last Activity',
        ].map(csvEscape).join(','),
      );

      for (final m in members) {
        final mid = m.id;
        final last = lastActivityByMember[mid];
        final lastStr = last == null
            ? ''
            : last.toIso8601String().split('T')[0];

        buffer.writeln(
          [
            m.id.toString(),
            m.name,
            m.email ?? '',
            m.phone ?? '',
            m.memberType,
            m.isActive ? 'Yes' : 'No',
            m.membershipDate,
            m.expiryDate ?? '',
            (totalByMember[mid] ?? 0).toString(),
            (issuedByMember[mid] ?? 0).toString(),
            (returnedByMember[mid] ?? 0).toString(),
            (overdueByMember[mid] ?? 0).toString(),
            lastStr,
          ].map((v) => csvEscape(v.toString())).join(','),
        );
      }

      // Excel on Windows often mis-detects UTF-8 without BOM.
      final bytes = utf8.encode(buffer.toString());
      const bom = <int>[0xEF, 0xBB, 0xBF];
      await File(path).writeAsBytes([...bom, ...bytes], flush: true);

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Exported CSV to: $path')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberProvider = Provider.of<MemberProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCompact ? 'Members' : 'Member Management'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Export Excel (CSV)',
            onPressed: _exportMembersActivityCsv,
            icon: const Icon(Icons.download),
          ),
          const SizedBox(width: 4),
          if (isCompact)
            IconButton(
              tooltip: 'Add Member',
              onPressed: () => _showMemberDialog(),
              icon: const Icon(Icons.person_add),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _showMemberDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Member'),
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
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search members...',
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
                    onChanged: (value) => _filterMembers(),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _statusFilter == MemberStatusFilter.all,
                        onSelected: (_) => setState(() {
                          _statusFilter = MemberStatusFilter.all;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('Active'),
                        selected: _statusFilter == MemberStatusFilter.active,
                        onSelected: (_) => setState(() {
                          _statusFilter = MemberStatusFilter.active;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('Inactive'),
                        selected: _statusFilter == MemberStatusFilter.inactive,
                        onSelected: (_) => setState(() {
                          _statusFilter = MemberStatusFilter.inactive;
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                elevation: 4,
                child: memberProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : memberProvider.members.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 80,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No members found',
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
                              'Click "Add Member" to create a new member',
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
                              onPressed: _loadMembers,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : DataTable2(
                        columnSpacing: 8,
                        horizontalMargin: 12,
                        dataRowHeight: 65,
                        minWidth: 700,
                        scrollController: ScrollController(),
                        columns: const [
                          DataColumn2(label: Text('Photo'), fixedWidth: 50),
                          DataColumn2(label: Text('Name'), size: ColumnSize.L),
                          DataColumn2(label: Text('Email'), size: ColumnSize.M),
                          DataColumn2(label: Text('Phone'), size: ColumnSize.S),
                          DataColumn2(label: Text('Type'), fixedWidth: 90),
                          DataColumn2(label: Text('Status'), fixedWidth: 70),
                          DataColumn2(label: Text('Actions'), fixedWidth: 100),
                        ],
                        rows: getFilteredMembers(memberProvider.members)
                            .map(
                              (member) => DataRow(
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
                                  DataCell(_buildStatusChip(member.isActive)),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(
                                              Icons.history,
                                              size: 14,
                                            ),
                                            tooltip: 'View History',
                                            onPressed: () =>
                                                _showMemberHistory(member),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(
                                              Icons.edit,
                                              size: 14,
                                            ),
                                            tooltip: 'Edit',
                                            onPressed: () => _showMemberDialog(
                                              member: member,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(
                                              Icons.delete,
                                              size: 14,
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
                              ),
                            )
                            .toList(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMemberDialog({Member? member}) async {
    final result = await showDialog(
      context: context,
      builder: (context) => MemberDialog(member: member),
    );
    if (mounted && result == true) {
      await context.read<MemberProvider>().loadMembers();
      await context.read<IssueProvider>().loadStats();
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
        icon = Icons.person;
        label = 'FACU';
        break;
      case 'staff':
        color = Colors.green;
        icon = Icons.work;
        label = 'STAFF';
        break;
      case 'guest':
        color = Colors.orange;
        icon = Icons.person_outline;
        label = 'GUEST';
        break;
      default: // student
        color = Colors.blue;
        icon = Icons.school;
        label = 'STU';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isActive ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  void _deleteMember(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Member'),
        content: const Text('Are you sure you want to delete this member?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop();
              try {
                await context.read<MemberProvider>().deleteMember(id);
                await context.read<IssueProvider>().loadStats();
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    const SnackBar(
                      content: Text('Member deleted successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(content: Text('Failed to delete member: $e')),
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
