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
import '../widgets/reports_content.dart';
import '../widgets/search_results_dialog.dart';
import '../widgets/notification_bell.dart';
import '../services/api_service.dart';
import '../utils/error_utils.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
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

  final List<Widget> _screens = [
    const DashboardContent(),
    const BooksContent(),
    const MembersContent(),
    const IssuesContent(),
    const ReportsContent(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Books Management',
    'Members Management',
    'Issues & Returns',
    'Reports & Analytics',
  ];

  @override
  void initState() {
    super.initState();
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
    // Keep startup fast: Dashboard content will fetch its own alerts/activity.
    context.read<IssueProvider>().loadStats().catchError(
      (e) => kDebugMode ? debugPrint('Error loading stats: $e') : null,
    );

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 900;
    final isVeryCompact = screenWidth < 600;

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
      drawer: isCompact
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
            if (!isCompact)
              Sidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: _onItemSelected,
              ),
            Expanded(
              child: Column(
                children: [
                  // Modern App Bar
                  Container(
                    height: isVeryCompact ? 60 : 70,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isVeryCompact ? 12 : 24,
                      ),
                      child: Row(
                        children: [
                          if (isCompact)
                            Builder(
                              builder: (context) => IconButton(
                                icon: const Icon(Icons.menu),
                                onPressed: () =>
                                    Scaffold.of(context).openDrawer(),
                              ),
                            ),
                          // Title
                          Flexible(
                            flex: 0,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                _titles[_selectedIndex],
                                key: ValueKey<int>(_selectedIndex),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          // Push everything else to the right
                          const Spacer(),
                          // Search Bar - Responsive width
                          if (!isVeryCompact)
                            Flexible(
                              flex: 0,
                              child: Container(
                                width: screenWidth < 1000 ? 220 : 280,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  onSubmitted: (value) => _performSearch(value),
                                  decoration: InputDecoration(
                                    hintText: 'Search...',
                                    prefixIcon: Icon(
                                      Icons.search_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      size: 22,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Theme.of(context).colorScheme.primary,
                                        size: 20,
                                      ),
                                      onPressed: () => _performSearch(_searchController.text),
                                      tooltip: 'Search',
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (isVeryCompact)
                            IconButton(
                              icon: Icon(
                                Icons.search_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: () => _showSearchDialog(context),
                            ),
                          const SizedBox(width: 8),
                          // Notification Bell with Badge
                          const NotificationBell(),
                        ],
                      ),
                    ),
                  ),
                  // Offline banner
                  if (_isOffline)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.orange.shade700,
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Backend unreachable — retrying...',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                            ),
                          ),
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white.withValues(alpha: 0.8),
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

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    // Ctrl+1..5 to switch tabs
    if (isCtrl) {
      const tabKeys = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
      ];
      for (var i = 0; i < tabKeys.length; i++) {
        if (event.logicalKey == tabKeys[i]) {
          _onItemSelected(i);
          return;
        }
      }
      // Ctrl+F to focus search
      if (event.logicalKey == LogicalKeyboardKey.keyF) {
        // Show search dialog on small screens, focus search bar on large
        final screenWidth = MediaQuery.of(context).size.width;
        if (screenWidth < 600) {
          _showSearchDialog(context);
        }
        return;
      }
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
    final sw = MediaQuery.of(context).size.width;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Search'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: sw < 500 ? sw * 0.85 : 300,
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search books, members...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _keyboardFocusNode.dispose();
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
