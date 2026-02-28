import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import '../providers/issue_provider.dart';
import '../services/api_service.dart';
import '../utils/date_formatter.dart';
import '../utils/hindi_text.dart';
import '../utils/error_utils.dart';

class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  Timer? _refreshTimer;
  Timer? _statsRefreshTimer;
  StreamSubscription<void>? _dataChangedSub;
  bool _refreshInFlight = false;
  bool _refreshQueued = false;

  bool _extrasLoading = false;
  String? _extrasError;
  Map<String, dynamic>? _alerts;
  List<Map<String, dynamic>> _activity = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll(showLoading: true, includeStats: true);

      // Periodic refresh for realtime-ish updates (other clients).
      _refreshTimer?.cancel();
      // Keep this lightweight: refresh alerts + activity only.
      _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _refreshAll(showLoading: false, includeStats: false);
      });

      // Stats are heavier (impact charts); refresh less often.
      _statsRefreshTimer?.cancel();
      _statsRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        _refreshAll(showLoading: false, includeStats: true);
      });

      // Instant refresh after local mutations (issue/return/add/update/etc).
      _dataChangedSub?.cancel();
      _dataChangedSub = ApiService.dataChangedStream.listen((_) {
        _refreshAll(showLoading: false, includeStats: true);
      });
    });
  }

  Future<void> _refreshAll({
    required bool showLoading,
    required bool includeStats,
  }) async {
    if (!mounted) return;
    if (_refreshInFlight) {
      // Queue one more refresh to run after the current one finishes.
      _refreshQueued = true;
      return;
    }
    _refreshInFlight = true;

    if (showLoading) {
      setState(() {
        _extrasLoading = true;
        _extrasError = null;
      });
    } else {
      // Don't clear existing data during background refresh.
      _extrasError = null;
    }

    try {
      final futures = <Future<dynamic>>[];
      if (includeStats) {
        futures.add(context.read<IssueProvider>().loadStats());
      }
      futures.add(ApiService.getDashboardAlerts(limit: 10));
      futures.add(ApiService.getDashboardActivity(limit: 25));

      final results = await Future.wait(futures);

      final offset = includeStats ? 1 : 0;

      if (!mounted) return;
      setState(() {
        _alerts = results[offset] as Map<String, dynamic>;
        _activity = results[offset + 1] as List<Map<String, dynamic>>;
        _extrasLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _extrasError = e.toString();
        _extrasLoading = false;
      });
    } finally {
      _refreshInFlight = false;

      if (_refreshQueued && mounted) {
        _refreshQueued = false;
        // Fire and forget (we just want to ensure UI eventually syncs).
        unawaited(_refreshAll(showLoading: false, includeStats: true));
      }
    }
  }

  Future<void> _clearRecentActivity() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear recent activity'),
        content: const Text(
          'This will hide all current items from the Recent Activity list (it will not delete books/issues/members). Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiService.clearDashboardActivity();
      if (!mounted) return;
      setState(() {
        _activity = [];
      });
      await _refreshAll(showLoading: false, includeStats: false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Recent activity cleared')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(getOperationErrorMessage('Clear', e))));
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _refreshTimer?.cancel();
    _statsRefreshTimer?.cancel();
    _dataChangedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsProvider = Provider.of<IssueProvider>(context);

    final stats = [
      {
        'title': 'Total Books',
        'value': statsProvider.stats['total_books']?.toString() ?? '0',
        'icon': Icons.library_books_rounded,
        'gradient': LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      },
      {
        'title': 'Issued Books',
        'value': statsProvider.stats['issued_books']?.toString() ?? '0',
        'icon': Icons.assignment_turned_in_rounded,
        'gradient': LinearGradient(
          colors: [Colors.orange.shade600, Colors.orange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      },
      {
        'title': 'Available Books',
        'value': statsProvider.stats['available_books']?.toString() ?? '0',
        'icon': Icons.check_circle_rounded,
        'gradient': LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      },
      {
        'title': 'Overdue Books',
        'value': statsProvider.stats['overdue_books']?.toString() ?? '0',
        'icon': Icons.warning_rounded,
        'gradient': LinearGradient(
          colors: [Colors.red.shade600, Colors.red.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      },
      {
        'title': 'Active Members',
        'value': statsProvider.stats['active_members']?.toString() ?? '0',
        'icon': Icons.people_alt_rounded,
        'gradient': LinearGradient(
          colors: [Colors.purple.shade600, Colors.purple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      },
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Cards - Responsive layout with consistent desktop styling
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth;
                      // Calculate how many cards can fit per row
                      // Consistent sizing for desktop monitors (1200px+)
                      final isDesktop = availableWidth >= 1200;
                      final isTablet = availableWidth >= 800 && availableWidth < 1200;
                      final minCardWidth = isDesktop ? 180.0 : (isTablet ? 160.0 : 140.0);
                      final spacing = isDesktop ? 16.0 : 12.0;
                      final cardsPerRow = isDesktop
                          ? stats.length  // All cards in one row on desktop
                          : (availableWidth / (minCardWidth + spacing))
                              .floor()
                              .clamp(2, stats.length);
                      final cardWidth =
                          (availableWidth - (spacing * (cardsPerRow - 1))) /
                          cardsPerRow;
                      final isCompact = availableWidth < 600;
                      final cardHeight = isDesktop ? 130.0 : (isCompact ? 100.0 : 120.0);

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: List.generate(stats.length, (index) {
                          final stat = stats[index];
                          return Container(
                            width: cardWidth,
                            height: cardHeight,
                            padding: EdgeInsets.all(isCompact ? 10 : 14),
                            decoration: BoxDecoration(
                              gradient: stat['gradient'] as LinearGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: (stat['gradient'] as LinearGradient)
                                      .colors
                                      .first
                                      .withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  stat['icon'] as IconData,
                                  size: isCompact ? 20 : 24,
                                  color: Colors.white,
                                ),
                                SizedBox(height: isCompact ? 4 : 8),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      stat['value'] as String,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: isCompact ? 18 : 22,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                SizedBox(height: isCompact ? 2 : 4),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      stat['title'] as String,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                            fontWeight: FontWeight.w600,
                                            fontSize: isCompact ? 11 : 13,
                                          ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Charts header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.secondary,
                              Theme.of(
                                context,
                              ).colorScheme.secondary.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.secondary.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.analytics_rounded,
                          size: 24,
                          color: Theme.of(context).colorScheme.onSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Analytics & Insights',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh dashboard widgets',
                        onPressed: _extrasLoading
                            ? null
                            : () => _refreshAll(
                                showLoading: true,
                                includeStats: true,
                              ),
                        icon: _extrasLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Charts - Consistent layout for desktop monitors
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 1200;
                      final isNarrow = constraints.maxWidth < 900;
                      final chartHeight = isDesktop ? 450.0 : (isNarrow ? 760.0 : 420.0);

                      return SizedBox(
                        height: chartHeight,
                        child: isNarrow
                            ? Column(
                                children: [
                                  Expanded(
                                    child: _buildModernBarChart(context),
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(child: _buildPieChart(context)),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _buildModernBarChart(context),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    flex: 2,
                                    child: _buildPieChart(context),
                                  ),
                                ],
                              ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  if (_extrasError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Dashboard widgets failed to load: $_extrasError',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 1200;
                      final isNarrow = constraints.maxWidth < 900;
                      final alertsCard = _buildAlertsCard(context);
                      final activityCard = _buildActivityCard(context);

                      if (isNarrow) {
                        return Column(
                          children: [
                            alertsCard,
                            const SizedBox(height: 16),
                            activityCard,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: alertsCard),
                          SizedBox(width: isDesktop ? 24 : 16),
                          Expanded(child: activityCard),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertsCard(BuildContext context) {
    final alerts = _alerts;
    final kpis = (alerts?['kpis'] as Map?)?.cast<String, dynamic>() ?? {};

    return Card(
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notification_important_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Actionable Alerts',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildKpiChip(
                  context,
                  label: 'Utilization',
                  value:
                      '${(((kpis['utilization_rate'] ?? 0) as num) * 100).toStringAsFixed(1)}%',
                ),
                _buildKpiChip(
                  context,
                  label: 'Availability',
                  value:
                      '${(((kpis['availability_rate'] ?? 0) as num) * 100).toStringAsFixed(1)}%',
                ),
                _buildKpiChip(
                  context,
                  label: 'Avg checkout',
                  value: '${kpis['avg_checkout_duration_days'] ?? 0}d',
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (alerts == null && _extrasLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (alerts == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No alerts data yet.',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              )
            else
              Column(
                children: [
                  _buildIssueAlertSection(
                    context,
                    title: 'Overdue (> 7 days)',
                    icon: Icons.warning_rounded,
                    color: Colors.red,
                    section: alerts['overdue'],
                    actions: const ['remind', 'return'],
                  ),
                  _buildIssueAlertSection(
                    context,
                    title: 'Due today',
                    icon: Icons.today_rounded,
                    color: Colors.orange,
                    section: alerts['dueToday'],
                    actions: const ['remind', 'return'],
                  ),
                  _buildIssueAlertSection(
                    context,
                    title: 'Due tomorrow',
                    icon: Icons.event_rounded,
                    color: Colors.amber,
                    section: alerts['dueTomorrow'],
                    actions: const ['remind', 'return'],
                  ),
                  _buildLowStockSection(context, alerts['lowStock']),
                  _buildInactiveMembersSection(
                    context,
                    alerts['inactiveMembers'],
                  ),
                  _buildDeactivatedMembersSection(
                    context,
                    alerts['deactivatedMembers'],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context) {
    return Card(
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recent Activity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _extrasLoading ? null : _clearRecentActivity,
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_extrasLoading && _activity.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_activity.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No recent activity.',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              )
            else
              Column(
                children: _activity.take(12).map((item) {
                  final icon = _activityIcon(item['type']?.toString() ?? '');
                  final occurredAt = item['occurred_at']?.toString() ?? '';
                  final occurredAtText = DateFormatter.formatDateTimeIndian(
                    occurredAt,
                  );
                  // Apply legacy Hindi conversion for any KrutiDev-encoded text.
                  // normalizeHindiForDisplay only converts if text looks like legacy Hindi.
                  final title = normalizeHindiForDisplay(
                    item['title']?.toString() ?? '',
                  );
                  final description = normalizeHindiForDisplay(
                    item['description']?.toString() ?? '',
                  );

                  final baseTitle =
                      Theme.of(context).textTheme.bodyMedium ??
                      const TextStyle();
                  final baseDesc =
                      Theme.of(context).textTheme.bodySmall ??
                      const TextStyle();

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            icon,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: hindiAwareTextStyle(
                                  context,
                                  text: title,
                                  base: baseTitle.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                description,
                                style: hindiAwareTextStyle(
                                  context,
                                  text: description,
                                  base: baseDesc.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                occurredAtText,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiChip(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'issue':
        return Icons.assignment_turned_in_rounded;
      case 'return':
        return Icons.assignment_return_rounded;
      case 'book_added':
        return Icons.library_add_rounded;
      case 'member_added':
        return Icons.person_add_alt_1_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Widget _buildIssueAlertSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required dynamic section,
    required List<String> actions,
  }) {
    final count = (section is Map ? section['count'] : 0) ?? 0;
    final items =
        (section is Map ? section['items'] : const []) as List? ?? const [];

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: InkWell(
        onTap: count > 0 ? () => _showAlertDetailsPopup(
          context,
          title: title,
          icon: icon,
          color: color,
          items: items,
          type: 'issue',
          actions: actions,
        ) : null,
        child: Icon(icon, color: color),
      ),
      title: InkWell(
        onTap: count > 0 ? () => _showAlertDetailsPopup(
          context,
          title: title,
          icon: icon,
          color: color,
          items: items,
          type: 'issue',
          actions: actions,
        ) : null,
        child: Row(
          children: [
            Expanded(child: Text('$title ($count)')),
            if (count > 5)
              TextButton(
                onPressed: () => _showAlertDetailsPopup(
                  context,
                  title: title,
                  icon: icon,
                  color: color,
                  items: items,
                  type: 'issue',
                  actions: actions,
                ),
                child: Text('View All $count'),
              ),
          ],
        ),
      ),
      children: items.take(5).map((raw) {
        final item = (raw as Map).cast<String, dynamic>();
        final issueId = item['id'] ?? 0;
        final memberName = item['member_name']?.toString() ?? '';
        final bookTitle = item['title']?.toString() ?? '';
        final dueDate = item['due_date']?.toString() ?? '';
        final daysOverdue = item['days_overdue']?.toString() ?? '';
        final dueDateText = DateFormatter.formatDateIndian(dueDate);

        return InkWell(
          onTap: () => _showSingleAlertPopup(
            context,
            item: item,
            type: 'issue',
            color: color,
            actions: actions,
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('Member: $memberName'),
                Text(
                  'Due: ${dueDateText.isEmpty ? '-' : dueDateText}${daysOverdue.isNotEmpty ? ' • Overdue: $daysOverdue d' : ''}',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (actions.contains('remind'))
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _runAction(
                            context,
                            () => ApiService.remindIssue(issueId),
                            successMessage: 'Reminder logged',
                          );
                        },
                        icon: const Icon(
                          Icons.mark_email_unread_rounded,
                          size: 18,
                        ),
                        label: const Text('Remind'),
                      ),
                    if (actions.contains('return'))
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _runAction(context, () async {
                            await context.read<IssueProvider>().returnBook(
                              issueId,
                            );
                          }, successMessage: 'Marked returned');
                          await _refreshAll(
                            showLoading: false,
                            includeStats: true,
                          );
                        },
                        icon: const Icon(
                          Icons.assignment_return_rounded,
                          size: 18,
                        ),
                        label: const Text('Returned'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showAlertDetailsPopup(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List items,
    required String type,
    List<String> actions = const [],
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.height * 0.6,
          child: items.isEmpty
              ? const Center(child: Text('No items'))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final raw = items[index];
                    final item = (raw as Map).cast<String, dynamic>();
                    return _buildAlertPopupItem(dialogContext, item, type, color, actions);
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAllLowStockPopup(BuildContext context, int totalCount) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading all low stock books...'),
          ],
        ),
      ),
    );

    try {
      // Fetch all low stock items with a high limit
      final alerts = await ApiService.getDashboardAlerts(
        limit: 10000, // Fetch all
        lowStockThreshold: 1,
      );
      
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      
      final lowStock = alerts['lowStock'];
      final items = (lowStock is Map ? lowStock['items'] : const []) as List? ?? const [];
      
      _showAlertDetailsPopup(
        context,
        title: 'Low Stock Books ($totalCount)',
        icon: Icons.inventory_2_rounded,
        color: Colors.blueGrey,
        items: items,
        type: 'lowstock',
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getOperationErrorMessage('Load low stock', e))),
      );
    }
  }

  void _showSingleAlertPopup(
    BuildContext context, {
    required Map<String, dynamic> item,
    required String type,
    required Color color,
    List<String> actions = const [],
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: color),
            const SizedBox(width: 12),
            const Expanded(child: Text('Alert Details')),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: _buildDetailedAlertContent(dialogContext, item, type, color, actions),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertPopupItem(
    BuildContext context,
    Map<String, dynamic> item,
    String type,
    Color color,
    List<String> actions,
  ) {
    if (type == 'issue') {
      final issueId = item['id'] ?? 0;
      final memberName = item['member_name']?.toString() ?? '';
      final bookTitle = item['title']?.toString() ?? '';
      final dueDate = item['due_date']?.toString() ?? '';
      final daysOverdue = item['days_overdue']?.toString() ?? '';
      final dueDateText = DateFormatter.formatDateIndian(dueDate);

      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bookTitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Member: $memberName')),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 4),
                  Text('Due: ${dueDateText.isEmpty ? '-' : dueDateText}'),
                  if (daysOverdue.isNotEmpty && daysOverdue != '0') ...[
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Overdue: $daysOverdue days',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (actions.contains('remind'))
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _runAction(
                          context,
                          () => ApiService.remindIssue(issueId),
                          successMessage: 'Reminder logged',
                        );
                      },
                      icon: const Icon(Icons.mark_email_unread_rounded, size: 16),
                      label: const Text('Remind'),
                    ),
                  if (actions.contains('return'))
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _runAction(context, () async {
                          await this.context.read<IssueProvider>().returnBook(issueId);
                        }, successMessage: 'Marked returned');
                        await _refreshAll(showLoading: false, includeStats: true);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.assignment_return_rounded, size: 16),
                      label: const Text('Return'),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    
    // Generic item display
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(item['title']?.toString() ?? item['name']?.toString() ?? 'Unknown'),
        subtitle: Text(item.entries
            .where((e) => e.key != 'id' && e.key != 'title' && e.key != 'name')
            .map((e) => '${e.key}: ${e.value}')
            .take(3)
            .join(', ')),
      ),
    );
  }

  Widget _buildDetailedAlertContent(
    BuildContext context,
    Map<String, dynamic> item,
    String type,
    Color color,
    List<String> actions,
  ) {
    final entries = item.entries.where((e) => e.key != 'id').toList();
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    _formatKey(e.key),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatValue(e.key, e.value),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          )),
          if (type == 'issue' && actions.isNotEmpty) ...[
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              children: [
                if (actions.contains('remind'))
                  OutlinedButton.icon(
                    onPressed: () async {
                      final issueId = item['id'] ?? 0;
                      await _runAction(
                        this.context,
                        () => ApiService.remindIssue(issueId),
                        successMessage: 'Reminder logged',
                      );
                    },
                    icon: const Icon(Icons.mark_email_unread_rounded, size: 16),
                    label: const Text('Send Reminder'),
                  ),
                if (actions.contains('return'))
                  ElevatedButton.icon(
                    onPressed: () async {
                      final issueId = item['id'] ?? 0;
                      await _runAction(this.context, () async {
                        await this.context.read<IssueProvider>().returnBook(issueId);
                      }, successMessage: 'Marked returned');
                      await _refreshAll(showLoading: false, includeStats: true);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.assignment_return_rounded, size: 16),
                    label: const Text('Mark Returned'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  String _formatValue(String key, dynamic value) {
    if (value == null) return '-';
    if (key.contains('date')) {
      return DateFormatter.formatDateIndian(value.toString());
    }
    return value.toString();
  }

  Widget _buildLowStockSection(BuildContext context, dynamic section) {
    final count = (section is Map ? section['count'] : 0) ?? 0;
    final items =
        (section is Map ? section['items'] : const []) as List? ?? const [];

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: InkWell(
        onTap: count > 0 ? () => _showAlertDetailsPopup(
          context,
          title: 'Low Stock Books',
          icon: Icons.inventory_2_rounded,
          color: Colors.blueGrey,
          items: items,
          type: 'lowstock',
        ) : null,
        child: const Icon(Icons.inventory_2_rounded, color: Colors.blueGrey),
      ),
      title: InkWell(
        onTap: count > 0 ? () => _showAlertDetailsPopup(
          context,
          title: 'Low Stock Books',
          icon: Icons.inventory_2_rounded,
          color: Colors.blueGrey,
          items: items,
          type: 'lowstock',
        ) : null,
        child: Row(
          children: [
            Expanded(child: Text('Low stock ($count)')),
            if (count > 5)
              TextButton(
                onPressed: () => _showAllLowStockPopup(context, count),
                child: Text('View All $count'),
              ),
          ],
        ),
      ),
      children: items.take(5).map((raw) {
        final item = (raw as Map).cast<String, dynamic>();
        final title = item['title']?.toString() ?? '';
        final available = item['available_copies']?.toString() ?? '0';
        final total = item['total_copies']?.toString() ?? '0';

        return InkWell(
          onTap: () => _showSingleAlertPopup(
            context,
            item: item,
            type: 'lowstock',
            color: Colors.blueGrey,
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(title),
            subtitle: Text('Available: $available / $total'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$available left',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInactiveMembersSection(BuildContext context, dynamic section) {
    final count = (section is Map ? section['count'] : 0) ?? 0;
    final items =
        (section is Map ? section['items'] : const []) as List? ?? const [];

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: InkWell(
        onTap: count > 0 ? () => _showAlertDetailsPopup(
          context,
          title: 'Inactive Members',
          icon: Icons.person_off_rounded,
          color: Colors.deepPurple,
          items: items,
          type: 'inactive_member',
        ) : null,
        child: const Icon(Icons.person_off_rounded, color: Colors.deepPurple),
      ),
      title: InkWell(
        onTap: count > 0 ? () => _showAlertDetailsPopup(
          context,
          title: 'Inactive Members',
          icon: Icons.person_off_rounded,
          color: Colors.deepPurple,
          items: items,
          type: 'inactive_member',
        ) : null,
        child: Row(
          children: [
            Expanded(child: Text('No recent activity ($count)')),
            if (count > 5)
              TextButton(
                onPressed: () => _showAlertDetailsPopup(
                  context,
                  title: 'Inactive Members',
                  icon: Icons.person_off_rounded,
                  color: Colors.deepPurple,
                  items: items,
                  type: 'inactive_member',
                ),
                child: Text('View All $count'),
              ),
          ],
        ),
      ),
      children: items.take(5).map((raw) {
        final item = (raw as Map).cast<String, dynamic>();
        final memberId = item['id'] ?? 0;
        final name = item['name']?.toString() ?? '';
        final email = item['email']?.toString() ?? '';
        final last = item['last_issue_date']?.toString();
        final lastText = DateFormatter.formatDateTimeIndian(last);

        return InkWell(
          onTap: () => _showSingleAlertPopup(
            context,
            item: item,
            type: 'inactive_member',
            color: Colors.deepPurple,
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(name),
            subtitle: Text(
              '${email.isNotEmpty ? email : 'No email'}${last != null ? ' • Last activity: ${lastText.isEmpty ? last : lastText}' : ''}',
            ),
            trailing: OutlinedButton(
              onPressed: () async {
                await _runAction(
                  context,
                  () => ApiService.deactivateMember(memberId),
                  successMessage: 'Member deactivated',
                );
                await _refreshAll(showLoading: false, includeStats: true);
              },
              child: const Text('Deactivate'),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDeactivatedMembersSection(
    BuildContext context,
    dynamic section,
  ) {
    final count = (section is Map ? section['count'] : 0) ?? 0;
    final items =
        (section is Map ? section['items'] : const []) as List? ?? const [];

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: InkWell(
        onTap: count > 0 ? () => _showAlertDetailsPopup(
          context,
          title: 'Deactivated Accounts',
          icon: Icons.block_rounded,
          color: Colors.redAccent,
          items: items,
          type: 'deactivated_member',
        ) : null,
        child: const Icon(Icons.block_rounded, color: Colors.redAccent),
      ),
      title: InkWell(
        onTap: count > 0 ? () => _showAlertDetailsPopup(
          context,
          title: 'Deactivated Accounts',
          icon: Icons.block_rounded,
          color: Colors.redAccent,
          items: items,
          type: 'deactivated_member',
        ) : null,
        child: Row(
          children: [
            Expanded(child: Text('Deactivated accounts ($count)')),
            if (count > 5)
              TextButton(
                onPressed: () => _showAlertDetailsPopup(
                  context,
                  title: 'Deactivated Accounts',
                  icon: Icons.block_rounded,
                  color: Colors.redAccent,
                  items: items,
                  type: 'deactivated_member',
                ),
                child: Text('View All $count'),
              ),
          ],
        ),
      ),
      children: items.take(5).map((raw) {
        final item = (raw as Map).cast<String, dynamic>();
        final memberId = item['id'] ?? 0;
        final name = item['name']?.toString() ?? '';
        final email = item['email']?.toString() ?? '';

        return InkWell(
          onTap: () => _showSingleAlertPopup(
            context,
            item: item,
            type: 'deactivated_member',
            color: Colors.redAccent,
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(name),
            subtitle: Text(email.isNotEmpty ? email : 'No email'),
            trailing: ElevatedButton(
              onPressed: () async {
                await _runAction(
                  context,
                  () => ApiService.activateMember(memberId),
                  successMessage: 'Member activated',
                );
                await _refreshAll(showLoading: false, includeStats: true);
              },
              child: const Text('Activate'),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(getOperationErrorMessage('Action', e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildModernBarChart(BuildContext context) {
    final statsProvider = Provider.of<IssueProvider>(context);

    // Generate dynamic data based on actual stats
    final data = [
      statsProvider.stats['total_books'] ?? 0,
      statsProvider.stats['issued_books'] ?? 0,
      statsProvider.stats['available_books'] ?? 0,
      statsProvider.stats['overdue_books'] ?? 0,
      statsProvider.stats['active_members'] ?? 0,
    ];

    final maxY = data.reduce((a, b) => a > b ? a : b).toDouble();
    final adjustedMaxY = maxY == 0 ? 10.0 : (maxY * 1.2).ceilToDouble();

    return Card(
      elevation: 12,
      shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Library Statistics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceEvenly,
                      maxY: adjustedMaxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBgColor: Theme.of(context).colorScheme.surface,
                          tooltipBorder: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                            width: 1,
                          ),
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final labels = [
                              'Total Books',
                              'Issued Books',
                              'Available Books',
                              'Overdue Books',
                              'Active Members',
                            ];
                            return BarTooltipItem(
                              '${labels[groupIndex]}\n${rod.toY.toInt()}',
                              TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
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
                              const labels = [
                                'Books',
                                'Issued',
                                'Avail',
                                'Overdue',
                                'Members',
                              ];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  labels[value.toInt()],
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
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
                        horizontalInterval: (adjustedMaxY / 5).clamp(
                          1.0,
                          double.infinity,
                        ),
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.2),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(
                        data.length,
                        (index) => BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: data[index].toDouble(),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.8),
                                  Theme.of(context).colorScheme.primary,
                                ],
                              ),
                              width: 32,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(6),
                                topRight: Radius.circular(6),
                              ),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: adjustedMaxY,
                                color: Theme.of(
                                  context,
                                ).colorScheme.surface.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPieChart(BuildContext context) {
    final statsProvider = Provider.of<IssueProvider>(context);

    final totalBooks = statsProvider.stats['total_books'] ?? 0;
    final issuedBooks = statsProvider.stats['issued_books'] ?? 0;
    final availableBooks = statsProvider.stats['available_books'] ?? 0;

    if (totalBooks == 0) {
      return Card(
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              ],
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pie_chart_rounded,
                  size: 64,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No data available',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Calculate percentage based on issued + available only
    final pieTotal = (issuedBooks + availableBooks).toDouble();
    final issuedPercentage = pieTotal > 0
        ? ((issuedBooks / pieTotal) * 100)
        : 0.0;
    final availablePercentage = pieTotal > 0
        ? ((availableBooks / pieTotal) * 100)
        : 0.0;

    // Format percentage - show more decimal places for very small values
    String formatPercentage(double pct) {
      if (pct == 0) return '0%';
      if (pct < 0.1) return '${pct.toStringAsFixed(2)}%';
      if (pct < 1) return '${pct.toStringAsFixed(1)}%';
      return '${pct.toStringAsFixed(1)}%';
    }

    // For small segments, show label outside with theme-aware color
    final isSmallIssued = issuedPercentage < 5;
    final isSmallAvailable = availablePercentage < 5;
    
    final sections = [
      PieChartSectionData(
        value: issuedBooks.toDouble(),
        title: formatPercentage(issuedPercentage),
        color: Theme.of(context).colorScheme.secondary,
        radius: isSmallIssued ? 95 : 80,
        titleStyle: TextStyle(
          fontSize: isSmallIssued ? 11 : 12,
          fontWeight: FontWeight.bold,
          color: isSmallIssued 
              ? Theme.of(context).colorScheme.onSurface
              : Colors.white,
        ),
        titlePositionPercentageOffset: isSmallIssued ? 1.6 : 0.6,
      ),
      PieChartSectionData(
        value: availableBooks.toDouble(),
        title: formatPercentage(availablePercentage),
        color: Theme.of(context).colorScheme.primary,
        radius: isSmallAvailable ? 95 : 80,
        titleStyle: TextStyle(
          fontSize: isSmallAvailable ? 11 : 12,
          fontWeight: FontWeight.bold,
          color: isSmallAvailable 
              ? Theme.of(context).colorScheme.onSurface
              : Colors.white,
        ),
        titlePositionPercentageOffset: isSmallAvailable ? 1.6 : 0.6,
      ),
    ];

    return Card(
      elevation: 12,
      shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book Status Distribution',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      pieTouchData: PieTouchData(
                        enabled: true,
                        touchCallback: (event, response) {
                          // Handle touch events if needed
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem(
                      context,
                      'Issued',
                      Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 24),
                    _buildLegendItem(
                      context,
                      'Available',
                      Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
