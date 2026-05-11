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
        height = MediaQuery.of(context).size.height;

  Responsive.fromConstraints(BoxConstraints constraints)
      : width = constraints.maxWidth,
        height = constraints.maxHeight;

  final double width;
  final double height;

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
    return 1400;
  }

  /// Card dimensions for responsive grids
  double cardWidth(int itemsPerRow) {
    final availableWidth = width - (pagePadding * 2);
    return (availableWidth - (12 * (itemsPerRow - 1))) / itemsPerRow;
  }

  /// Constrains a dialog width to a reasonable max based on screen size.
  double dialogWidth({double maxDesktop = 520}) {
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
}
