import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _booksLoaded = false;
  bool _membersLoaded = false;
  bool _issuesLoaded = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;

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
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    // Load initial data for all screens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    // Keep startup fast: Dashboard content will fetch its own alerts/activity.
    context.read<IssueProvider>().loadStats().catchError(
      (e) => print('Error loading stats: $e'),
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
        (e) => print('Error loading books: $e'),
      );
      return;
    }
    if (index == 2 && !_membersLoaded) {
      _membersLoaded = true;
      context.read<MemberProvider>().loadMembers().catchError(
        (e) => print('Error loading members: $e'),
      );
      return;
    }
    if (index == 3 && !_issuesLoaded) {
      _issuesLoaded = true;
      context.read<IssueProvider>().loadIssues().catchError(
        (e) => print('Error loading issues: $e'),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            Sidebar(
              selectedIndex: _selectedIndex,
              onItemSelected: _onItemSelected,
            ),
            Expanded(
              child: Column(
                children: [
                  // Modern App Bar
                  Container(
                    height: 80,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                      ), // Increased horizontal padding
                      child: Row(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _titles[_selectedIndex],
                              key: ValueKey<int>(_selectedIndex),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                          ),
                          const Spacer(),
                          // Search Bar
                          Container(
                            width: 320, // Slightly wider
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.3),
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) => _onSearchChanged(value),
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ), // Increased padding
                              ),
                            ),
                          ),
                          const SizedBox(width: 24), // Increased spacing
                          // Notification Bell with Badge
                          const NotificationBell(),
                        ],
                      ),
                    ),
                  ),
                  // Content Area
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Padding(
                          padding: const EdgeInsets.all(
                            24,
                          ), // Added padding for better spacing
                          child: _screens[_selectedIndex],
                        ),
                      ),
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

  void _onItemSelected(int index) {
    if (_selectedIndex != index) {
      _animationController.reset();
      setState(() => _selectedIndex = index);
      _animationController.forward();

      // Load data for the newly selected tab.
      _ensureTabDataLoaded(index);
    }
  }

  void _onSearchChanged(String query) async {
    // Cancel previous timer
    _searchDebounceTimer?.cancel();

    if (query.trim().isEmpty) {
      context.read<SearchProvider>().clearSearch();
      return;
    }

    // Start a new timer - search will run after 800ms of inactivity
    _searchDebounceTimer = Timer(const Duration(milliseconds: 800), () async {
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
              content: Text('Search failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
