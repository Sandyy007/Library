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

  /// < 600 px
  bool get isCompact => width < Breakpoints.compact;

  /// < 900 px
  bool get isMedium => width < Breakpoints.medium;

  /// ≥ 1200 px
  bool get isExpanded => width >= Breakpoints.expanded;

  /// ≥ 1600 px
  bool get isExtraExpanded => width >= Breakpoints.extraExpanded;

  /// Adaptive outer padding.
  double get pagePadding => isCompact ? 8 : (isMedium ? 14 : 20);

  /// Adaptive toolbar inner padding.
  double get toolbarPaddingH => isCompact ? 8 : 16;

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
}
