/// Shared responsive breakpoints and helper utilities.
library;

import 'package:flutter/widgets.dart';

/// Standardised breakpoint thresholds used across the app.
abstract final class Breakpoints {
  /// Phones / very narrow windows.
  static const double compact = 600;

  /// Small tablets / narrow desktop windows.
  static const double medium = 900;

  /// Full-size desktops / wide monitors.
  static const double expanded = 1200;

  /// Ultra-wide monitors.
  static const double extraExpanded = 1600;

  /// Minimum card width for responsive grids
  static const double minCardWidth = 160;

  /// Sidebar width
  static const double sidebarWidth = 280;
  static const double sidebarCollapsedWidth = 72;

  /// Below this width use a drawer instead of inline sidebar
  static const double sidebarDrawerThreshold = 500;

  /// Data table breakpoints
  static const double tableCompact = 600;
  static const double tableMedium = 900;
  static const double tableExpanded = 1200;
  static const double tableExtraExpanded = 1300;
}

/// Lightweight helper that derives common flags from screen width.
///
/// Usage:
/// ```dart
/// final r = Responsive(context);
/// if (r.isCompact) ...
/// ```
class Responsive {
  Responsive(BuildContext context)
      : width = MediaQuery.of(context).size.width,
        height = MediaQuery.of(context).size.height,
        orientation = MediaQuery.of(context).orientation;

  Responsive.fromConstraints(BoxConstraints constraints)
      : width = constraints.maxWidth,
        height = constraints.maxHeight,
        orientation = constraints.maxWidth > constraints.maxHeight 
            ? Orientation.landscape 
            : Orientation.portrait;

  final double width;
  final double height;
  final Orientation orientation;

  /// < 600 px - Phone
  bool get isCompact => width < Breakpoints.compact;

  /// < 900 px - Tablet
  bool get isMedium => width < Breakpoints.medium;

  /// 600-899 px - Small desktop
  bool get isSmallDesktop => width >= Breakpoints.compact && width < Breakpoints.medium;

  /// ≥ 1200 px - Full desktop
  bool get isExpanded => width >= Breakpoints.expanded;

  /// ≥ 1600 px - Ultra-wide
  bool get isExtraExpanded => width >= Breakpoints.extraExpanded;

  /// Check if sidebar should be collapsed
  bool get shouldCollapseSidebar => width < Breakpoints.medium;

  /// Adaptive outer padding.
  double get pagePadding {
    if (isCompact) return 8;
    if (isMedium) return 14;
    if (isExpanded) return 24;
    return 20;
  }

  /// Adaptive toolbar inner padding.
  double get toolbarPaddingH {
    if (isCompact) return 8;
    if (isMedium) return 12;
    return 16;
  }

  /// Adaptive content max width
  double get contentMaxWidth {
    if (isCompact) return width * 0.98;
    if (isMedium) return width * 0.9;
    if (isExtraExpanded) return 1800;
    if (isExpanded) return 1400;
    return width;
  }

  /// Card dimensions for responsive grids
  double cardWidth(int itemsPerRow) {
    final availableWidth = width - (pagePadding * 2);
    return (availableWidth - (12 * (itemsPerRow - 1))) / itemsPerRow;
  }

  /// Constrains a dialog width to a reasonable max based on screen size.
  double dialogWidth({double maxDesktop = 600}) {
    if (isCompact) return width * 0.92;
    if (isMedium) return width * 0.7;
    return maxDesktop.clamp(300, width * 0.8);
  }

  /// Returns symmetric horizontal padding for dialog content.
  EdgeInsets get dialogPadding => EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 20,
        vertical: isCompact ? 12 : 16,
      );

  /// Grid columns based on screen width
  int get gridColumns {
    if (isCompact) return 2;
    if (isMedium) return 3;
    if (isExpanded) return 5;
    return 4;
  }

  /// Sidebar width in expanded vs collapsed states.
  bool get sidebarShouldExpand => width >= Breakpoints.medium;
  double get sidebarExpandedWidth => Breakpoints.sidebarWidth;
  double get sidebarCollapsedWidth => Breakpoints.sidebarCollapsedWidth;

  /// Statistics card width for dashboard hero.
  double get statCardMinWidth {
    if (isCompact) return 140;
    if (isMedium) return 160;
    return 180;
  }

  /// Number of stat cards per row in dashboard.
  int get statCardsPerRow {
    if (isCompact) return 2;
    if (isMedium) return 3;
    if (isExtraExpanded) return 5;
    if (isExpanded) return 4;
    return 4;
  }

  /// Title font size scale (used by hero / large headers).
  double get titleScale {
    if (isCompact) return 0.9;
    if (isMedium) return 1.0;
    if (isExtraExpanded) return 1.15;
    if (isExpanded) return 1.08;
    return 1.08;
  }

  /// Responsive form field spacing
  double get formFieldSpacing {
    if (isCompact) return 12;
    if (isMedium) return 16;
    return 20;
  }

  /// Responsive form label spacing
  double get formLabelSpacing {
    if (isCompact) return 4;
    if (isMedium) return 6;
    return 8;
  }

  /// Responsive input height
  double get inputHeight {
    if (isCompact) return 44;
    if (isMedium) return 48;
    return 52;
  }

  /// Responsive button height
  double get buttonHeight {
    if (isCompact) return 44;
    if (isMedium) return 48;
    return 52;
  }

  /// Data table column visibility helpers
  bool get tableShowAllColumns => width >= Breakpoints.tableExtraExpanded;
  bool get tableShowExtendedColumns => width >= Breakpoints.tableExpanded;
  bool get tableShowMediumColumns => width >= Breakpoints.tableMedium;
  bool get tableShowBasicColumns => width >= Breakpoints.tableCompact;

  /// Optimal data table column count
  int get tableColumnCount {
    if (isCompact) return 4;
    if (isMedium) return 6;
    if (isExpanded) return 8;
    return 10;
  }

  /// Data table horizontal padding
  double get tableHorizontalPadding {
    if (isCompact) return 8;
    if (isMedium) return 12;
    return 16;
  }

  /// Data table row height
  double get tableRowHeight {
    if (isCompact) return 48;
    if (isMedium) return 52;
    return 56;
  }

  /// Whether to use card-based layout instead of table
  bool get useCardLayout => isCompact;

  /// Card aspect ratio for responsive grids
  double get cardAspectRatio {
    if (isCompact) return 1.0;
    if (isMedium) return 1.1;
    return 1.2;
  }

  /// Search bar max width
  double get searchBarMaxWidth {
    if (isCompact) return width * 0.9;
    if (isMedium) return 400;
    if (isExpanded) return 480;
    return 440;
  }

  /// App bar height
  double get appBarHeight {
    if (isCompact) return 72;
    if (isMedium) return 64;
    return 56;
  }

  /// Orientation helpers
  bool get isPortrait => orientation == Orientation.portrait;
  bool get isLandscape => orientation == Orientation.landscape;

  /// Whether device is in landscape on tablets (medium-sized screens)
  bool get isTabletLandscape => isMedium && isLandscape;

  /// Whether device is in landscape on phones
  bool get isPhoneLandscape => isCompact && isLandscape;

  /// Adaptive padding for landscape orientation
  double get landscapeAdjustedPadding {
    if (isLandscape && isMedium) return pagePadding * 1.5;
    if (isPhoneLandscape) return pagePadding * 0.8;
    return pagePadding;
  }

  /// Aspect ratio adjustments for landscape
  double get landscapeCardAspectRatio {
    if (isTabletLandscape) return 1.5;
    if (isPhoneLandscape) return 2.0;
    return cardAspectRatio;
  }
}

/// Wraps a child in a horizontally-centered, max-width-clamped container
/// so ultra-wide monitors don't stretch a single-column layout across
/// the entire screen. Use as the outermost widget of any screen body.
class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final bool center;
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 1600,
    this.padding = EdgeInsets.zero,
    this.center = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive.fromConstraints(constraints);
        final width = constraints.maxWidth.clamp(0.0, r.contentMaxWidth);
        final body = Padding(padding: padding, child: child);
        if (!center) return SizedBox(width: width, child: body);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: width, child: body),
        );
      },
    );
  }
}

/// A grid that picks its `crossAxisCount` based on the available width
/// and a minimum cell size, the same pattern Material 3 uses for the
/// settings tiles. Wrap children with [SliverGridDelegateWithMaxCrossAxisExtent].
class ResponsiveGrid extends StatelessWidget {
  final double minCellWidth;
  final double spacing;
  final double childAspectRatio;
  final List<Widget> children;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minCellWidth = 280,
    this.spacing = 16,
    this.childAspectRatio = 1.1,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / (minCellWidth + spacing)).floor();
        final n = cols < 1 ? 1 : cols;
        return GridView.count(
          crossAxisCount: n,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: childAspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}
