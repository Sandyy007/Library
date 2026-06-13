import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/issue_provider.dart';
import '../providers/book_provider.dart';
import '../providers/member_provider.dart';
import '../providers/search_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/sidebar.dart';
import '../widgets/dashboard_content.dart';
import '../widgets/books_content.dart';
import '../widgets/members_content.dart';
import '../widgets/issues_content.dart';
import '../utils/responsive.dart';
import '../widgets/reports_content.dart';
import '../widgets/about_content.dart';
import '../widgets/search_results_dialog.dart';
import '../widgets/notification_bell.dart';
import '../widgets/session_expiring_banner.dart';
import '../services/api_service.dart';
import '../utils/error_utils.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.initialIndex = 0});

  /// Tab to start on (0=Dashboard, 1=Books, 2=Members, 3=Issues,
  /// 4=Reports, 5=About). Primarily for tests that want to mount
  /// a specific tab without having to simulate navigation.
  final int initialIndex;

  /// Broadcasts shortcut events to child widgets.
  /// Values: 'new-book', 'new-member', 'new-issue'
  static final ValueNotifier<String?> shortcutEvent = ValueNotifier(null);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  static const List<String> _hindiFontFallback = [
    'NotoSansDevanagari',
    'Nirmala UI',
    'Mangal',
    'Noto Sans Devanagari',
  ];
  int _selectedIndex = 0;
  int _previousIndex = 0;
  bool _booksLoaded = false;
  bool _membersLoaded = false;
  bool _issuesLoaded = false;
  bool _isOffline = false;
  Timer? _connectivityTimer;
  late AnimationController _animationController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode(
    debugLabel: 'Dashboard global search',
  );

  final List<Widget> _screens = [
    const DashboardContent(),
    const BooksContent(),
    const MembersContent(),
    const IssuesContent(),
    const ReportsContent(),
    const AboutContent(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Books Management',
    'Members Management',
    'Issues & Returns',
    'Reports & Analytics',
    'About Us',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _previousIndex = widget.initialIndex;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();

    // Load initial data for all screens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      _startConnectivityCheck();
    });
  }

  void _startConnectivityCheck() {
    _checkConnectivity();
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkConnectivity(),
    );
  }

  Future<void> _checkConnectivity() async {
    try {
      await ApiService.healthCheck();
      if (_isOffline && mounted) setState(() => _isOffline = false);
    } catch (_) {
      if (!_isOffline && mounted) setState(() => _isOffline = true);
    }
  }

  void _loadInitialData() {
    // Dashboard content will fetch its own alerts/activity.
    // Initialize notifications with current user (if authenticated)
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isAuthenticated && authProvider.user != null) {
      context.read<NotificationProvider>().initialize(authProvider.user!.id);
    }
  }

  void _ensureTabDataLoaded(int index) {
    // Load tab data lazily the first time a tab is opened.
    if (index == 1 && !_booksLoaded) {
      _booksLoaded = true;
      context.read<BookProvider>().loadBooks().catchError(
        (e) => kDebugMode ? debugPrint('Error loading books: $e') : null,
      );
      return;
    }
    if (index == 2 && !_membersLoaded) {
      _membersLoaded = true;
      context.read<MemberProvider>().loadMembers().catchError(
        (e) => kDebugMode ? debugPrint('Error loading members: $e') : null,
      );
      return;
    }
    if (index == 3 && !_issuesLoaded) {
      _issuesLoaded = true;
      context.read<IssueProvider>().loadIssues().catchError(
        (e) => kDebugMode ? debugPrint('Error loading issues: $e') : null,
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isVeryCompact = r.width < Breakpoints.sidebarDrawerThreshold;
    final showSearchField = r.width >= 760;
    final searchBarWidth = r.isExtraExpanded
      ? 480.0
      : (r.isExpanded ? 440.0 : (r.width >= 1000 ? 380.0 : 320.0));

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
      drawer: isVeryCompact
          ? Drawer(
              child: Sidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: (index) {
                  _onItemSelected(index);
                  Navigator.of(context).pop();
                },
                isDrawer: true,
              ),
            )
          : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
            ],
          ),
        ),
        child: Row(
          children: [
            if (!isVeryCompact)
              Sidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: _onItemSelected,
              ),
            Expanded(
              child: Column(
                children: [
                  const SessionExpiringBanner(),
                  // Modern App Bar
                  Container(
                    height: isVeryCompact ? 80 : 68,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isVeryCompact ? 12 : 20,
                      ),
                      child: Row(
                        children: [
                          if (isVeryCompact)
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(1),
                              child: Semantics(
                                button: true,
                                label: 'Open navigation menu',
                                child: Builder(
                                  builder: (context) => Tooltip(
                                    message: 'Open menu',
                                    child: IconButton(
                                      onPressed: () =>
                                          Scaffold.of(context).openDrawer(),
                                      icon: const Icon(Icons.menu_rounded),
                                      tooltip: 'Open menu',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Title
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    _titles[_selectedIndex],
                                    key: ValueKey<int>(_selectedIndex),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                _buildConnectivityPill(context),
                              ],
                            ),
                          ),
                          // Search Bar - Responsive width
                          if (showSearchField)
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(2),
                              child: Semantics(
                                textField: true,
                                label:
                                    'Global search. Press Control and F to focus this field.',
                                child: Container(
                                  width: searchBarWidth,
                                  height: r.inputHeight,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: TextField(
                                    focusNode: _searchFocusNode,
                                    controller: _searchController,
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: (value) => _performSearch(value),
                                    style: _searchTextStyle(context),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Search books, members, issues...',
                                      hintStyle: _searchHintStyle(context),
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.only(left: 12, right: 4),
                                        child: Icon(
                                          Icons.search_rounded,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          size: 20,
                                        ),
                                      ),
                                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                      suffixIcon: Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: IconButton(
                                          onPressed: () =>
                                              _performSearch(_searchController.text),
                                          icon: Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 18,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                            minimumSize: const Size(32, 32),
                                          ),
                                        ),
                                      ),
                                      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (!showSearchField)
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(2),
                              child: Semantics(
                                button: true,
                                label: 'Open search dialog',
                                child: IconButton(
                                  onPressed: () => _showSearchDialog(context),
                                  icon: Icon(
                                    Icons.search_rounded,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  tooltip: 'Search',
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          // Notification Bell with Badge
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(3),
                            child: Semantics(
                              container: true,
                              label: 'Notifications',
                              child: const NotificationBell(),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                  // Offline banner
                  if (_isOffline)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Row(
                        children: [
                          Icon(Icons.cloud_off,
                              color: Theme.of(context).colorScheme.onErrorContainer,
                              size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Backend unreachable — retrying...',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Content Area with slide+fade transition
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        // Determine slide direction based on tab index
                        final isForward = _selectedIndex >= _previousIndex;
                        final slideOffset = Tween<Offset>(
                          begin: Offset(isForward ? 0.05 : -0.05, 0),
                          end: Offset.zero,
                        ).animate(animation);
                        return SlideTransition(
                          position: slideOffset,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<int>(_selectedIndex),
                        child: _screens[_selectedIndex],
                      ),
                    ),
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

  Widget _buildConnectivityPill(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOffline = _isOffline;
    final accent = isOffline ? cs.error : cs.primary;
    final label = isOffline ? 'Offline' : 'Online';
    final icon =
        isOffline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  TextStyle _searchTextStyle(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    return base.copyWith(fontFamilyFallback: _hindiFontFallback);
  }

  TextStyle _searchHintStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    return base.copyWith(
      color: cs.onSurface.withValues(alpha: 0.6),
      fontFamilyFallback: _hindiFontFallback,
    );
  }

  void _focusSearchField() {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      _showSearchDialog(context);
    } else {
      _searchFocusNode.requestFocus();
      _searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchController.text.length,
      );
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    if (event.logicalKey == LogicalKeyboardKey.f1) {
      _showShortcutHelpDialog();
      return;
    }

    // Ctrl+1..6 to switch tabs
    if (isCtrl) {
      const tabKeys = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
        LogicalKeyboardKey.digit6,
      ];
      for (var i = 0; i < tabKeys.length; i++) {
        if (event.logicalKey == tabKeys[i]) {
          _onItemSelected(i);
          return;
        }
      }
      // Ctrl+F to focus search
      if (event.logicalKey == LogicalKeyboardKey.keyF) {
        _focusSearchField();
        return;
      }
      // Ctrl+K to focus search
      if (event.logicalKey == LogicalKeyboardKey.keyK) {
        _focusSearchField();
        return;
      }
      // Ctrl+/ to show keyboard shortcut help
      if (event.logicalKey == LogicalKeyboardKey.slash) {
        _showShortcutHelpDialog();
        return;
      }
      // Ctrl+R to refresh current tab data
      if (event.logicalKey == LogicalKeyboardKey.keyR) {
        _refreshCurrentTab();
        return;
      }
      // Ctrl+N to create new item (context-aware)
      if (event.logicalKey == LogicalKeyboardKey.keyN) {
        _createNewForCurrentTab();
        return;
      }
    }
  }

  /// Refresh data for the currently active tab.
  void _refreshCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        // Dashboard — trigger full reload via IssueProvider stats
        context.read<IssueProvider>().loadStats().catchError(
          (e) => kDebugMode ? debugPrint('Refresh stats: $e') : null,
        );
        break;
      case 1:
        context.read<BookProvider>().loadBooks().catchError(
          (e) => kDebugMode ? debugPrint('Refresh books: $e') : null,
        );
        break;
      case 2:
        context.read<MemberProvider>().loadMembers().catchError(
          (e) => kDebugMode ? debugPrint('Refresh members: $e') : null,
        );
        break;
      case 3:
        context.read<IssueProvider>().loadIssues().catchError(
          (e) => kDebugMode ? debugPrint('Refresh issues: $e') : null,
        );
        break;
      case 4:
        // Reports — no single refresh, just notify
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Use the refresh button on each report tab'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case 5:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('About Us is always up to date'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
    }
    if (_selectedIndex <= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refreshing ${_titles[_selectedIndex]}...'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// Open the "Add New" dialog for the current tab via shortcut event.
  void _createNewForCurrentTab() {
    switch (_selectedIndex) {
      case 1:
        DashboardScreen.shortcutEvent.value = null; // reset first
        DashboardScreen.shortcutEvent.value = 'new-book';
        break;
      case 2:
        DashboardScreen.shortcutEvent.value = null;
        DashboardScreen.shortcutEvent.value = 'new-member';
        break;
      case 3:
        DashboardScreen.shortcutEvent.value = null;
        DashboardScreen.shortcutEvent.value = 'new-issue';
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ctrl+N: Switch to Books, Members, or Issues tab to add new items'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  void _onItemSelected(int index) {
    if (_selectedIndex != index) {
      _previousIndex = _selectedIndex;
      _animationController.reset();
      setState(() => _selectedIndex = index);
      _animationController.forward();

      // Load data for the newly selected tab.
      _ensureTabDataLoaded(index);
    }
  }

  void _showSearchDialog(BuildContext context) {
    final r = Responsive(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Search'),
        content: SizedBox(
          width: r.dialogWidth(maxDesktop: 400),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search books, members, issues, reports',
              prefixIcon: const Icon(Icons.search),
              hintStyle: _searchHintStyle(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            style: _searchTextStyle(context),
            onSubmitted: (value) {
              Navigator.of(dialogContext).pop();
              _performSearch(value);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _performSearch(_searchController.text);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showShortcutHelpDialog() {
    final r = Responsive(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keyboard Shortcuts'),
        content: SizedBox(
          width: r.dialogWidth(maxDesktop: 400),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ctrl+1..6  Switch tabs'),
              SizedBox(height: 8),
              Text('Ctrl+F     Focus search'),
              SizedBox(height: 8),
              Text('Ctrl+K     Focus search'),
              SizedBox(height: 8),
              Text('Ctrl+R     Refresh current tab'),
              SizedBox(height: 8),
              Text('Ctrl+N     Create new item (context-aware)'),
              SizedBox(height: 8),
              Text('Ctrl+/     Open this shortcut help'),
              SizedBox(height: 8),
              Text('F1        Open this shortcut help'),
            ],
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

  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      context.read<SearchProvider>().clearSearch();
      return;
    }

    try {
      await context.read<SearchProvider>().searchAll(query);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => const SearchResultsDialog(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getOperationErrorMessage('Search', e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        _searchController.clear();
      }
    }
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _keyboardFocusNode.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
