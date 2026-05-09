import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;
import '../providers/issue_provider.dart';
import '../services/api_service.dart';
import '../utils/date_formatter.dart';
import '../utils/hindi_text.dart';
import '../utils/error_utils.dart';
import 'common_widgets.dart';

enum DashboardDensityMode { compact, detailed }

enum DashboardAlertFilter { all, circulation, inventory, members }

enum DashboardActivityFilter { all, circulation, inventory, members }

enum DashboardViewPreset { balanced, operations, inventory, memberCare }

class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _floatController;

  Timer? _refreshTimer;
  Timer? _statsRefreshTimer;
  StreamSubscription<void>? _dataChangedSub;
  bool _refreshInFlight = false;
  bool _refreshQueued = false;
  static const int _lowStockPopupPageSize = 25;

  bool _extrasLoading = false;
  String? _extrasError;
  Map<String, dynamic>? _alerts;
  List<Map<String, dynamic>> _activity = [];
  DateTime? _lastUpdatedAt;
  DashboardAlertFilter _alertFilter = DashboardAlertFilter.all;
  DashboardActivityFilter _activityFilter = DashboardActivityFilter.all;
  DashboardViewPreset _viewPreset = DashboardViewPreset.balanced;
  int _activityPage = 1;
  late final ScrollController _alertsScrollController;

  static const String _prefAlertFilter = 'dashboard_alert_filter';
  static const String _prefActivityFilter = 'dashboard_activity_filter';
  static const String _prefViewPreset = 'dashboard_view_preset';

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
    _loadDashboardUxPreferences();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _floatController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();
    _alertsScrollController = ScrollController();

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

  Future<void> _loadDashboardUxPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final storedAlertFilter = prefs.getString(_prefAlertFilter);
    final storedActivityFilter = prefs.getString(_prefActivityFilter);
    final storedPreset = prefs.getString(_prefViewPreset);

    setState(() {
      _alertFilter = DashboardAlertFilter.values.firstWhere(
        (e) => e.name == storedAlertFilter,
        orElse: () => DashboardAlertFilter.all,
      );
      _activityFilter = DashboardActivityFilter.values.firstWhere(
        (e) => e.name == storedActivityFilter,
        orElse: () => DashboardActivityFilter.all,
      );
      _viewPreset = DashboardViewPreset.values.firstWhere(
        (e) => e.name == storedPreset,
        orElse: () => DashboardViewPreset.balanced,
      );
    });
  }

  Future<void> _persistDashboardUxPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefAlertFilter, _alertFilter.name);
    await prefs.setString(_prefActivityFilter, _activityFilter.name);
    await prefs.setString(_prefViewPreset, _viewPreset.name);
  }

  DashboardDensityMode _resolveDensityMode(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 900) {
      return DashboardDensityMode.compact;
    }

    final alertCount = _totalAlertCount();
    final activityCount = _activity.length;
    final totalSignals = alertCount + activityCount;

    if (totalSignals > 16) {
      return DashboardDensityMode.compact;
    }

    return DashboardDensityMode.detailed;
  }

  int _totalAlertCount() {
    final alerts = _alerts;
    if (alerts == null) return 0;

    var total = 0;
    for (final entry in alerts.values) {
      if (entry is Map && entry['count'] is num) {
        total += (entry['count'] as num).toInt();
      }
    }
    return total;
  }

  int _previewItemLimitFor(DashboardDensityMode mode) {
    return mode == DashboardDensityMode.compact ? 3 : 5;
  }

  int _activityPreviewCountFor(DashboardDensityMode mode) {
    return mode == DashboardDensityMode.compact ? 8 : 12;
  }

  int _activitySkeletonRowsFor(DashboardDensityMode mode) {
    return mode == DashboardDensityMode.compact ? 6 : 8;
  }

  double _secondaryCardHeightFor(double width) {
    if (width >= 1200) return 560;
    if (width >= 900) return 540;
    if (width >= 600) return 520;
    return 500;
  }

  int _pageCountFor(int total, int pageSize) {
    if (total <= 0) return 1;
    return ((total + pageSize - 1) / pageSize).ceil();
  }

  void _setActivityPage(int page, int totalPages) {
    final next = page.clamp(1, totalPages);
    if (next == _activityPage) return;
    setState(() => _activityPage = next);
  }

  bool _showAlertSection(String sectionKey) {
    if (_alertFilter == DashboardAlertFilter.all) return true;
    const circulationKeys = {'overdue', 'dueToday', 'dueTomorrow'};
    const inventoryKeys = {'lowStock'};
    const memberKeys = {'inactiveMembers', 'deactivatedMembers'};

    switch (_alertFilter) {
      case DashboardAlertFilter.circulation:
        return circulationKeys.contains(sectionKey);
      case DashboardAlertFilter.inventory:
        return inventoryKeys.contains(sectionKey);
      case DashboardAlertFilter.members:
        return memberKeys.contains(sectionKey);
      case DashboardAlertFilter.all:
        return true;
    }
  }

  bool _showActivityItem(String type) {
    if (_activityFilter == DashboardActivityFilter.all) return true;

    switch (_activityFilter) {
      case DashboardActivityFilter.circulation:
        return type == 'issue' || type == 'return';
      case DashboardActivityFilter.inventory:
        return type == 'book_added';
      case DashboardActivityFilter.members:
        return type == 'member_added';
      case DashboardActivityFilter.all:
        return true;
    }
  }

  List<Map<String, dynamic>> _normalizeAlertItems(dynamic section) {
    final rawItems = section is Map ? section['items'] : null;
    if (rawItems is List) {
      return rawItems
          .whereType<Map>()
          .map((raw) => raw.cast<String, dynamic>())
          .toList();
    }
    if (rawItems is Map) {
      return [rawItems.cast<String, dynamic>()];
    }
    return const [];
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
        _lastUpdatedAt = DateTime.now();
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
    _floatController.dispose();
    _alertsScrollController.dispose();
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentPadding = constraints.maxWidth < 600 ? 12.0 : (constraints.maxWidth < 900 ? 16.0 : 24.0);
              return Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _buildDashboardBackground(context),
                    ),
                  ),
                  SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(contentPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: _buildDashboardHero(context),
                          ),
                          const SizedBox(height: 18),
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
                          final title = stat['title'] as String;
                          final value = stat['value'] as String;
                          final entryAnimation = CurvedAnimation(
                            parent: _animationController,
                            curve: Interval(
                              0.12 + (index * 0.08),
                              1,
                              curve: Curves.easeOutCubic,
                            ),
                          );

                          return FadeTransition(
                            opacity: entryAnimation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.08),
                                end: Offset.zero,
                              ).animate(entryAnimation),
                              child: Semantics(
                                container: true,
                                label: '$title: $value',
                                child: Container(
                                  width: cardWidth,
                                  height: cardHeight,
                                  padding: EdgeInsets.all(isCompact ? 10 : 14),
                                  decoration: BoxDecoration(
                                    gradient:
                                        stat['gradient'] as LinearGradient,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.18,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (stat['gradient']
                                                as LinearGradient)
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
                                          child: AnimatedCounter(
                                            value: int.tryParse(value) ?? 0,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize:
                                                      isCompact ? 18 : 22,
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
                                            title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Colors.white
                                                      .withValues(
                                                        alpha: 0.9,
                                                      ),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize:
                                                      isCompact ? 11 : 13,
                                                ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
                      final cardHeight = _secondaryCardHeightFor(
                        constraints.maxWidth,
                      );
                      final alertsCard = SizedBox(
                        height: cardHeight,
                        child: _buildAlertsCard(context),
                      );
                      final activityCard = SizedBox(
                        height: cardHeight,
                        child: _buildActivityCard(context),
                      );

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
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatLastUpdated(BuildContext context) {
    final updatedAt = _lastUpdatedAt;
    if (updatedAt == null) {
      return 'Awaiting first sync';
    }
    final timeOfDay = TimeOfDay.fromDateTime(updatedAt);
    final timeLabel = MaterialLocalizations.of(context).formatTimeOfDay(
      timeOfDay,
    );
    return 'Updated $timeLabel';
  }

  Widget _buildDashboardBackground(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final t = _floatController.value;
        final drift = 14 * math.sin(2 * math.pi * t);
        final glow = 0.08 + 0.04 * math.sin(2 * math.pi * t);

        return Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.surface,
                    cs.primary.withValues(alpha: glow),
                    cs.secondary.withValues(alpha: glow * 1.2),
                  ],
                  stops: const [0.2, 0.6, 1.0],
                ),
              ),
              child: const SizedBox.expand(),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _DotGridPainter(
                  color: cs.primary.withValues(alpha: 0.03),
                  spacing: 26,
                  radius: 1.1,
                ),
              ),
            ),
            Positioned(
              top: -140 + drift,
              right: -120,
              child: _AmbientOrb(
                size: 260,
                colors: [
                  cs.primary.withValues(alpha: 0.24),
                  cs.secondary.withValues(alpha: 0.12),
                ],
              ),
            ),
            Positioned(
              bottom: -180,
              left: -140 + drift,
              child: _AmbientOrb(
                size: 320,
                colors: [
                  cs.secondary.withValues(alpha: 0.2),
                  cs.tertiary.withValues(alpha: 0.14),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeroChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardHero(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateText =
        MaterialLocalizations.of(context).formatFullDate(DateTime.now());
    final statusText = _extrasLoading
        ? 'Refreshing data...'
        : _formatLastUpdated(context);
    final statusIcon =
        _extrasLoading ? Icons.sync_rounded : Icons.cloud_done_rounded;

    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final t = _floatController.value;
        final drift = 10 * math.sin(2 * math.pi * t);
        final glow = 0.16 + 0.04 * math.sin(2 * math.pi * t);

        return Material(
          elevation: 10,
          shadowColor: cs.primary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: glow),
                  cs.secondary.withValues(alpha: glow * 0.9),
                  cs.tertiary.withValues(alpha: glow * 0.75),
                ],
                stops: const [0.05, 0.55, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border:
                  Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          cs.onSurface.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                        center: Alignment.topLeft,
                        radius: 1.2,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -60,
                  top: -60 + drift,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primary.withValues(alpha: 0.14),
                    ),
                  ),
                ),
                Positioned(
                  left: -40 + drift,
                  bottom: -60,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.secondary.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Positioned(
                  right: 40,
                  bottom: -30 - drift,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.tertiary.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 760;
                      final titleStyle = Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          );
                      final subtitleStyle =
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.8),
                                height: 1.4,
                              );
                      final chipRow = Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildHeroChip(
                            context,
                            icon: Icons.calendar_today_rounded,
                            label: dateText,
                          ),
                          _buildHeroChip(
                            context,
                            icon: statusIcon,
                            label: statusText,
                          ),
                          _buildHeroChip(
                            context,
                            icon: Icons.bolt_rounded,
                            label: 'Auto-refresh every 10s',
                          ),
                        ],
                      );
                      final refreshButton = FilledButton.icon(
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
                        label: Text(
                          _extrasLoading ? 'Refreshing' : 'Refresh data',
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      );

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Library overview', style: titleStyle),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Monitor circulation, inventory, and member health in one place.',
                                    style: subtitleStyle,
                                  ),
                                  const SizedBox(height: 12),
                                  chipRow,
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 180),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: SizedBox(
                                  width: 180,
                                  child: refreshButton,
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Library overview', style: titleStyle),
                          const SizedBox(height: 6),
                          Text(
                            'Monitor circulation, inventory, and member health in one place.',
                            style: subtitleStyle,
                          ),
                          const SizedBox(height: 12),
                          chipRow,
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: refreshButton,
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
      },
    );
  }

  Widget _buildAlertsCard(BuildContext context) {
    final alerts = _alerts;
    final kpis = (alerts?['kpis'] as Map?)?.cast<String, dynamic>() ?? {};
    final densityMode = _resolveDensityMode(context);
    final densityLabel = densityMode == DashboardDensityMode.compact
        ? 'compact'
        : 'detailed';
    final sections = <Widget>[];
    if (alerts != null) {
      if (_showAlertSection('overdue')) {
        sections.add(
          _buildIssueAlertSection(
            context,
            title: 'Overdue (> 7 days)',
            icon: Icons.warning_rounded,
            color: Colors.red,
            section: alerts['overdue'],
            actions: const ['remind', 'return'],
          ),
        );
      }
      if (_showAlertSection('dueToday')) {
        sections.add(
          _buildIssueAlertSection(
            context,
            title: 'Due today',
            icon: Icons.today_rounded,
            color: Colors.orange,
            section: alerts['dueToday'],
            actions: const ['remind', 'return'],
          ),
        );
      }
      if (_showAlertSection('dueTomorrow')) {
        sections.add(
          _buildIssueAlertSection(
            context,
            title: 'Due tomorrow',
            icon: Icons.event_rounded,
            color: Colors.amber,
            section: alerts['dueTomorrow'],
            actions: const ['remind', 'return'],
          ),
        );
      }
      if (_showAlertSection('lowStock')) {
        sections.add(_buildLowStockSection(context, alerts['lowStock']));
      }
      if (_showAlertSection('inactiveMembers')) {
        sections.add(
          _buildInactiveMembersSection(context, alerts['inactiveMembers']),
        );
      }
      if (_showAlertSection('deactivatedMembers')) {
        sections.add(
          _buildDeactivatedMembersSection(
            context,
            alerts['deactivatedMembers'],
          ),
        );
      }
    }
    return _buildFloatingCard(
      context,
      offsetSeed: 0.12,
      child: Card(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Actionable Alerts',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Filtered by ${_alertFilter.name} • $densityLabel layout',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
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

            Expanded(
              child: Builder(
                builder: (context) {
                  if (alerts == null && _extrasLoading) {
                    return _buildAlertsSkeleton(context);
                  }
                  if (alerts == null) {
                    return EmptyStateWidget(
                      icon: Icons.notifications_off_outlined,
                      title: 'No alerts available yet',
                      subtitle:
                          'Alerts will appear here when circulation, inventory, or member actions need attention.',
                      actionLabel: 'Refresh alerts',
                      onAction: () => _refreshAll(
                        showLoading: true,
                        includeStats: false,
                      ),
                    );
                  }

                  if (sections.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.filter_alt_off_rounded,
                      title: 'No alert sections match this filter',
                      subtitle:
                          'Try switching the alert filter or choose a saved view to see more data.',
                      actionLabel: 'Show all alerts',
                      onAction: () {
                        setState(() {
                          _alertFilter = DashboardAlertFilter.all;
                          _viewPreset = DashboardViewPreset.balanced;
                        });
                        unawaited(_persistDashboardUxPreferences());
                      },
                    );
                  }

                  return Scrollbar(
                    controller: _alertsScrollController,
                    thumbVisibility: true,
                    child: ListView.separated(
                      controller: _alertsScrollController,
                      itemCount: sections.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) => sections[index],
                    ),
                  );
                },
              ),
            ),
            if (sections.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildAlertsScrollControls(context),
            ],
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context) {
    final densityMode = _resolveDensityMode(context);
    final filteredActivity = _activity.where((item) {
      final type = item['type']?.toString() ?? '';
      return _showActivityItem(type);
    }).toList();
    final activityPageSize = _activityPreviewCountFor(densityMode);
    final totalPages = _pageCountFor(filteredActivity.length, activityPageSize);
    final currentPage = _activityPage.clamp(1, totalPages);
    final start = (currentPage - 1) * activityPageSize;
    final end = math.min(start + activityPageSize, filteredActivity.length);
    final pagedActivity = start < end
        ? filteredActivity.sublist(start, end)
        : const <Map<String, dynamic>>[];

    return _buildFloatingCard(
      context,
      offsetSeed: 0.32,
      child: Card(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Activity',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Filtered by ${_activityFilter.name}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _extrasLoading ? null : _clearRecentActivity,
                    icon: const Icon(Icons.clear_all_rounded, size: 18),
                    label: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<DashboardActivityFilter>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment<DashboardActivityFilter>(
                    value: DashboardActivityFilter.all,
                    label: Text('All'),
                  ),
                  ButtonSegment<DashboardActivityFilter>(
                    value: DashboardActivityFilter.circulation,
                    label: Text('Borrowed'),
                  ),
                  ButtonSegment<DashboardActivityFilter>(
                    value: DashboardActivityFilter.inventory,
                    label: Text('Inventory'),
                  ),
                  ButtonSegment<DashboardActivityFilter>(
                    value: DashboardActivityFilter.members,
                    label: Text('Members'),
                  ),
                ],
                selected: {_activityFilter},
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) return;
                  setState(() {
                    _activityFilter = selection.first;
                    _viewPreset = DashboardViewPreset.balanced;
                    _activityPage = 1;
                  });
                  unawaited(_persistDashboardUxPreferences());
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (_extrasLoading && filteredActivity.isEmpty) {
                      return _buildActivitySkeleton(context);
                    }
                    if (filteredActivity.isEmpty) {
                      return EmptyStateWidget(
                        icon: Icons.history_toggle_off_rounded,
                        title: 'No activity for this filter',
                        subtitle:
                            'Try selecting a different filter or keep working and new activity will appear automatically.',
                        actionLabel: 'Show all activity',
                        onAction: () {
                          setState(() {
                            _activityFilter = DashboardActivityFilter.all;
                            _viewPreset = DashboardViewPreset.balanced;
                            _activityPage = 1;
                          });
                          unawaited(_persistDashboardUxPreferences());
                        },
                      );
                    }

                    return ListView.builder(
                      itemCount: pagedActivity.length,
                      itemBuilder: (context, index) {
                        final item = pagedActivity[index];
                        final icon =
                            _activityIcon(item['type']?.toString() ?? '');
                        final occurredAt =
                            item['occurred_at']?.toString() ?? '';
                        final occurredAtText =
                            DateFormatter.formatDateTimeIndian(occurredAt);
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
                                    Tooltip(
                                      message: occurredAtText,
                                      child: Text(
                                        formatRelativeTime(occurredAt),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (filteredActivity.isNotEmpty && totalPages > 1) ...[
                const SizedBox(height: 10),
                _buildPaginationControls(
                  context,
                  currentPage: currentPage,
                  totalPages: totalPages,
                  onPrevious: () =>
                      _setActivityPage(currentPage - 1, totalPages),
                  onNext: () =>
                      _setActivityPage(currentPage + 1, totalPages),
                ),
              ],
            ],
          ),
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

  Widget _buildFloatingCard(
    BuildContext context, {
    required Widget child,
    double offsetSeed = 0,
  }) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, _) {
        final t = _floatController.value;
        final lift = 4 * math.sin(2 * math.pi * (t + offsetSeed));
        return Transform.translate(
          offset: Offset(0, -lift),
          child: child,
        );
      },
    );
  }

  Widget _buildPaginationControls(
    BuildContext context, {
    required int currentPage,
    required int totalPages,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          'Page $currentPage of $totalPages',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: currentPage > 1 ? onPrevious : null,
          icon: const Icon(Icons.chevron_left_rounded, size: 18),
          label: const Text('Prev'),
          style: TextButton.styleFrom(shape: const StadiumBorder()),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: currentPage < totalPages ? onNext : null,
          icon: const Icon(Icons.chevron_right_rounded, size: 18),
          label: const Text('Next'),
          style: TextButton.styleFrom(shape: const StadiumBorder()),
        ),
      ],
    );
  }

  void _scrollAlertsBy(double offset) {
    if (!_alertsScrollController.hasClients) return;
    final maxScroll = _alertsScrollController.position.maxScrollExtent;
    final next = (_alertsScrollController.offset + offset).clamp(0.0, maxScroll);
    _alertsScrollController.animateTo(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildAlertsScrollControls(BuildContext context) {
    return Row(
      children: [
        Text(
          'Scroll alerts',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Scroll up',
          onPressed: () => _scrollAlertsBy(-220),
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
        ),
        IconButton(
          tooltip: 'Scroll down',
          onPressed: () => _scrollAlertsBy(220),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ],
    );
  }

  Widget _buildAlertsSkeleton(BuildContext context) {
    final previewCount =
        _previewItemLimitFor(_resolveDensityMode(context));
    return ListView.separated(
      itemCount: previewCount,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              ShimmerBlock(width: 28, height: 28, borderRadius: 14),
              SizedBox(width: 10),
              Expanded(
                child: ShimmerBlock(width: double.infinity, height: 16),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivitySkeleton(BuildContext context) {
    final rows = _activitySkeletonRowsFor(_resolveDensityMode(context));
    return ListView.separated(
      itemCount: rows,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            ShimmerBlock(width: 34, height: 34, borderRadius: 10),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBlock(width: double.infinity, height: 14),
                  SizedBox(height: 6),
                  ShimmerBlock(width: double.infinity, height: 12),
                ],
              ),
            ),
          ],
        );
      },
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
    final items = _normalizeAlertItems(section);
    final previewLimit = _previewItemLimitFor(_resolveDensityMode(context));

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Row(
        children: [
          Expanded(child: Text('$title ($count)')),
          if (count > 0)
            TextButton(
              onPressed: () => _showAlertDetailsPopup(
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
      children: items.take(previewLimit).map((item) {
        final issueId = item['id'] ?? 0;
        final memberName = item['member_name']?.toString() ?? '';
        final bookTitle = item['title']?.toString() ?? '';
        final dueDate = item['due_date']?.toString() ?? '';
        final daysOverdue = item['days_overdue']?.toString() ?? '';
        final dueDateText = DateFormatter.formatDateIndian(dueDate);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showSingleAlertPopup(
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
          ),
        );
      }).toList(),
    );
  }

  void _showAlertDetailsPopup({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> items,
    required String type,
    List<String> actions = const [],
  }) {
    if (!mounted) return;
    final rootContext = context;
    Future.microtask(() {
      if (!mounted) return;
      showDialog(
        context: rootContext,
        useRootNavigator: true,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(child: Text(title)),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(dialogContext).size.width < 600
                  ? MediaQuery.of(dialogContext).size.width * 0.9
                  : MediaQuery.of(dialogContext).size.width * 0.7,
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.6,
            ),
            child: items.isEmpty
                ? const Center(child: Text('No items'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildAlertPopupItem(
                        dialogContext,
                        item,
                        type,
                        color,
                        actions,
                      );
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
    });
  }

  Future<void> _showAllLowStockPopup(BuildContext _, int totalCount) async {
    int currentPage = 1;
    int resolvedTotalCount = totalCount;
    int totalPages = totalCount > 0
        ? ((totalCount + _lowStockPopupPageSize - 1) ~/ _lowStockPopupPageSize)
        : 1;
    bool isLoading = true;
    String? loadError;
    List<Map<String, dynamic>> items = const [];
    bool hasLoadedInitialPage = false;

    Future<void> loadPage(StateSetter setDialogState, int targetPage) async {
      setDialogState(() {
        isLoading = true;
        loadError = null;
      });

      try {
        final alerts = await ApiService.getDashboardAlerts(
          limit: 10,
          lowStockThreshold: 1,
          lowStockPage: targetPage,
          lowStockLimit: _lowStockPopupPageSize,
        );

        final lowStock = alerts['lowStock'];
        final rawItems =
            (lowStock is Map ? lowStock['items'] : const []) as List? ?? const [];
        final mappedItems = rawItems
            .whereType<Map>()
            .map((raw) => raw.cast<String, dynamic>())
            .toList();

        final countValue = lowStock is Map ? lowStock['count'] : null;
        final normalizedCount =
            countValue is num ? countValue.toInt() : resolvedTotalCount;

        final paginationRaw = lowStock is Map ? lowStock['pagination'] : null;
        final pagination = paginationRaw is Map
            ? paginationRaw.cast<String, dynamic>()
            : const <String, dynamic>{};
        final responsePage = pagination['page'] is num
            ? (pagination['page'] as num).toInt()
            : targetPage;
        final responseLimit = pagination['limit'] is num
            ? (pagination['limit'] as num).toInt()
            : _lowStockPopupPageSize;
        final computedTotalPages = normalizedCount > 0
            ? ((normalizedCount + responseLimit - 1) ~/ responseLimit)
            : 1;
        final responseTotalPages = pagination['totalPages'] is num
            ? (pagination['totalPages'] as num).toInt()
            : computedTotalPages;

        if (!mounted) return;
        setDialogState(() {
          items = mappedItems;
          resolvedTotalCount = normalizedCount;
          currentPage = responsePage < 1 ? 1 : responsePage;
          totalPages = responseTotalPages < 1 ? 1 : responseTotalPages;
          isLoading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setDialogState(() {
          loadError = getOperationErrorMessage('Load low stock', e);
          isLoading = false;
        });
      }
    }

    final rootContext = context;
    await showDialog(
      context: rootContext,
      useRootNavigator: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          if (!hasLoadedInitialPage) {
            hasLoadedInitialPage = true;
            unawaited(loadPage(setDialogState, 1));
          }

          final dialogWidth = MediaQuery.of(dialogContext).size.width < 600
              ? MediaQuery.of(dialogContext).size.width * 0.92
              : MediaQuery.of(dialogContext).size.width * 0.72;
          final dialogHeight = MediaQuery.of(dialogContext).size.height * 0.65;

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.inventory_2_rounded, color: Colors.blueGrey),
                const SizedBox(width: 12),
                Expanded(child: Text('Low Stock Books ($resolvedTotalCount)')),
              ],
            ),
            content: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: Column(
                children: [
                  if (isLoading) const LinearProgressIndicator(),
                  if (isLoading) const SizedBox(height: 8),
                  Expanded(
                    child: loadError != null && items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(loadError!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: () async {
                                    await loadPage(setDialogState, currentPage);
                                  },
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : items.isEmpty
                        ? const Center(child: Text('No low stock books'))
                        : ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (itemContext, index) {
                              final item = items[index];
                              return _buildAlertPopupItem(
                                dialogContext,
                                item,
                                'lowstock',
                                Colors.blueGrey,
                                const [],
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Showing ${items.length} of $resolvedTotalCount',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            onPressed: (!isLoading && currentPage > 1)
                                ? () async {
                                    await loadPage(
                                      setDialogState,
                                      currentPage - 1,
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_left, size: 18),
                            label: const Text('Prev'),
                            style: TextButton.styleFrom(
                              shape: const StadiumBorder(),
                            ),
                          ),
                          Text('Page $currentPage of $totalPages'),
                          TextButton.icon(
                            onPressed: (!isLoading && currentPage < totalPages)
                                ? () async {
                                    await loadPage(
                                      setDialogState,
                                      currentPage + 1,
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_right, size: 18),
                            label: const Text('Next'),
                            style: TextButton.styleFrom(
                              shape: const StadiumBorder(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSingleAlertPopup({
    required Map<String, dynamic> item,
    required String type,
    required Color color,
    List<String> actions = const [],
  }) {
    if (!mounted) return;
    final rootContext = context;
    Future.microtask(() {
      if (!mounted) return;
      showDialog(
        context: rootContext,
        useRootNavigator: true,
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
            child: _buildDetailedAlertContent(
              dialogContext,
              item,
              type,
              color,
              actions,
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
    });
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
    final items = _normalizeAlertItems(section);
    final previewLimit = _previewItemLimitFor(_resolveDensityMode(context));

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const Icon(Icons.inventory_2_rounded, color: Colors.blueGrey),
      title: Row(
        children: [
          Expanded(child: Text('Low stock ($count)')),
          if (count > 0)
            TextButton(
              onPressed: () => _showAllLowStockPopup(context, count),
              child: Text('View All $count'),
            ),
        ],
      ),
      children: items.take(previewLimit).map((raw) {
        final item = (raw as Map).cast<String, dynamic>();
        final title = item['title']?.toString() ?? '';
        final available = item['available_copies']?.toString() ?? '0';
        final total = item['total_copies']?.toString() ?? '0';

        return ListTile(
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
          onTap: () => _showSingleAlertPopup(
            item: item,
            type: 'lowstock',
            color: Colors.blueGrey,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInactiveMembersSection(BuildContext context, dynamic section) {
    final count = (section is Map ? section['count'] : 0) ?? 0;
    final items = _normalizeAlertItems(section);
    final previewLimit = _previewItemLimitFor(_resolveDensityMode(context));

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const Icon(Icons.person_off_rounded, color: Colors.deepPurple),
      title: Row(
        children: [
          Expanded(child: Text('No recent activity ($count)')),
          if (count > 0)
            TextButton(
              onPressed: () => _showAlertDetailsPopup(
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
      children: items.take(previewLimit).map((raw) {
        final item = (raw as Map).cast<String, dynamic>();
        final memberId = item['id'] ?? 0;
        final name = item['name']?.toString() ?? '';
        final email = item['email']?.toString() ?? '';
        final last = item['last_issue_date']?.toString();
        final lastText = DateFormatter.formatDateTimeIndian(last);

        return ListTile(
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
          onTap: () => _showSingleAlertPopup(
            item: item,
            type: 'inactive_member',
            color: Colors.deepPurple,
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
    final items = _normalizeAlertItems(section);
    final previewLimit = _previewItemLimitFor(_resolveDensityMode(context));

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const Icon(Icons.block_rounded, color: Colors.redAccent),
      title: Row(
        children: [
          Expanded(child: Text('Deactivated accounts ($count)')),
          if (count > 0)
            TextButton(
              onPressed: () => _showAlertDetailsPopup(
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
      children: items.take(previewLimit).map((raw) {
        final item = (raw as Map).cast<String, dynamic>();
        final memberId = item['id'] ?? 0;
        final name = item['name']?.toString() ?? '';
        final email = item['email']?.toString() ?? '';

        return ListTile(
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
          onTap: () => _showSingleAlertPopup(
            item: item,
            type: 'deactivated_member',
            color: Colors.redAccent,
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
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

    return _buildFloatingCard(
      context,
      offsetSeed: 0.42,
      child: Card(
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
                          enabled: _enableChartTouch,
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBgColor:
                                Theme.of(context).colorScheme.surface,
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
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.2),
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
                                    Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.8),
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
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surface
                                      .withValues(alpha: 0.3),
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
      ),
    );
  }

  Widget _buildPieChart(BuildContext context) {
    final statsProvider = Provider.of<IssueProvider>(context);

    final totalBooks = statsProvider.stats['total_books'] ?? 0;
    final issuedBooks = statsProvider.stats['issued_books'] ?? 0;
    final availableBooks = statsProvider.stats['available_books'] ?? 0;

    if (totalBooks == 0) {
      return _buildFloatingCard(
        context,
        offsetSeed: 0.58,
        child: Card(
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
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

    return _buildFloatingCard(
      context,
      offsetSeed: 0.64,
      child: Card(
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
                          enabled: _enableChartTouch,
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

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({
    required this.size,
    required this.colors,
  });

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter({
    required this.color,
    required this.spacing,
    required this.radius,
  });

  final Color color;
  final double spacing;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.spacing != spacing ||
        oldDelegate.radius != radius;
  }
}

