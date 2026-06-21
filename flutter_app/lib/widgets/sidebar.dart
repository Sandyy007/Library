import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/responsive.dart';
import 'advanced_search_dialog.dart';
import 'backup_restore_dialog.dart';

class Sidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isDrawer;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.isDrawer = false,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Hover states for menu items
  final Map<int, bool> _menuHoverStates = {};
  // Hover states for quick actions
  final Map<int, bool> _quickActionHoverStates = {};
  bool _logoutHovered = false;
  bool _toggleHovered = false;

  void _setToggleHover(bool isHovered) {
    if (mounted) setState(() => _toggleHovered = isHovered);
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  void _setMenuHover(int index, bool isHovered) {
    if (mounted) setState(() => _menuHoverStates[index] = isHovered);
  }

  void _setQuickActionHover(int index, bool isHovered) {
    if (mounted) setState(() => _quickActionHoverStates[index] = isHovered);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final responsive = Responsive(context);
    final sidebarWidth = responsive.shouldCollapseSidebar ? Breakpoints.sidebarCollapsedWidth : Breakpoints.sidebarWidth;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171923) : const Color(0xFFFFFFFF),
        border: Border.all(color: isDark ? const Color(0xFF2D2F3D) : const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // ══════════════════════════════════════════════
            // SECTION 1 - SIDEBAR HEADER (gradient top area) - compact
            // ══════════════════════════════════════════════
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0D2137),
                    const Color(0xFF1565C0),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Top-right decorative circle
                  Positioned(
                    top: -25,
                    right: -25,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  // Bottom-left decorative circle
                  Positioned(
                    bottom: -15,
                    left: -15,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                  // Glow divider line
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  // Header content - ultra compact
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      responsive.shouldCollapseSidebar ? 8 : 16,
                      responsive.shouldCollapseSidebar ? 8 : 16,
                      responsive.shouldCollapseSidebar ? 8 : 16,
                      responsive.shouldCollapseSidebar ? 8 : 12,
                    ),
                    child: Column(
                      children: [
                        // Logo section - smaller
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Radial glow
                            Container(
                              width: responsive.shouldCollapseSidebar ? 48 : 90,
                              height: responsive.shouldCollapseSidebar ? 48 : 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.06),
                                    Colors.transparent,
                                  ],
                                  radius: 0.8,
                                ),
                              ),
                            ),
                            // Outer ring
                            Container(
                              width: responsive.shouldCollapseSidebar ? 40 : 62,
                              height: responsive.shouldCollapseSidebar ? 40 : 62,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                            ),
                            // Logo container
                            Container(
                              width: responsive.shouldCollapseSidebar ? 36 : 90,
                              height: responsive.shouldCollapseSidebar ? 36 : 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Padding(
                                  padding: EdgeInsets.all(responsive.shouldCollapseSidebar ? 0 : 1),
                                  child: Image.asset(
                                    'assets/images/Office_Logo.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFF0D2137),
                                              const Color(0xFF1565C0),
                                            ],
                                          ),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.account_balance_rounded,
                                            size: responsive.shouldCollapseSidebar ? 16 : 36,
                                            color: Colors.white,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Header text - hidden in collapsed mode
                        if (!responsive.shouldCollapseSidebar) ...[
                          const SizedBox(height: 8),
                          // Institute Name - compact single line
                          Text(
                            'Uttar Pradesh State Tax\nTraining & Research Institute',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Subtitless
                          const SizedBox(height: 4),
                          Text(
                            'LIBRARY MANAGEMENT SYSTEM',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: const Color.fromARGB(255, 255, 255, 255).withValues(alpha: 0.75),
                              letterSpacing: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          // Administrator badge - compact
                          if (user != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_rounded,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.role.toLowerCase() == 'admin'
                                        ? 'Administrator'
                                        : user.username,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ══════════════════════════════════════════════
            // SECTION 2 - NAV MENU ITEMS (compact, scrollable)
            // ══════════════════════════════════════════════
            Expanded(
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  responsive.shouldCollapseSidebar ? 0 : 12,
                  12,
                  responsive.shouldCollapseSidebar ? 0 : 12,
                  8,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // Navigation Items
                    _buildNavItem(
                      icon: Icons.dashboard_rounded,
                      title: 'Dashboard',
                      index: 0,
                    ),
                    const SizedBox(height: 3),
                    _buildNavItem(
                      icon: Icons.menu_book_rounded,
                      title: 'Books',
                      index: 1,
                    ),
                    const SizedBox(height: 3),
                    _buildNavItem(
                      icon: Icons.people_alt_rounded,
                      title: 'Members',
                      index: 2,
                    ),
                    const SizedBox(height: 3),
                    _buildNavItem(
                      icon: Icons.assignment_turned_in_rounded,
                      title: 'Issues & Returns',
                      index: 3,
                    ),
                    const SizedBox(height: 3),
                    _buildNavItem(
                      icon: Icons.analytics_rounded,
                      title: 'Reports',
                      index: 4,
                    ),
                    const SizedBox(height: 3),
                    _buildNavItem(
                      icon: Icons.info_outline_rounded,
                      title: 'About Us',
                      index: 5,
                    ),

                    // ══════════════════════════════════════
                    // SECTION 3 - QUICK ACTIONS (compact)
                    // ══════════════════════════════════════
                    const SizedBox(height: 12),
                    // Divider before QUICK ACTIONS
                    Container(
                      height: 1,
                      margin: EdgeInsets.symmetric(horizontal: responsive.shouldCollapseSidebar ? 0 : 8),
                      color: isDark ? const Color(0xFF2D2F3D) : const Color(0xFFE5E7EB),
                    ),
                    const SizedBox(height: 8),
                    // QUICK ACTIONS label - hidden in collapsed mode
                    if (!responsive.shouldCollapseSidebar)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 4),
                          child: Text(
                            'QUICK ACTIONS',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF9B9DAB) : const Color(0xFF6B7280),
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                      ),
                    _buildQuickActionItem(
                      icon: Icons.search_rounded,
                      title: 'Advanced Search',
                      index: 0,
                      onTap: () => _showAdvancedSearch(context),
                    ),
                    const SizedBox(height: 2),
                    _buildQuickActionItem(
                      icon: Icons.backup_rounded,
                      title: 'Backup & Restore',
                      index: 1,
                      onTap: () => _showBackupRestore(context),
                    ),
                  ],
                ),
              ),
            ),

            // ══════════════════════════════════════════════
            // SECTION 4 - LIGHT/DARK TOGGLE (fixed bottom)
            // ══════════════════════════════════════════════
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              child: MouseRegion(
                onEnter: (_) => _setToggleHover(true),
                onExit: (_) => _setToggleHover(false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _toggleHovered
                        ? (isDark ? const Color(0xFF2C2E3C) : const Color(0xFFF8FAFC))
                        : (isDark ? const Color(0xFF1C1E28) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2D2F3D) : const Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  child: Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      final isCollapsed = Responsive(context).shouldCollapseSidebar;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: isCollapsed
                            ? Center(
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 20,
                                      minHeight: 20,
                                    ),
                                    icon: Icon(
                                      themeProvider.isDarkMode
                                          ? Icons.dark_mode_rounded
                                          : Icons.light_mode_rounded,
                                      size: 16,
                                      color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFF59E0B),
                                    ),
                                    onPressed: () => themeProvider.toggleTheme(),
                                  ),
                                ),
                              )
                            : Row(
                          children: [
                            Icon(
                              Icons.light_mode_rounded,
                              size: 16,
                              color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Light',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFFEDEEF4) : const Color(0xFF374151),
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              height: 20,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Switch(
                                  key: ValueKey(themeProvider.isDarkMode),
                                  value: themeProvider.isDarkMode,
                                  onChanged: (value) => themeProvider.toggleTheme(),
                                  activeThumbColor: isDark ? const Color(0xFF7C9BFF) : const Color(0xFF1565C0),
                                  activeTrackColor: (isDark ? const Color(0xFF7C9BFF) : const Color(0xFF1565C0)).withValues(alpha: 0.3),
                                  inactiveThumbColor: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                                  inactiveTrackColor: (isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)).withValues(alpha: 0.3),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.dark_mode_rounded,
                              size: 16,
                              color: isDark ? const Color(0xFF9B9DAB) : const Color(0xFF6B7280),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // ══════════════════════════════════════════════
            // SECTION 5 - LOGOUT BUTTON (fixed bottom)
            // ══════════════════════════════════════════════
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: MouseRegion(
                onEnter: (_) => setState(() => _logoutHovered = true),
                onExit: (_) => setState(() => _logoutHovered = false),
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _logoutHovered = true),
                  onTapUp: (_) => setState(() => _logoutHovered = false),
                  onTapCancel: () => setState(() => _logoutHovered = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    transform: Matrix4.diagonal3Values(
                      _logoutHovered ? 0.97 : 1.0,
                      _logoutHovered ? 0.97 : 1.0,
                      1.0,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        final ctx = context;
                        // ignore: use_build_context_synchronously
                        Future.microtask(() => _logout(ctx));
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _logoutHovered
                                ? [
                                    const Color(0xFFC62828),
                                    const Color(0xFFB71C1C),
                                  ]
                                : [
                                    const Color(0xFFD32F2F),
                                    const Color(0xFFB71C1C),
                                  ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD32F2F).withValues(alpha: _logoutHovered ? 0.35 : 0.2),
                              blurRadius: _logoutHovered ? 12 : 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // White shine overlay
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.06),
                                      Colors.transparent,
                                      Colors.transparent,
                                      Colors.white.withValues(alpha: 0.02),
                                    ],
                                    stops: const [0.0, 0.4, 0.6, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.logout_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  if (!responsive.shouldCollapseSidebar) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      'Logout',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // NAV ITEM WIDGET (Active/Inactive with hover states) - compact
  // ══════════════════════════════════════════════════════
  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final isSelected = widget.selectedIndex == index;
    final isHovered = _menuHoverStates[index] ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCollapsed = Responsive(context).shouldCollapseSidebar;

    // Theme-aware colors
    final activeColor = isDark ? const Color(0xFF7C9BFF) : const Color(0xFF1565C0);
    final hoverColorLight = const Color(0xFFEBF4FF);
    final hoverColorDark = const Color(0xFF2C2E3C);
    final iconBgLight = const Color(0xFFF0F4F8);
    final iconBgDark = const Color(0xFF262836);

    final hoverColor = isHovered ? (isDark ? hoverColorDark : hoverColorLight) : Colors.transparent;
    final iconBg = isSelected ? null : (isHovered ? (isDark ? activeColor.withValues(alpha: 0.15) : const Color(0xFFDBEAFE)) : (isDark ? iconBgDark : iconBgLight));

    return MouseRegion(
      onEnter: (_) => _setMenuHover(index, true),
      onExit: (_) => _setMenuHover(index, false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Future.microtask(() => widget.onItemSelected(index)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.diagonal3Values(isHovered ? 1.02 : 1.0, isHovered ? 1.02 : 1.0, 1.0),
          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 10, vertical: 9),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: isDark
                        ? [
                            activeColor.withValues(alpha: 0.26),
                            activeColor.withValues(alpha: 0.10),
                          ]
                        : [
                            const Color(0xFFE3EEFD),
                            const Color(0xFFF1F6FE),
                          ],
                  )
                : null,
            color: isSelected ? null : hoverColor,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: activeColor.withValues(alpha: isDark ? 0.35 : 0.20))
                : null,
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: isDark ? 0.25 : 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : (isSelected
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: isDark ? 0.18 : 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null),
          ),
          child: Row(
            mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              // Left accent bar (active only) - expanded only
              if (!isCollapsed && isSelected)
                Container(
                  width: 3.5,
                  height: 34,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        activeColor,
                        isDark ? const Color(0xFF5B8DEF) : const Color(0xFF42A5F5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              // Icon container 34x34 (compact)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            activeColor,
                            isDark ? const Color(0xFF5B8DEF) : const Color(0xFF42A5F5),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : iconBg,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isSelected
                  ? Colors.white
                  : isHovered
                      ? activeColor
                      : (isDark ? const Color(0xFF9B9DAB) : const Color(0xFF455A64)),
                ),
              ),
              // Label - expanded only
              if (!isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: isSelected ? 0.1 : 0.2,
                      color: isSelected
                          ? activeColor
                          : isHovered
                              ? activeColor
                              : (isDark ? const Color(0xFFEDEEF4) : const Color(0xFF374151)),
                    ),
                  ),
                ),
                // Active trailing indicator dot
                AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: isSelected ? 1.0 : 0.0,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activeColor,
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // QUICK ACTION ITEM WIDGET - compact
  // ══════════════════════════════════════════════════════
  Widget _buildQuickActionItem({
    required IconData icon,
    required String title,
    required int index,
    required VoidCallback onTap,
  }) {
    final isHovered = _quickActionHoverStates[index] ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCollapsed = Responsive(context).shouldCollapseSidebar;
    final activeColor = isDark ? const Color(0xFF7C9BFF) : const Color(0xFF1565C0);

    return MouseRegion(
      onEnter: (_) => _setQuickActionHover(index, true),
      onExit: (_) => _setQuickActionHover(index, false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Future.microtask(() => onTap()),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.diagonal3Values(isHovered ? 1.01 : 1.0, isHovered ? 1.01 : 1.0, 1.0),
          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 10, vertical: 8),
          decoration: BoxDecoration(
            color: isHovered ? (isDark ? const Color(0xFF2C2E3C) : const Color(0xFFEBF4FF)) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              // Icon container 28x28 (compact)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isHovered
                      ? (isDark ? activeColor.withValues(alpha: 0.15) : const Color(0xFFDBEAFE))
                      : (isDark ? const Color(0xFF262836) : const Color(0xFFF0F4F8)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: activeColor,
                ),
              ),
              // Label - expanded only
              if (!isCollapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: isHovered ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: 0.2,
                      color: isHovered ? activeColor : (isDark ? const Color(0xFFEDEEF4) : const Color(0xFF374151)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // LOGOUT DIALOG
  // ══════════════════════════════════════════════════════
  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.logout_rounded,
              color: Theme.of(dialogContext).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text('Logout', overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.onSurface,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showAdvancedSearch(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AdvancedSearchDialog(),
    );
  }

  void _showBackupRestore(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const BackupRestoreDialog(),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
