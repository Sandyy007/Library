import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/responsive.dart';
import '../providers/report_provider.dart';
import '../providers/issue_provider.dart';
import '../models/report_models.dart';
import '../utils/date_formatter.dart';
import '../utils/hindi_text.dart';
import '../utils/error_utils.dart';
import '../utils/hindi_pdf_helper.dart';

class ReportsContent extends StatefulWidget {
  const ReportsContent({super.key});

  @override
  State<ReportsContent> createState() => _ReportsContentState();
}

class _ReportsContentState extends State<ReportsContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isExporting = false;

  bool get _enableChartTouch {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return false;
    }
  }

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
    final responsive = Responsive(context);
    final isCompact = responsive.isCompact;

    return Scaffold(
      body: Column(
        children: [
          // Tabs and action icons in a single toolbar row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            margin: EdgeInsets.fromLTRB(
              isCompact ? 12 : 20,
              isCompact ? 12 : 20,
              isCompact ? 12 : 20,
              8,
            ),
            child: Row(
              children: [
                // Tab bar
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
                    dividerHeight: 0,
                    tabs: const [
                      Tab(icon: Icon(Icons.star_rounded, size: 18), text: 'Popular'),
                      Tab(icon: Icon(Icons.people_rounded, size: 18), text: 'Members'),
                      Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'Monthly'),
                      Tab(icon: Icon(Icons.pie_chart_rounded, size: 18), text: 'Category'),
                      Tab(icon: Icon(Icons.warning_rounded, size: 18), text: 'Overdue'),
                    ],
                  ),
                ),
                // Vertical divider
                Container(
                  height: 28,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                // Export
                if (_isExporting)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.download_rounded, size: 20),
                    tooltip: 'Export Reports',
                    onSelected: _exportReport,
                    padding: EdgeInsets.zero,
                    splashRadius: 20,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'pdf',
                        child: Row(
                          children: [
                            Icon(Icons.picture_as_pdf, color: const Color(0xFFEF4444), size: 18),
                            SizedBox(width: 8),
                            Text('Export to PDF'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'excel',
                        child: Row(
                          children: [
                            Icon(Icons.table_chart, color: const Color(0xFF10B981), size: 18),
                            SizedBox(width: 8),
                            Text('Export to CSV'),
                          ],
                        ),
                      ),
                    ],
                  ),
                // Refresh
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: _loadAllReports,
                  tooltip: 'Refresh Reports',
                  visualDensity: VisualDensity.compact,
                  splashRadius: 20,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 12 : 20,
                0,
                isCompact ? 12 : 20,
                isCompact ? 12 : 20,
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPopularBooksTab(),
                  _buildActiveMembersTab(),
                  _buildMonthlyStatsTab(),
                  _buildCategoryStatsTab(),
                  _buildOverdueTab(),
                ],
              ),
            ),
          ),
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
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
      rankColor = const Color(0xFFD97706);
    } else if (rank == 2) {
      rankColor = const Color(0xFF6B7280);
    } else if (rank == 3) {
      rankColor = const Color(0xFF8D6E63);
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
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
                      ? const Color(0xFFD97706)
                      : rank == 2
                      ? const Color(0xFF6B7280)
                      : const Color(0xFF8D6E63),
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
          Expanded(
            child: Text(
              'Borrowed: ${member.borrowCount}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
          Text(
            'total borrowed',
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTypeChip(String type) {
    Color color;
    String label;
    switch (type.toLowerCase()) {
      case 'additional_director':
        color = const Color(0xFF7C3AED);
        label = 'Additional Director';
        break;
      case 'joint_director':
        color = const Color(0xFF6D28D9);
        label = 'Joint Director';
        break;
      case 'deputy_director':
        color = const Color(0xFF4F46E5);
        label = 'Deputy Director';
        break;
      case 'assistant_commissioner':
        color = const Color(0xFF0D9488);
        label = 'Assistant Commissioner';
        break;
      case 'state_tax_officer':
        color = const Color(0xFF10B981);
        label = 'State Tax Officer';
        break;
      case 'assistant':
        color = const Color(0xFF6B7280);
        label = 'Assistant';
        break;
      case 'faculty':
        color = const Color(0xFF8B5CF6);
        label = 'Faculty';
        break;
      case 'staff':
        color = const Color(0xFF059669);
        label = 'Staff';
        break;
      case 'guest':
        color = const Color(0xFFF59E0B);
        label = 'Guest';
        break;
      default:
        color = const Color(0xFF3B82F6);
        label = 'Student';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              // Summary cards
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 500) {
                    // Stack cards vertically on small screens
                    return Column(
                      children: [
                        _buildSummaryCard(
                          'Total Issues',
                          provider.monthlyStats
                              .fold(0, (sum, s) => sum + s.issues)
                              .toString(),
                          Icons.arrow_upward,
                          const Color(0xFF3B82F6),
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryCard(
                          'Total Returns',
                          provider.monthlyStats
                              .fold(0, (sum, s) => sum + s.returns)
                              .toString(),
                          Icons.arrow_downward,
                          const Color(0xFF10B981),
                        ),
                        const SizedBox(height: 12),
                        _buildSummaryCard(
                          'Avg/Month',
                          (provider.monthlyStats.fold(
                                    0,
                                    (sum, s) => sum + s.issues,
                                  ) ~/
                                  provider.monthlyStats.length)
                              .toString(),
                          Icons.trending_up,
                          const Color(0xFFF59E0B),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Issues',
                          provider.monthlyStats
                              .fold(0, (sum, s) => sum + s.issues)
                              .toString(),
                          Icons.arrow_upward,
                          const Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Returns',
                          provider.monthlyStats
                              .fold(0, (sum, s) => sum + s.returns)
                              .toString(),
                          Icons.arrow_downward,
                          const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Avg/Month',
                          (provider.monthlyStats.fold(
                                    0,
                                    (sum, s) => sum + s.issues,
                                  ) ~/
                                  provider.monthlyStats.length)
                              .toString(),
                          Icons.trending_up,
                          const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          enabled: _enableChartTouch,
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
              color: const Color(0xFF9CA3AF).withValues(alpha: 0.2),
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
                color: const Color(0xFF3B82F6),
                width: 12,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              BarChartRodData(
                toY: stat.returns.toDouble(),
                color: const Color(0xFF10B981),
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

  int _touchedCategoryIndex = -1;

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
        final totalBorrows = provider.categoryStats.fold(
          0,
          (sum, s) => sum + s.borrowCount,
        );

        // Sort categories by book count for better visibility
        final sortedStats = List<CategoryStats>.from(provider.categoryStats)
          ..sort((a, b) => b.bookCount.compareTo(a.bookCount));

        // Group tiny categories (< 3%) into "Other" if there are 6+ categories
        final displayStats = <CategoryStats>[];
        int otherBookCount = 0;
        int otherBorrowCount = 0;
        int otherCount = 0;
        const double groupingThreshold = 3.0;
        for (final stat in sortedStats) {
          final pct = (stat.bookCount / total) * 100;
          if (pct < groupingThreshold && sortedStats.length >= 6) {
            otherBookCount += stat.bookCount;
            otherBorrowCount += stat.borrowCount;
            otherCount++;
          } else {
            displayStats.add(stat);
          }
        }
        if (otherCount > 1) {
          displayStats.add(CategoryStats(
            category: 'Other ($otherCount)',
            bookCount: otherBookCount,
            borrowCount: otherBorrowCount,
          ));
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 700;
              
              final pieChart = Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.donut_large_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Books by Category',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${displayStats.length} categories \u2022 $total books \u2022 $totalBorrows borrows',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Tooltip for hovered/touched segment
                      if (_touchedCategoryIndex >= 0 && _touchedCategoryIndex < displayStats.length)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(_touchedCategoryIndex).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(_touchedCategoryIndex),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${displayStats[_touchedCategoryIndex].category}: '
                                  '${displayStats[_touchedCategoryIndex].bookCount} books, '
                                  '${displayStats[_touchedCategoryIndex].borrowCount} borrows '
                                  '(${total > 0 ? ((displayStats[_touchedCategoryIndex].bookCount / total) * 100).toStringAsFixed(1) : "0"}%)',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _getCategoryColor(_touchedCategoryIndex),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Text(
                            'Tap or hover over a segment for details',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sections: displayStats.asMap().entries.map((
                              entry,
                            ) {
                              final index = entry.key;
                              final stat = entry.value;
                              final percentage = total > 0 
                                  ? (stat.bookCount / total) * 100 
                                  : 0.0;
                              final isTouched = index == _touchedCategoryIndex;
                              final color = _getCategoryColor(index);
                              final luminance = color.computeLuminance();
                              final labelColor = luminance > 0.5 ? Colors.black87 : Colors.white;
                              
                              String title;
                              if (percentage >= 12) {
                                final name = stat.category.length > 12
                                    ? '${stat.category.substring(0, 11)}\u2026'
                                    : stat.category;
                                title = '$name\n${stat.bookCount}';
                              } else if (percentage >= 6) {
                                final name = stat.category.length > 8
                                    ? '${stat.category.substring(0, 7)}\u2026'
                                    : stat.category;
                                title = name;
                              } else if (percentage >= 3) {
                                title = '${stat.bookCount}';
                              } else {
                                title = '';
                              }
                              
                              return PieChartSectionData(
                                value: stat.bookCount.toDouble(),
                                title: title,
                                color: color,
                                radius: isTouched ? 115 : 100,
                                titleStyle: TextStyle(
                                  fontSize: isTouched ? 13 : 11,
                                  fontWeight: FontWeight.bold,
                                  color: labelColor,
                                  shadows: luminance <= 0.5
                                      ? const [Shadow(color: Colors.black54, blurRadius: 4)]
                                      : null,
                                ),
                                titlePositionPercentageOffset: 0.55,
                                borderSide: isTouched
                                    ? BorderSide(color: labelColor, width: 2.5)
                                    : BorderSide(
                                        color: Theme.of(context).colorScheme.surface,
                                        width: 1.5,
                                      ),
                              );
                            }).toList(),
                            sectionsSpace: 1,
                            centerSpaceRadius: 50,
                            pieTouchData: PieTouchData(
                              enabled: _enableChartTouch,
                              touchCallback: (event, response) {
                                if (!_enableChartTouch) return;
                                setState(() {
                                  if (!event.isInterestedForInteractions ||
                                      response == null ||
                                      response.touchedSection == null) {
                                    _touchedCategoryIndex = -1;
                                    return;
                                  }
                                  _touchedCategoryIndex = response
                                      .touchedSection!.touchedSectionIndex;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
              
              final legend = Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.list_alt_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Categories',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: displayStats.length,
                          itemBuilder: (context, index) {
                            final stat = displayStats[index];
                            final percentage = total > 0 
                                ? (stat.bookCount / total) * 100 
                                : 0.0;
                            final isHighlighted = index == _touchedCategoryIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 8,
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(
                                color: isHighlighted
                                    ? _getCategoryColor(index).withValues(alpha: 0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  setState(() {
                                    _touchedCategoryIndex = _touchedCategoryIndex == index ? -1 : index;
                                  });
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: _getCategoryColor(index),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            stat.category,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getCategoryColor(index).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${stat.bookCount} (${percentage.toStringAsFixed(1)}%)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              color: _getCategoryColor(index),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: percentage / 100,
                                        backgroundColor: _getCategoryColor(index).withValues(alpha: 0.1),
                                        color: _getCategoryColor(index),
                                        minHeight: 3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
              
              if (isNarrow) {
                return Column(
                  children: [
                    Expanded(flex: 2, child: pieChart),
                    const SizedBox(height: 16),
                    Expanded(flex: 1, child: legend),
                  ],
                );
              }
              
              return Row(
                children: [
                  Expanded(flex: 2, child: pieChart),
                  const SizedBox(width: 20),
                  Expanded(flex: 1, child: legend),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Color _getCategoryColor(int index) {
    // Curated color palette with good contrast and distinction between adjacent colors
    const colors = [
      Color(0xFF4285F4), // Google Blue
      Color(0xFFEA4335), // Google Red
      Color(0xFF34A853), // Google Green
      Color(0xFFFBBC04), // Google Yellow
      Color(0xFF9C27B0), // Purple
      Color(0xFF00ACC1), // Cyan
      Color(0xFFFF7043), // Deep Orange
      Color(0xFF5C6BC0), // Indigo
      Color(0xFF66BB6A), // Light Green
      Color(0xFFEC407A), // Pink
      Color(0xFF26A69A), // Teal
      Color(0xFFAB47BC), // Light Purple
      Color(0xFF42A5F5), // Light Blue
      Color(0xFFFFA726), // Orange
      Color(0xFF78909C), // Blue Grey
      Color(0xFF8D6E63), // Brown
      Color(0xFFD4E157), // Lime
      Color(0xFFEF5350), // Red shade
      Color(0xFF29B6F6), // Sky Blue
      Color(0xFFFF8A65), // Peach
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
                          style: TextStyle(color: const Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    avatar: Icon(
                      Icons.warning,
                      color: const Color(0xFFEF4444),
                      size: 18,
                    ),
                    label: Text('${overdueList.length} Overdue'),
                    backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
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
          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.warning, color: Color(0xFFEF4444)),
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
          color: const Color(0xFFEF4444),
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

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Widget _buildEmptyState(String message, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary.withValues(alpha: 0.1),
                  ),
                  child: Icon(icon, size: 48, color: cs.primary.withValues(alpha: 0.5)),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
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
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getOperationErrorMessage('Export report', e)),
            backgroundColor: const Color(0xFFEF4444),
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

    // Embed Hindi-supporting font for proper Devanagari text rendering.
    await HindiPdfHelper.initialize();
    final baseFont = HindiPdfHelper.baseFont;
    final boldFont = HindiPdfHelper.boldFont;

    // Load organization logo
    final logoBytes = await _loadPdfLogo();

    final doc = pw.Document();
    final table = await _buildPdfTable(exportName);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (context) => [
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
                'Reports & Analytics — $title',
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
              HindiPdfHelper.normalizeForPdf(e.value.title),
              HindiPdfHelper.normalizeForPdf(e.value.author),
              HindiPdfHelper.normalizeForPdf(e.value.category ?? 'Uncategorized'),
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
              HindiPdfHelper.normalizeForPdf(e.value.name),
              HindiPdfHelper.normalizeForPdf(e.value.memberType),
              '${e.value.borrowCount}',
            ],
          )
          .toList();
    } else if (exportName == 'monthly_stats') {
      headers = ['Month', 'Issues', 'Returns', 'Overdue'];
      rows = reportProvider.monthlyStats
          .map(
            (m) => [
              HindiPdfHelper.normalizeForPdf(m.monthName),
              '${m.issues}',
              '${m.returns}',
              '${m.overdue}',
            ],
          )
          .toList();
    } else if (exportName == 'category_stats') {
      headers = ['Category', 'Books', 'Borrows'];
      rows = reportProvider.categoryStats
          .map(
            (c) => [
              HindiPdfHelper.normalizeForPdf(c.category),
              '${c.bookCount}',
              '${c.borrowCount}',
            ],
          )
          .toList();
    } else if (exportName == 'overdue') {
      final overdue = await context.read<IssueProvider>().getOverdueReport();
      headers = ['Title', 'Member', 'Due Date', 'Days Overdue'];
      rows = overdue.map((item) {
        final dueDate = item['due_date']?.toString() ?? '';
        return [
          HindiPdfHelper.normalizeForPdf(item['title']?.toString() ?? 'Unknown'),
          HindiPdfHelper.normalizeForPdf(item['member_name']?.toString() ?? 'Unknown'),
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

    final headerStyle = pw.TextStyle(
      font: HindiPdfHelper.boldFont,
      fontWeight: pw.FontWeight.bold,
      fontSize: 10,
      fontFallback: HindiPdfHelper.boldFontFallback,
    );

    final cellStyle = pw.TextStyle(
      font: HindiPdfHelper.baseFont,
      fontSize: 10,
      fontFallback: HindiPdfHelper.baseFontFallback,
    );

    final hindiCache = await HindiPdfHelper.preRenderHindiTexts(
      rows.expand((row) => row),
      fontSize: 10,
      fontWeight: pw.FontWeight.normal,
      color: PdfColors.black,
    );

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: headerStyle,
      headerDecoration: const pw.BoxDecoration(),
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: cellStyle,
      cellBuilder: (index, data, rowNum) {
        return HindiPdfHelper.buildCachedText(
          data.toString(),
          style: cellStyle,
          cache: hindiCache,
        );
      },
      headerHeight: 26,
      cellHeight: 22,
      cellAlignments: {
        for (int i = 0; i < headers.length; i++) i: pw.Alignment.centerLeft,
      },
    );
  }

  Future<String> _buildCsv(String exportName) async {
    final reportProvider = context.read<ReportProvider>();
    final now = DateTime.now();
    final generatedOn = '${now.day.toString().padLeft(2, '0')}-'
        '${_getMonthName(now.month)}-${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')} IST';

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
    // Add generation timestamp as comment
    buffer.writeln('# Generated on: $generatedOn');
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
