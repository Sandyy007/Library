import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/member_provider.dart';
import '../providers/issue_provider.dart';
import '../models/member.dart';
import '../widgets/member_dialog.dart';
import '../widgets/member_history_dialog.dart';
import '../widgets/borrowed_books_dialog.dart';
import '../services/api_service.dart';
import '../utils/hindi_text.dart';
import '../utils/error_utils.dart';
import '../utils/responsive.dart';
import '../widgets/common_widgets.dart';
import 'premium_dialog.dart';
import '../screens/dashboard_screen.dart';

enum MemberStatusFilter { all, active, inactive }

class MembersContent extends StatefulWidget {
  const MembersContent({super.key});

  @override
  State<MembersContent> createState() => _MembersContentState();
}

class _MembersContentState extends State<MembersContent>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  MemberStatusFilter _statusFilter = MemberStatusFilter.all;
  final Set<int> _selectedMemberIds = <int>{};
  StreamSubscription<void>? _dataChangedSub;
  Timer? _searchDebounce;
  int? _hoveredRowIndex;

  static const Duration _hoverDuration = Duration(milliseconds: 150);
  static const Duration _pulseDuration = Duration(seconds: 2);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _statusPulseController;
  late Animation<double> _statusPulse;

  TextStyle _textStyleForHindi(String text, TextStyle base) {
    final defaultSize = DefaultTextStyle.of(context).style.fontSize ?? 14;
    final effectiveSize = base.fontSize ?? defaultSize;

    if (containsDevanagari(text)) {
      final devanagariBase = GoogleFonts.notoSansDevanagari(textStyle: base);
      return devanagariBase.copyWith(
        fontSize: (effectiveSize * 1.15).clamp(10, 30).toDouble(),
        letterSpacing: 0.5,
        height: 1.5,
        fontFamilyFallback: const [
          'NotoSansDevanagari',
          'Nirmala UI',
          'Mangal',
          'Noto Sans Devanagari',
        ],
      );
    }

    if (looksLikeLegacyHindi(text)) {
      return base.copyWith(
        fontSize: (effectiveSize * 1.12).clamp(10, 30).toDouble(),
        letterSpacing: 0.3,
        height: 1.4,
        fontFamily: 'KrutiDev',
        fontFamilyFallback: const [
          'KrutiDev',
          'Kruti Dev 010',
          'NotoSansDevanagari',
          'Nirmala UI',
          'Mangal',
        ],
      );
    }

    return base.copyWith(
      fontFamilyFallback: const [
        'NotoSansDevanagari',
        'Nirmala UI',
        'Mangal',
        'Noto Sans Devanagari',
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _statusPulseController = AnimationController(
      duration: _pulseDuration,
      vsync: this,
    )..repeat(reverse: true);
    _statusPulse = CurvedAnimation(
      parent: _statusPulseController,
      curve: Curves.easeInOut,
    );
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

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
    _animationController.dispose();
    _statusPulseController.dispose();
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

  Widget _buildMemberSearchField({
    required TextEditingController controller,
    required Color tableBorderColor,
    required Color searchFill,
    required Color mutedText,
    required Color accentTeal,
  }) {
    return TextField(
      controller: controller,
      style: GoogleFonts.dmSans(fontSize: 14),
      cursorColor: accentTeal,
      decoration: InputDecoration(
        hintText: 'Search members...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  controller.clear();
                  _filterMembers();
                  setState(() {});
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tableBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tableBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentTeal, width: 1.2),
        ),
        filled: true,
        fillColor: searchFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
        hintStyle: GoogleFonts.dmSans(fontSize: 13, color: mutedText),
      ),
      onChanged: (value) {
        _searchDebounce?.cancel();
        _searchDebounce = Timer(const Duration(milliseconds: 350), _filterMembers);
        setState(() {});
      },
    );
  }

  Widget _buildMembersToolbarActions({
    required int selectedCount,
    required Color accentTeal,
    required ColorScheme colorScheme,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatusChips(),
          const SizedBox(width: 8),
          if (selectedCount > 0) ...[
            _buildToolbarDivider(context),
            _buildToolbarIconButton(
              icon: Icons.delete_forever,
              tooltip: 'Delete ($selectedCount)',
              onPressed: _deleteSelectedMembers,
              color: colorScheme.error,
            ),
            _buildToolbarIconButton(
              icon: Icons.clear,
              tooltip: 'Clear selection',
              onPressed: () => setState(_selectedMemberIds.clear),
            ),
          ],
          _buildToolbarDivider(context),
          _buildToolbarIconButton(
            icon: Icons.download,
            tooltip: 'Export CSV',
            onPressed: _exportMembersActivityCsv,
          ),
          _buildToolbarIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh',
            onPressed: _loadMembers,
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _showMemberDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Member'),
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) return const Color(0xFF137A5A);
                if (states.contains(WidgetState.hovered)) return const Color(0xFF168B66);
                return accentTeal;
              }),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersToolbar({
    required int selectedCount,
    required bool isCompact,
    required bool isMedium,
    required Color accentTeal,
    required Color tableBorderColor,
    required Color searchFill,
    required Color mutedText,
    required ColorScheme colorScheme,
  }) {
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMemberSearchField(
            controller: _searchController,
            tableBorderColor: tableBorderColor,
            searchFill: searchFill,
            mutedText: mutedText,
            accentTeal: accentTeal,
          ),
          const SizedBox(height: 10),
          _buildMembersToolbarActions(
            selectedCount: selectedCount,
            accentTeal: accentTeal,
            colorScheme: colorScheme,
          ),
        ],
      );
    }

    if (isMedium) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMemberSearchField(
            controller: _searchController,
            tableBorderColor: tableBorderColor,
            searchFill: searchFill,
            mutedText: mutedText,
            accentTeal: accentTeal,
          ),
          const SizedBox(height: 10),
          _buildMembersToolbarActions(
            selectedCount: selectedCount,
            accentTeal: accentTeal,
            colorScheme: colorScheme,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _buildMemberSearchField(
            controller: _searchController,
            tableBorderColor: tableBorderColor,
            searchFill: searchFill,
            mutedText: mutedText,
            accentTeal: accentTeal,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusChips(),
                const SizedBox(width: 8),
                if (selectedCount > 0) ...[
                  _buildToolbarDivider(context),
                  _buildToolbarIconButton(
                    icon: Icons.delete_forever,
                    tooltip: 'Delete ($selectedCount)',
                    onPressed: _deleteSelectedMembers,
                    color: colorScheme.error,
                  ),
                  _buildToolbarIconButton(
                    icon: Icons.clear,
                    tooltip: 'Clear selection',
                    onPressed: () => setState(_selectedMemberIds.clear),
                  ),
                  const SizedBox(width: 4),
                ],
                _buildToolbarDivider(context),
                _buildToolbarIconButton(
                  icon: Icons.download,
                  tooltip: 'Export CSV',
                  onPressed: _exportMembersActivityCsv,
                ),
                _buildToolbarIconButton(
                  icon: Icons.refresh,
                  tooltip: 'Refresh',
                  onPressed: _loadMembers,
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () => _showMemberDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Member'),
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.pressed)) return const Color(0xFF137A5A);
                      if (states.contains(WidgetState.hovered)) return const Color(0xFF168B66);
                      return accentTeal;
                    }),
                    foregroundColor: WidgetStateProperty.all(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final background = isDark
        ? cs.surfaceContainerHighest.withValues(alpha: 0.45)
        : const Color(0xFFF7FAFB);
    final borderColor = isDark
        ? cs.outlineVariant.withValues(alpha: 0.6)
        : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilterChip('All', MemberStatusFilter.all),
          const SizedBox(width: 4),
          _buildFilterChip('Active', MemberStatusFilter.active),
          const SizedBox(width: 4),
          _buildFilterChip('Inactive', MemberStatusFilter.inactive),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, MemberStatusFilter filter) {
    final isSelected = _statusFilter == filter;
    const accentTeal = Color(0xFF1D9E75);
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => setState(() => _statusFilter = filter),
        borderRadius: BorderRadius.circular(8),
        hoverColor: accentTeal.withValues(alpha: 0.1),
        child: AnimatedContainer(
          duration: _hoverDuration,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? accentTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? accentTeal
                  : cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderLabel(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8)
        : const Color(0xFF6B7280);
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: color,
      ),
    );
  }

  Widget _wrapRowCell(int rowIndex, Widget child, {bool showAccent = false}) {
    final isHovered = _hoveredRowIndex == rowIndex;
    return MouseRegion(
      onEnter: (_) {
        if (_hoveredRowIndex != rowIndex) {
          setState(() => _hoveredRowIndex = rowIndex);
        }
      },
      child: AnimatedContainer(
        duration: _hoverDuration,
        padding: EdgeInsets.only(left: showAccent ? 6 : 0),
        decoration: showAccent
            ? BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color:
                        isHovered ? const Color(0xFF1D9E75) : Colors.transparent,
                    width: 3,
                  ),
                ),
              )
            : null,
        child: child,
      ),
    );
  }

  Widget _buildPagerIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color borderColor,
    required Color iconColor,
    required Color hoverFill,
    required Color disabledIconColor,
  }) {
    final enabled = onPressed != null;
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      style: ButtonStyle(
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        fixedSize: WidgetStateProperty.all(const Size(32, 32)),
        minimumSize: WidgetStateProperty.all(const Size(32, 32)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: enabled
                ? borderColor
                : borderColor.withValues(alpha: 0.45),
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (!enabled) return Colors.transparent;
          if (states.contains(WidgetState.hovered)) return hoverFill;
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (!enabled) return disabledIconColor;
          return iconColor;
        }),
      ),
    );
  }

  /// Thin vertical divider for the toolbar.
  Widget _buildToolbarDivider(BuildContext context) {
    return Container(
      height: 20,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
    );
  }

  /// Toolbar IconButton with consistent styling
  Widget _buildToolbarIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final iconColor = color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          hoverColor: iconColor.withValues(alpha: 0.1),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color hoverColor,
    required Color borderColor,
    required Color iconColor,
  }) {
    return _ActionIconButton(
      icon: icon,
      tooltip: tooltip,
      onTap: onTap,
      backgroundColor: backgroundColor,
      hoverColor: hoverColor,
      borderColor: borderColor,
      iconColor: iconColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final memberProvider = Provider.of<MemberProvider>(context);
    final selectedCount = _selectedMemberIds.length;
    final filteredMembers = getFilteredMembers(memberProvider.members);
    final r = Responsive(context);
    final screenWidth = r.width;
    final isCompact = r.isCompact;
    final isMedium = r.isMedium;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const accentTeal = Color(0xFF1D9E75);
    final headerAccent = isDark
      ? colorScheme.primary.withValues(alpha: 0.45)
      : const Color(0xFFBFE9E3);
    final rowHoverColor = isDark
      ? colorScheme.primary.withValues(alpha: 0.12)
      : const Color(0xFFF0FAF7);
    final zebraColor = isDark
      ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.18)
      : const Color(0xFFFAFAFA);
    final tableBorderColor = isDark
      ? colorScheme.outlineVariant.withValues(alpha: 0.55)
      : const Color(0xFFE5E7EB);
    final tableShadowColor = isDark
      ? Colors.black.withValues(alpha: 0.32)
      : Colors.black.withValues(alpha: 0.06);
    final headerBackground = isDark
      ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.65)
      : Colors.white.withValues(alpha: 0.9);
    final mutedText = isDark
      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.8)
      : const Color(0xFF6B7280);
    final searchFill = isDark
      ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
      : const Color(0xFFF7FAFB);
    final nameTextColor =
      isDark ? colorScheme.onSurface : const Color(0xFF1A1A2E);
    final secondaryTextColor = isDark
      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.8)
      : const Color(0xFF666666);
    const headingRowHeight = 54.0;
    final showEmail = screenWidth >= 980;
    final showPhone = screenWidth >= 860;
    final showType = screenWidth >= 900;
    const showBorrowed = true;
    final columnWidths = <double>[
      46,
      64,
      screenWidth >= 1200 ? 260 : (screenWidth >= 900 ? 220 : 180),
      if (showEmail) (screenWidth >= 1200 ? 260 : 220),
      if (showPhone) 120,
      if (showType) 140,
      if (showBorrowed) 90,
      110,
    ];
    final minTableWidth =
      columnWidths.fold(0.0, (sum, width) => sum + width);

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: EdgeInsets.all(r.pagePadding),
          child: Column(
          children: [
            // Search Bar, Status Filters, and Action buttons - all in one bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tableBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: tableShadowColor,
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _buildMembersToolbar(
                selectedCount: selectedCount,
                isCompact: isCompact,
                isMedium: isMedium,
                accentTeal: accentTeal,
                tableBorderColor: tableBorderColor,
                searchFill: searchFill,
                mutedText: mutedText,
                colorScheme: colorScheme,
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tableBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: tableShadowColor,
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
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
                            dividerColor: isDark
                                ? colorScheme.outlineVariant
                                    .withValues(alpha: 0.35)
                                : const Color(0xFFF0F0F0),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            checkboxTheme: Theme.of(context)
                                .checkboxTheme
                                .copyWith(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  side: BorderSide(
                                    color: tableBorderColor,
                                    width: 1,
                                  ),
                                  fillColor:
                                      WidgetStateProperty.resolveWith(
                                    (states) {
                                      if (states
                                          .contains(WidgetState.selected)) {
                                        return accentTeal;
                                      }
                                      return Colors.transparent;
                                    },
                                  ),
                                  checkColor: WidgetStateProperty.all(
                                    Colors.white,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                          ),
                          child: MouseRegion(
                            onExit: (_) {
                              if (_hoveredRowIndex != null) {
                                setState(() => _hoveredRowIndex = null);
                              }
                            },
                            child: Stack(
                              children: [
                                DataTable2(
                                  columnSpacing: 12,
                                  horizontalMargin: 12,
                                  dataRowHeight: 72,
                                  headingRowHeight: headingRowHeight,
                                  showCheckboxColumn: false,
                                  minWidth: minTableWidth,
                                  fixedTopRows: 1,
                                  headingRowColor: WidgetStateProperty.all(
                                    headerBackground,
                                  ),
                                  dividerThickness: 0.5,
                                  columns: [
                                    DataColumn2(
                                      label: Center(
                                        child: Transform.scale(
                                          scale: 0.85,
                                          child: Checkbox(
                                            tristate: true,
                                            value: filteredMembers.isEmpty
                                                ? false
                                                : filteredMembers.every((m) =>
                                                        _selectedMemberIds
                                                            .contains((m as Member)
                                                                .id))
                                                    ? true
                                                    : filteredMembers.any((m) =>
                                                            _selectedMemberIds
                                                                .contains((m as Member)
                                                                    .id))
                                                        ? null
                                                        : false,
                                            onChanged: (value) {
                                              setState(() {
                                                if (value == true) {
                                                  for (final m in
                                                      filteredMembers) {
                                                    _selectedMemberIds
                                                        .add((m as Member)
                                                            .id);
                                                  }
                                                } else {
                                                  for (final m in
                                                      filteredMembers) {
                                                    _selectedMemberIds
                                                        .remove((m as Member)
                                                            .id);
                                                  }
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataColumn2(
                                      label: _buildHeaderLabel('Photo'),
                                    ),
                                    DataColumn2(
                                      label: _buildHeaderLabel('Name'),
                                    ),
                                    if (showEmail)
                                      DataColumn2(
                                        label: _buildHeaderLabel('Email'),
                                      ),
                                    if (showPhone)
                                      DataColumn2(
                                        label: _buildHeaderLabel('Phone'),
                                      ),
                                    if (showType)
                                      DataColumn2(
                                        label: _buildHeaderLabel('Type'),
                                      ),
                                    if (showBorrowed)
                                      DataColumn2(
                                        label: _buildHeaderLabel('Borrowed'),
                                      ),
                                    DataColumn2(
                                      label: _buildHeaderLabel('Status'),
                                    ),
                                    DataColumn2(
                                      label: Align(
                                        alignment: Alignment.centerRight,
                                        child: _buildHeaderLabel('Actions'),
                                      ),
                                    ),
                                  ],
                                  rows: filteredMembers
                                      .asMap()
                                      .entries
                                      .map(
                                        (entry) {
                                          final idx = entry.key;
                                          final member = entry.value as Member;
                                          final baseRowColor = idx.isEven
                                              ? colorScheme.surface
                                              : zebraColor;
                                          final emailValue =
                                              (member.email ?? '').trim();
                                          final phoneValue =
                                              (member.phone ?? '').trim();
                                          final addressValue =
                                              normalizeHindiForDisplay(
                                            member.address ?? '',
                                          );
                                          final metaParts = <String>[];
                                          if (!showEmail && emailValue.isNotEmpty) {
                                            metaParts.add(emailValue);
                                          }
                                          if (!showPhone && phoneValue.isNotEmpty) {
                                            metaParts.add(phoneValue);
                                          }
                                          if (!showType &&
                                              member.memberType.isNotEmpty) {
                                            metaParts.add(
                                              _memberTypeLabel(member.memberType),
                                            );
                                          }
                                          if (metaParts.isEmpty &&
                                              addressValue.isNotEmpty) {
                                            metaParts.add(addressValue);
                                          }
                                          final metaLine = metaParts.isEmpty
                                              ? null
                                              : metaParts.join(' • ');
                                          return DataRow(
                                            color:
                                                WidgetStateProperty.resolveWith(
                                              (states) {
                                                if (states.contains(
                                                  WidgetState.hovered,
                                                )) {
                                                  return rowHoverColor;
                                                }
                                                if (states.contains(
                                                  WidgetState.selected,
                                                )) {
                                                  return rowHoverColor
                                                      .withValues(alpha: 0.6);
                                                }
                                                return baseRowColor;
                                              },
                                            ),
                                            selected: _selectedMemberIds
                                                .contains(member.id),
                                            onSelectChanged: (selected) {
                                              if (selected == null) return;
                                              setState(() {
                                                if (selected) {
                                                  _selectedMemberIds
                                                      .add(member.id);
                                                } else {
                                                  _selectedMemberIds
                                                      .remove(member.id);
                                                }
                                              });
                                            },
                                            cells: [
                                              DataCell(
                                                _wrapRowCell(
                                                  idx,
                                                  Center(
                                                    child: Transform.scale(
                                                      scale: 0.9,
                                                      child: Checkbox(
                                                        value:
                                                            _selectedMemberIds
                                                                .contains(
                                                          member.id,
                                                        ),
                                                        onChanged: (checked) {
                                                          setState(() {
                                                            if (checked ==
                                                                true) {
                                                              _selectedMemberIds
                                                                  .add(member
                                                                      .id);
                                                            } else {
                                                              _selectedMemberIds
                                                                  .remove(member
                                                                      .id);
                                                            }
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                  showAccent: true,
                                                ),
                                              ),
                                              DataCell(
                                                _wrapRowCell(
                                                  idx,
                                                  _buildPhotoCell(member),
                                                ),
                                              ),
                                              DataCell(
                                                _wrapRowCell(
                                                  idx,
                                                  Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        normalizeHindiForDisplay(
                                                          member.name,
                                                        ),
                                                        style:
                                                            _textStyleForHindi(
                                                          normalizeHindiForDisplay(
                                                            member.name,
                                                          ),
                                                          GoogleFonts.dmSans(
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                nameTextColor,
                                                          ),
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      if (metaLine != null)
                                                        Text(
                                                          metaLine,
                                                          style: _textStyleForHindi(
                                                            metaLine,
                                                            GoogleFonts.dmSans(
                                                              fontSize: 11,
                                                              color: mutedText,
                                                            ),
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              if (showEmail)
                                                DataCell(
                                                  _wrapRowCell(
                                                    idx,
                                                    Text(
                                                      emailValue.isEmpty
                                                          ? '-'
                                                          : emailValue,
                                                      style:
                                                          GoogleFonts.dmSans(
                                                        fontSize: 13,
                                                        color:
                                                            secondaryTextColor,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              if (showPhone)
                                                DataCell(
                                                  _wrapRowCell(
                                                    idx,
                                                    Text(
                                                      phoneValue.isEmpty
                                                          ? '-'
                                                          : phoneValue,
                                                      style: GoogleFonts
                                                          .inter(
                                                        fontSize: 12,
                                                        color:
                                                            secondaryTextColor,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              if (showType)
                                                DataCell(
                                                  _wrapRowCell(
                                                    idx,
                                                    _buildTypeChip(
                                                      member.memberType,
                                                    ),
                                                  ),
                                                ),
                                              if (showBorrowed)
                                                DataCell(
                                                  _wrapRowCell(
                                                    idx,
                                                    _buildBorrowCountBadge(
                                                      member,
                                                    ),
                                                  ),
                                                ),
                                              DataCell(
                                                _wrapRowCell(
                                                  idx,
                                                  _buildStatusBadge(
                                                    member.isActive,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                _wrapRowCell(
                                                  idx,
                                                  SizedBox(
                                                    width: 120,
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      alignment:
                                                          Alignment.centerRight,
                                                      child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .end,
                                                      children: [
                                                        _buildActionButton(
                                                          icon: Icons
                                                              .history_rounded,
                                                          tooltip:
                                                              'View history',
                                                          onTap: () =>
                                                              _showMemberHistory(
                                                            member,
                                                          ),
                                                          backgroundColor:
                                                              isDark
                                                                  ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                                                                  : const Color(0xFFEFF6FF),
                                                          hoverColor:
                                                              isDark
                                                                  ? const Color(0xFF2563EB).withValues(alpha: 0.25)
                                                                  : const Color(0xFFDBEAFE),
                                                          borderColor:
                                                              isDark
                                                                  ? const Color(0xFF2563EB).withValues(alpha: 0.4)
                                                                  : const Color(0xFFBFDBFE),
                                                          iconColor:
                                                              const Color(0xFF2563EB),
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        _buildActionButton(
                                                          icon:
                                                              Icons.edit_rounded,
                                                          tooltip:
                                                              'Edit member',
                                                          onTap: () =>
                                                              _showMemberDialog(
                                                            member: member,
                                                          ),
                                                          backgroundColor:
                                                              isDark
                                                                  ? const Color(0xFFD97706).withValues(alpha: 0.15)
                                                                  : const Color(0xFFFFF7ED),
                                                          hoverColor:
                                                              isDark
                                                                  ? const Color(0xFFD97706).withValues(alpha: 0.25)
                                                                  : const Color(0xFFFEF3C7),
                                                          borderColor:
                                                              isDark
                                                                  ? const Color(0xFFD97706).withValues(alpha: 0.4)
                                                                  : const Color(0xFFFDE68A),
                                                          iconColor:
                                                              const Color(0xFFD97706),
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        _buildActionButton(
                                                          icon:
                                                              Icons.delete_rounded,
                                                          tooltip:
                                                              'Delete member',
                                                          onTap: () =>
                                                              _deleteMember(
                                                            member.id,
                                                          ),
                                                          backgroundColor:
                                                              isDark
                                                                  ? const Color(0xFFE11D48).withValues(alpha: 0.15)
                                                                  : const Color(0xFFFFF1F2),
                                                          hoverColor:
                                                              isDark
                                                                  ? const Color(0xFFE11D48).withValues(alpha: 0.25)
                                                                  : const Color(0xFFFFE4E6),
                                                          borderColor:
                                                              isDark
                                                                  ? const Color(0xFFE11D48).withValues(alpha: 0.4)
                                                                  : const Color(0xFFFECDD3),
                                                          iconColor:
                                                              const Color(0xFFE11D48),
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
                                      )
                                      .toList(),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: headingRowHeight - 1,
                                  child: Container(
                                    height: 1,
                                    color: headerAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),

            // Pagination controls
            if (!memberProvider.isLoading && memberProvider.members.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: tableBorderColor,
                    ),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 760;
                    final footerTextStyle = GoogleFonts.dmSans(
                      fontSize: 13,
                      color: mutedText,
                    );
                    final pagePill = Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentTeal,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${memberProvider.currentPage}',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    );
                    final pageIndicator = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Page', style: footerTextStyle),
                        const SizedBox(width: 6),
                        pagePill,
                        const SizedBox(width: 6),
                        Text(
                          'of ${memberProvider.totalPages}',
                          style: footerTextStyle,
                        ),
                      ],
                    );
                    final loadMoreButton = OutlinedButton(
                      onPressed: memberProvider.hasMore
                          ? () => memberProvider.loadMoreMembers()
                          : null,
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        side: WidgetStateProperty.all(
                          const BorderSide(color: accentTeal),
                        ),
                        backgroundColor:
                            WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return accentTeal;
                          }
                          return Colors.transparent;
                        }),
                        foregroundColor:
                            WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return Colors.white;
                          }
                          return accentTeal;
                        }),
                        textStyle: WidgetStateProperty.all(
                          GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      child: const Text('+ Load More'),
                    );
                    final pagerButtons = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPagerIconButton(
                          icon: Icons.chevron_left,
                          onPressed: memberProvider.currentPage > 1
                              ? () => memberProvider.loadPage(
                                    memberProvider.currentPage - 1,
                                  )
                              : null,
                          borderColor: tableBorderColor,
                          iconColor: const Color(0xFF475569),
                          hoverFill: rowHoverColor,
                          disabledIconColor: const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 8),
                        _buildPagerIconButton(
                          icon: Icons.chevron_right,
                          onPressed: memberProvider.hasMore
                              ? () => memberProvider.loadPage(
                                    memberProvider.currentPage + 1,
                                  )
                              : null,
                          borderColor: tableBorderColor,
                          iconColor: const Color(0xFF475569),
                          hoverFill: rowHoverColor,
                          disabledIconColor: const Color(0xFF94A3B8),
                        ),
                      ],
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Showing ${memberProvider.members.length} of ${memberProvider.totalMembers} members',
                            style: footerTextStyle,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [Flexible(child: pageIndicator), pagerButtons],
                          ),
                          if (memberProvider.hasMore) ...[
                            const SizedBox(height: 10),
                            loadMoreButton,
                          ],
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Showing ${memberProvider.members.length} of ${memberProvider.totalMembers} members',
                            style: footerTextStyle,
                          ),
                        ),
                        Expanded(child: Center(child: pageIndicator)),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              pagerButtons,
                              if (memberProvider.hasMore) ...[
                                const SizedBox(width: 12),
                                loadMoreButton,
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            member.isActive ? Colors.green.withValues(alpha: 0.25) : Colors.grey.withValues(alpha: 0.2),
            member.isActive ? Colors.green.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: member.isActive ? Colors.green.withValues(alpha: 0.6) : Colors.grey.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (member.isActive ? Colors.green : Colors.grey).withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: member.profilePhoto != null && member.profilePhoto!.isNotEmpty
            ? Image.network(
                ApiService.resolvePublicUrl(member.profilePhoto!),
                fit: BoxFit.cover,
                width: 44,
                height: 44,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPhotoPlaceholder(),
              )
            : _buildPhotoPlaceholder(),
      ),
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Center(
      child: Icon(
        Icons.person,
        size: 22,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isActive
        ? (isDark ? const Color(0xFF059669).withValues(alpha: 0.15) : const Color(0xFFECFDF5))
        : (isDark ? const Color(0xFFEF4444).withValues(alpha: 0.15) : const Color(0xFFFEF2F2));
    final border = isActive
        ? (isDark ? const Color(0xFF059669).withValues(alpha: 0.4) : const Color(0xFF6EE7B7))
        : (isDark ? const Color(0xFFEF4444).withValues(alpha: 0.4) : const Color(0xFFFECACA));
    final textColor = isActive
        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
        : (isDark ? const Color(0xFFFC8181) : const Color(0xFFEF4444));
    final label = isActive ? 'Active' : 'Inactive';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _statusPulse,
            builder: (context, child) {
              final scale = 0.85 + (_statusPulse.value * 0.35);
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: textColor,
                boxShadow: [
                  BoxShadow(
                    color: textColor.withValues(alpha: 0.35),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _memberTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'additional_director':
        return 'Additional Director';
      case 'joint_director':
        return 'Joint Director';
      case 'deputy_director':
        return 'Deputy Director';
      case 'assistant_commissioner':
        return 'Assistant Commissioner';
      case 'state_tax_officer':
        return 'State Tax Officer';
      case 'assistant':
        return 'Assistant';
      case 'faculty':
        return 'Faculty';
      case 'staff':
        return 'Staff';
      case 'guest':
        return 'Guest';
      default:
        return 'Student';
    }
  }

  Widget _buildTypeChip(String type) {
    final chipInfo = _getTypeChipInfo(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      constraints: const BoxConstraints(maxWidth: 115),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            chipInfo.color.withValues(alpha: 0.12),
            chipInfo.color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipInfo.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chipInfo.icon, size: 14, color: chipInfo.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              chipInfo.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: chipInfo.color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  ({IconData icon, Color color, String label}) _getTypeChipInfo(String type) {
    switch (type.toLowerCase()) {
      case 'additional_director':
        return (icon: Icons.apartment, color: const Color(0xFF8B5CF6), label: 'Additional Director');
      case 'joint_director':
        return (icon: Icons.apartment_outlined, color: const Color(0xFFA855F7), label: 'Joint Director');
      case 'deputy_director':
        return (icon: Icons.badge, color: const Color(0xFFEC4899), label: 'Deputy Director');
      case 'assistant_commissioner':
        return (icon: Icons.account_balance, color: const Color(0xFF14B8A6), label: 'Assistant Commissioner');
      case 'state_tax_officer':
        return (icon: Icons.account_balance_wallet, color: const Color(0xFF22C55E), label: 'State Tax Officer');
      case 'assistant':
        return (icon: Icons.person, color: const Color(0xFFF59E0B), label: 'Assistant');
      case 'faculty':
        return (icon: Icons.school, color: const Color(0xFF3B82F6), label: 'Faculty');
      case 'staff':
        return (icon: Icons.work, color: const Color(0xFF10B981), label: 'Staff');
      case 'guest':
        return (icon: Icons.person_outline, color: const Color(0xFF6366F1), label: 'Guest');
      default:
        return (icon: Icons.menu_book, color: const Color(0xFF3B82F6), label: 'Student');
    }
  }

  Widget _buildBorrowCountBadge(Member member) {
    final count = member.borrowCount;
    final maxBooks = member.maxBooks;
    final ratio = maxBooks > 0 ? count / maxBooks : 0.0;
    final badgeColor = count >= maxBooks
        ? const Color(0xFFEF4444)
        : (ratio > 0.5 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
    final badgeIcon = count >= maxBooks
        ? Icons.library_books
        : (ratio > 0.5 ? Icons.menu_book : Icons.book);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: count > 0 ? () => _showBorrowedBooks(member) : null,
        borderRadius: BorderRadius.circular(12),
        hoverColor: badgeColor.withValues(alpha: 0.15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints: const BoxConstraints(maxWidth: 78),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              badgeColor.withValues(alpha: 0.12),
              badgeColor.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: badgeColor.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badgeIcon, size: 13, color: badgeColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$count/$maxBooks',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
                overflow: TextOverflow.ellipsis,
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

  Future<void> _deleteSelectedMembers() async {
    final ids = _selectedMemberIds.toList()..sort();
    if (ids.isEmpty) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final memberProvider = context.read<MemberProvider>();
    final issueProvider = context.read<IssueProvider>();

    final confirmed = await showPremiumConfirm(
      context: context,
      icon: Icons.delete_sweep_rounded,
      title: 'Delete selected members',
      message: 'Delete ${ids.length} selected member(s)? This action cannot be undone.',
      confirmLabel: 'Delete',
      confirmIcon: Icons.delete_outline_rounded,
      destructive: true,
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
        SnackBar(
          content: Text('Deleted $deletedCount member(s) successfully.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      navigator.maybePop();
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(getOperationErrorMessage('Bulk delete', e)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _deleteMember(int id) {
    final memberProvider = context.read<MemberProvider>();
    final issueProvider = context.read<IssueProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final cs = Theme.of(context).colorScheme;
    () async {
      final confirmed = await showPremiumConfirm(
        context: context,
        icon: Icons.person_remove_rounded,
        title: 'Delete Member',
        message: 'Are you sure you want to delete this member? This action cannot be undone.',
        confirmLabel: 'Delete',
        confirmIcon: Icons.delete_outline_rounded,
        destructive: true,
      );
      if (confirmed != true || !mounted) return;
      try {
        await memberProvider.deleteMember(id);
        await memberProvider.loadMembers();
        await issueProvider.loadStats();
        if (mounted) {
          messenger.clearSnackBars();
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Member deleted successfully'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          messenger.clearSnackBars();
          messenger.showSnackBar(
            SnackBar(
              content: Text(getOperationErrorMessage('Delete member', e)),
              backgroundColor: cs.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }();
  }
}

class _ActionIconButton extends StatefulWidget {
  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.backgroundColor,
    required this.hoverColor,
    required this.borderColor,
    required this.iconColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color hoverColor;
  final Color borderColor;
  final Color iconColor;

  @override
  State<_ActionIconButton> createState() => _ActionIconButtonState();
}

class _ActionIconButtonState extends State<_ActionIconButton> {
  bool _hovered = false;
  static const _duration = Duration(milliseconds: 150);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: _hovered ? 1.05 : 1.0,
          duration: _duration,
          curve: Curves.easeInOut,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: _duration,
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      _hovered ? widget.hoverColor : widget.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: widget.borderColor),
                ),
                child: Icon(
                  widget.icon,
                  size: 18,
                  color: widget.iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
