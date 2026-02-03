import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show PdfGoogleFonts;
import '../providers/report_provider.dart';
import '../providers/issue_provider.dart';
import '../models/report_models.dart';
import '../utils/date_formatter.dart';
import '../utils/hindi_text.dart';

class ReportsContent extends StatefulWidget {
  const ReportsContent({super.key});

  @override
  State<ReportsContent> createState() => _ReportsContentState();
}

class _ReportsContentState extends State<ReportsContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllReports();
    });
  }

  Future<void> _loadAllReports() async {
    final reportProvider = context.read<ReportProvider>();
    await reportProvider.loadPopularBooks();
    await reportProvider.loadActiveMembers();
    await reportProvider.loadMonthlyStats();
    await reportProvider.loadCategoryStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        elevation: 0,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.download),
              tooltip: 'Export Reports',
              onSelected: _exportReport,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Export to PDF'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'excel',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Export to Excel (CSV)'),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllReports,
            tooltip: 'Refresh Reports',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.star), text: 'Popular Books'),
            Tab(icon: Icon(Icons.people), text: 'Active Members'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Monthly Stats'),
            Tab(icon: Icon(Icons.pie_chart), text: 'Categories'),
            Tab(icon: Icon(Icons.warning), text: 'Overdue'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPopularBooksTab(),
          _buildActiveMembersTab(),
          _buildMonthlyStatsTab(),
          _buildCategoryStatsTab(),
          _buildOverdueTab(),
        ],
      ),
    );
  }

  Widget _buildPopularBooksTab() {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.popularBooks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.popularBooks.isEmpty) {
          return _buildEmptyState('No popular books data', Icons.book_outlined);
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Most Borrowed Books',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Books ranked by total borrow count',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Card(
                  elevation: 2,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.popularBooks.length,
                    separatorBuilder: (_, i) => const Divider(),
                    itemBuilder: (context, index) {
                      final book = provider.popularBooks[index];
                      return _buildPopularBookTile(book, index + 1);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPopularBookTile(PopularBook book, int rank) {
    Color rankColor;
    if (rank == 1) {
      rankColor = Colors.amber;
    } else if (rank == 2) {
      rankColor = Colors.grey;
    } else if (rank == 3) {
      rankColor = Colors.brown;
    } else {
      rankColor = Theme.of(context).colorScheme.primary;
    }

    final displayTitle = normalizeHindiForDisplay(book.title);
    final displayAuthor = normalizeHindiForDisplay(book.author);

    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
      minVerticalPadding: 6,
      leading: CircleAvatar(
        backgroundColor: rankColor.withValues(alpha: 0.2),
        child: Text(
          '#$rank',
          style: TextStyle(color: rankColor, fontWeight: FontWeight.bold),
        ),
      ),
      title: Builder(
        builder: (context) => Text(
          displayTitle,
          style: hindiAwareTextStyle(
            context,
            text: displayTitle,
            base: const TextStyle(fontWeight: FontWeight.w500),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      subtitle: Builder(
        builder: (context) => Text(
          '$displayAuthor • ${book.category ?? "Uncategorized"}',
          style: hindiAwareTextStyle(
            context,
            text: displayAuthor,
            base: const TextStyle(),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: SizedBox(
        height: 38,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${book.borrowCount}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  height: 1.0,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                'borrows',
                style: TextStyle(
                  fontSize: 9,
                  height: 1.0,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveMembersTab() {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.activeMembers.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.activeMembers.isEmpty) {
          return _buildEmptyState(
            'No active members data',
            Icons.people_outline,
          );
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Most Active Members',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Members ranked by total books borrowed',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Card(
                  elevation: 2,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.activeMembers.length,
                    separatorBuilder: (_, i) => const Divider(),
                    itemBuilder: (context, index) {
                      final member = provider.activeMembers[index];
                      return _buildActiveMemberTile(member, index + 1);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveMemberTile(ActiveMember member, int rank) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              member.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (rank <= 3)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: rank == 1
                      ? Colors.amber
                      : rank == 2
                      ? Colors.grey
                      : Colors.brown,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        member.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          _buildMemberTypeChip(member.memberType),
          const SizedBox(width: 8),
          Text('Borrowed: ${member.borrowCount}'),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${member.borrowCount}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Text(
            'total borrowed',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTypeChip(String type) {
    Color color;
    switch (type.toLowerCase()) {
      case 'faculty':
        color = Colors.purple;
        break;
      case 'staff':
        color = Colors.green;
        break;
      default:
        color = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMonthlyStatsTab() {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.monthlyStats.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.monthlyStats.isEmpty) {
          return _buildEmptyState('No monthly stats data', Icons.bar_chart);
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monthly Statistics',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Issues and returns over the last 12 months',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              // Summary cards
              Row(
                children: [
                  _buildSummaryCard(
                    'Total Issues',
                    provider.monthlyStats
                        .fold(0, (sum, s) => sum + s.issues)
                        .toString(),
                    Icons.arrow_upward,
                    Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  _buildSummaryCard(
                    'Total Returns',
                    provider.monthlyStats
                        .fold(0, (sum, s) => sum + s.returns)
                        .toString(),
                    Icons.arrow_downward,
                    Colors.green,
                  ),
                  const SizedBox(width: 16),
                  _buildSummaryCard(
                    'Avg per Month',
                    (provider.monthlyStats.fold(
                              0,
                              (sum, s) => sum + s.issues,
                            ) ~/
                            provider.monthlyStats.length)
                        .toString(),
                    Icons.trending_up,
                    Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildBarChart(provider.monthlyStats),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(List<MonthlyStats> stats) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY:
            stats
                .map((s) => s.issues > s.returns ? s.issues : s.returns)
                .reduce((a, b) => a > b ? a : b)
                .toDouble() *
            1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final stat = stats[group.x.toInt()];
              return BarTooltipItem(
                '${stat.monthName}\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: rodIndex == 0
                        ? 'Issues: ${stat.issues}'
                        : 'Returns: ${stat.returns}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < stats.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      stats[value.toInt()].monthName.substring(0, 3),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: stats.asMap().entries.map((entry) {
          final index = entry.key;
          final stat = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: stat.issues.toDouble(),
                color: Colors.blue,
                width: 12,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              BarChartRodData(
                toY: stat.returns.toDouble(),
                color: Colors.green,
                width: 12,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryStatsTab() {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.categoryStats.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.categoryStats.isEmpty) {
          return _buildEmptyState('No category stats data', Icons.pie_chart);
        }

        final total = provider.categoryStats.fold(
          0,
          (sum, s) => sum + s.bookCount,
        );

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              // Pie Chart
              Expanded(
                flex: 2,
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Books by Category',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sections: provider.categoryStats.asMap().entries.map((
                                entry,
                              ) {
                                final index = entry.key;
                                final stat = entry.value;
                                return PieChartSectionData(
                                  value: stat.bookCount.toDouble(),
                                  title:
                                      '${((stat.bookCount / total) * 100).toStringAsFixed(1)}%',
                                  color: _getCategoryColor(index),
                                  radius: 100,
                                  titleStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              }).toList(),
                              sectionsSpace: 2,
                              centerSpaceRadius: 60,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Legend
              Expanded(
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Categories',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: provider.categoryStats.length,
                            itemBuilder: (context, index) {
                              final stat = provider.categoryStats[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: _getCategoryColor(index),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        stat.category,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${stat.bookCount}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
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
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getCategoryColor(int index) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
    ];
    return colors[index % colors.length];
  }

  Widget _buildOverdueTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: context.read<IssueProvider>().getOverdueReport(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildEmptyState(
            'Error loading overdue data',
            Icons.error_outline,
          );
        }

        final overdueList = snapshot.data ?? [];
        if (overdueList.isEmpty) {
          return _buildEmptyState(
            'No overdue books',
            Icons.check_circle_outline,
          );
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overdue Books',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${overdueList.length} books need attention',
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    avatar: const Icon(
                      Icons.warning,
                      color: Colors.red,
                      size: 18,
                    ),
                    label: Text('${overdueList.length} Overdue'),
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Card(
                  elevation: 2,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: overdueList.length,
                    separatorBuilder: (_, i) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = overdueList[index];
                      return _buildOverdueItem(item);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverdueItem(Map<String, dynamic> item) {
    final dueDate = item['due_date']?.toString() ?? '';
    final daysOverdue = _calculateDaysOverdue(dueDate);
    final bookTitle = normalizeHindiForDisplay(
      item['title']?.toString() ?? 'Unknown Book',
    );
    final memberName = normalizeHindiForDisplay(
      item['member_name']?.toString() ?? 'Unknown',
    );

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.warning, color: Colors.red),
      ),
      title: Builder(
        builder: (context) => Text(
          bookTitle,
          style: hindiAwareTextStyle(
            context,
            text: bookTitle,
            base: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ),
      subtitle: Builder(
        builder: (context) => Text(
          'Borrowed by: $memberName\nDue: ${DateFormatter.formatDateIndian(dueDate)}',
          style: hindiAwareTextStyle(
            context,
            text: memberName,
            base: const TextStyle(),
          ),
        ),
      ),
      isThreeLine: true,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$daysOverdue days',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  int _calculateDaysOverdue(String dueDateStr) {
    try {
      final dueDate = DateTime.parse(dueDateStr);
      return DateTime.now().difference(dueDate).inDays;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadAllReports,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportReport(String type) async {
    setState(() => _isExporting = true);

    try {
      final exportName = _tabController.index == 0
          ? 'popular_books'
          : _tabController.index == 1
          ? 'active_members'
          : _tabController.index == 2
          ? 'monthly_stats'
          : _tabController.index == 3
          ? 'category_stats'
          : 'overdue';

      final date = DateTime.now().toIso8601String().split('T')[0];

      if (type == 'pdf') {
        final bytes = await _buildPdfBytes(exportName);
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Save PDF Report',
          fileName: 'report_${exportName}_$date.pdf',
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
        );

        if (!mounted) return;
        if (path == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Export cancelled')));
          return;
        }

        await File(path).writeAsBytes(bytes, flush: true);
      } else if (type == 'excel') {
        final csv = await _buildCsv(exportName);
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Excel (CSV) Report',
          fileName: 'report_${exportName}_$date.csv',
          type: FileType.custom,
          allowedExtensions: const ['csv'],
        );

        if (!mounted) return;
        if (path == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Export cancelled')));
          return;
        }

        // Excel on Windows often mis-detects UTF-8 without BOM.
        final bytes = utf8.encode(csv);
        const bom = <int>[0xEF, 0xBB, 0xBF];
        await File(path).writeAsBytes([...bom, ...bytes], flush: true);
      } else {
        throw Exception('Unsupported export type: $type');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Report exported as ${type.toUpperCase()} successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<Uint8List> _buildPdfBytes(String exportName) async {
    final title = _tabController.index == 0
        ? 'Popular Books'
        : _tabController.index == 1
        ? 'Active Members'
        : _tabController.index == 2
        ? 'Monthly Stats'
        : _tabController.index == 3
        ? 'Categories'
        : 'Overdue';

    // Embed a font that supports Hindi/Devanagari so text renders correctly.
    final baseFont = await PdfGoogleFonts.notoSansDevanagariRegular();
    final boldFont = await PdfGoogleFonts.notoSansDevanagariBold();

    final doc = pw.Document();
    final table = await _buildPdfTable(exportName);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (context) => [
          pw.Text(
            'Reports & Analytics — $title',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          table,
        ],
      ),
    );

    return doc.save();
  }

  Future<pw.Widget> _buildPdfTable(String exportName) async {
    final reportProvider = context.read<ReportProvider>();

    List<String> headers;
    List<List<String>> rows;

    if (exportName == 'popular_books') {
      headers = ['Rank', 'Title', 'Author', 'Category', 'Borrows'];
      rows = reportProvider.popularBooks
          .asMap()
          .entries
          .map(
            (e) => [
              '${e.key + 1}',
              e.value.title,
              e.value.author,
              e.value.category ?? 'Uncategorized',
              '${e.value.borrowCount}',
            ],
          )
          .toList();
    } else if (exportName == 'active_members') {
      headers = ['Rank', 'Name', 'Type', 'Borrowed'];
      rows = reportProvider.activeMembers
          .asMap()
          .entries
          .map(
            (e) => [
              '${e.key + 1}',
              e.value.name,
              e.value.memberType,
              '${e.value.borrowCount}',
            ],
          )
          .toList();
    } else if (exportName == 'monthly_stats') {
      headers = ['Month', 'Issues', 'Returns', 'Overdue'];
      rows = reportProvider.monthlyStats
          .map(
            (m) => [m.monthName, '${m.issues}', '${m.returns}', '${m.overdue}'],
          )
          .toList();
    } else if (exportName == 'category_stats') {
      headers = ['Category', 'Books', 'Borrows'];
      rows = reportProvider.categoryStats
          .map((c) => [c.category, '${c.bookCount}', '${c.borrowCount}'])
          .toList();
    } else if (exportName == 'overdue') {
      final overdue = await context.read<IssueProvider>().getOverdueReport();
      headers = ['Title', 'Member', 'Due Date', 'Days Overdue'];
      rows = overdue.map((item) {
        final dueDate = item['due_date']?.toString() ?? '';
        return [
          item['title']?.toString() ?? 'Unknown',
          item['member_name']?.toString() ?? 'Unknown',
          DateFormatter.formatDateIndian(dueDate),
          '${_calculateDaysOverdue(dueDate)}',
        ];
      }).toList();
    } else {
      headers = ['Message'];
      rows = [
        ['Unsupported report type: $exportName'],
      ];
    }

    if (rows.isEmpty) {
      rows = [
        ['No data'],
      ];
      headers = ['Message'];
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(),
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 10),
      headerHeight: 24,
      cellHeight: 20,
    );
  }

  Future<String> _buildCsv(String exportName) async {
    final reportProvider = context.read<ReportProvider>();

    List<String> headers;
    List<List<String>> rows;

    if (exportName == 'popular_books') {
      headers = ['Rank', 'Title', 'Author', 'Category', 'Borrows'];
      rows = reportProvider.popularBooks
          .asMap()
          .entries
          .map(
            (e) => [
              '${e.key + 1}',
              e.value.title,
              e.value.author,
              e.value.category ?? 'Uncategorized',
              '${e.value.borrowCount}',
            ],
          )
          .toList();
    } else if (exportName == 'active_members') {
      headers = ['Rank', 'Name', 'Type', 'Borrowed'];
      rows = reportProvider.activeMembers
          .asMap()
          .entries
          .map(
            (e) => [
              '${e.key + 1}',
              e.value.name,
              e.value.memberType,
              '${e.value.borrowCount}',
            ],
          )
          .toList();
    } else if (exportName == 'monthly_stats') {
      headers = ['Month', 'Issues', 'Returns', 'Overdue'];
      rows = reportProvider.monthlyStats
          .map(
            (m) => [m.monthName, '${m.issues}', '${m.returns}', '${m.overdue}'],
          )
          .toList();
    } else if (exportName == 'category_stats') {
      headers = ['Category', 'Books', 'Borrows'];
      rows = reportProvider.categoryStats
          .map((c) => [c.category, '${c.bookCount}', '${c.borrowCount}'])
          .toList();
    } else if (exportName == 'overdue') {
      final overdue = await context.read<IssueProvider>().getOverdueReport();
      headers = ['Title', 'Member', 'Due Date', 'Days Overdue'];
      rows = overdue.map((item) {
        final dueDate = item['due_date']?.toString() ?? '';
        return [
          normalizeHindiForDisplay(item['title']?.toString() ?? 'Unknown'),
          normalizeHindiForDisplay(
            item['member_name']?.toString() ?? 'Unknown',
          ),
          DateFormatter.formatDateIndian(dueDate),
          '${_calculateDaysOverdue(dueDate)}',
        ];
      }).toList();
    } else {
      headers = ['Message'];
      rows = [
        ['Unsupported report type: $exportName'],
      ];
    }

    if (rows.isEmpty) {
      headers = ['Message'];
      rows = [
        ['No data'],
      ];
    }

    final buffer = StringBuffer();
    buffer.writeln(headers.map(_csvEscape).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_csvEscape).join(','));
    }
    return buffer.toString();
  }

  String _csvEscape(String value) {
    final needsQuotes =
        value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuotes) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}
