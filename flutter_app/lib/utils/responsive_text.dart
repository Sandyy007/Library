import 'package:flutter/material.dart';
import 'responsive.dart';

/// Responsive text scaling utilities for adaptive font sizes across devices.
/// 
/// These helpers ensure consistent text sizing based on screen dimensions.
/// Usage:
/// ```dart
/// final responsive = Responsive(context);
/// Text('Hello', style: responsive.displayLarge)
/// ```
extension ResponsiveTextScaling on Responsive {
  /// Scale factor for typography (1.0 = base, scales from 0.8 to 1.2)
  double get textScale {
    if (isCompact) return 0.85;
    if (isMedium) return 0.95;
    if (isExtraExpanded) return 1.15;
    if (isExpanded) return 1.05;
    return 1.0;
  }

  /// Display Large (used for major headings)
  /// Base: 57px on desktop, scales responsively
  TextStyle displayLarge(BuildContext context) {
    final base = Theme.of(context).textTheme.displayLarge ?? const TextStyle();
    return base.copyWith(
      fontSize: (base.fontSize ?? 57) * textScale,
    );
  }

  /// Display Medium
  /// Base: 45px on desktop
  TextStyle displayMedium(BuildContext context) {
    final base = Theme.of(context).textTheme.displayMedium ?? const TextStyle();
    return base.copyWith(
      fontSize: (base.fontSize ?? 45) * textScale,
    );
  }

  /// Display Small
  /// Base: 36px on desktop
  TextStyle displaySmall(BuildContext context) {
    final base = Theme.of(context).textTheme.displaySmall ?? const TextStyle();
    return base.copyWith(
      fontSize: (base.fontSize ?? 36) * textScale,
    );
  }

  /// Headline Large (page titles)
  /// Base: 32px on desktop
  TextStyle headlineLarge(BuildContext context) {
    final base = Theme.of(context).textTheme.headlineLarge ?? const TextStyle();
    return base.copyWith(
      fontSize: (base.fontSize ?? 32) * textScale,
    );
  }

  /// Headline Medium (section headers)
  /// Base: 28px on desktop
  TextStyle headlineMedium(BuildContext context) {
    final base = Theme.of(context).textTheme.headlineMedium ?? const TextStyle();
    return base.copyWith(
      fontSize: (base.fontSize ?? 28) * textScale,
    );
  }

  /// Headline Small (subsection headers)
  /// Base: 24px on desktop
  TextStyle headlineSmall(BuildContext context) {
    final base = Theme.of(context).textTheme.headlineSmall ?? const TextStyle();
    return base.copyWith(
      fontSize: (base.fontSize ?? 24) * textScale,
    );
  }

  /// Title Large (important labels)
  /// Base: 22px on desktop
  TextStyle titleLarge(BuildContext context) {
    final base = Theme.of(context).textTheme.titleLarge ?? const TextStyle();
    return base.copyWith(
      fontSize: (base.fontSize ?? 22) * textScale,
    );
  }

  /// Title Medium (dialog titles, tab labels)
  /// Base: 16px on desktop
  TextStyle titleMedium(BuildContext context) {
    final base = Theme.of(context).textTheme.titleMedium ?? const TextStyle();
    return base.copyWith(
      fontSize: (base.fontSize ?? 16) * textScale,
    );
  }

  /// Title Small (card titles)
  /// Base: 14px on desktop
  TextStyle titleSmall(BuildContext context) {
    final base = Theme.of(context).textTheme.titleSmall ?? const TextStyle();
    return base.copyWith(
      fontSize: (base.fontSize ?? 14) * textScale,
    );
  }

  /// Body Large (main content text)
  /// Base: 16px on desktop
  TextStyle bodyLarge(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge ?? const TextStyle();
    return base.copyWith(
      fontSize: (base.fontSize ?? 16) * textScale,
    );
  }

  /// Body Medium (standard body text)
  /// Base: 14px on desktop
  TextStyle bodyMedium(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    return base.copyWith(
      fontSize: (base.fontSize ?? 14) * textScale,
    );
  }

  /// Body Small (fine print, hints)
  /// Base: 12px on desktop
  TextStyle bodySmall(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall ?? const TextStyle();
    return base.copyWith(
      fontSize: (base.fontSize ?? 12) * textScale,
    );
  }

  /// Label Large (prominent labels)
  /// Base: 14px on desktop
  TextStyle labelLarge(BuildContext context) {
    final base = Theme.of(context).textTheme.labelLarge ?? const TextStyle();
    return base.copyWith(
      fontSize: (base.fontSize ?? 14) * textScale,
    );
  }

  /// Label Medium (standard labels)
  /// Base: 12px on desktop
  TextStyle labelMedium(BuildContext context) {
    final base = Theme.of(context).textTheme.labelMedium ?? const TextStyle();
    return base.copyWith(
      fontSize: (base.fontSize ?? 12) * textScale,
    );
  }

  /// Label Small (small labels, tags)
  /// Base: 11px on desktop
  TextStyle labelSmall(BuildContext context) {
    final base = Theme.of(context).textTheme.labelSmall ?? const TextStyle();
    return base.copyWith(
      fontSize: (base.fontSize ?? 11) * textScale,
    );
  }

  /// Custom responsive text style with optional size multiplier
  TextStyle customTextStyle(
    BuildContext context, {
    required double fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? lineHeight,
    TextDecoration? decoration,
    TextDecorationStyle? decorationStyle,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontSize: fontSize * textScale,
      fontWeight: fontWeight,
      color: color,
      height: lineHeight,
      decoration: decoration,
      decorationStyle: decorationStyle,
      letterSpacing: letterSpacing,
    );
  }
}

/// Responsive text widget with automatic scaling
class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle Function(Responsive responsive, BuildContext context) styleBuilder;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ResponsiveText(
    this.text, {
    super.key,
    required this.styleBuilder,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive(context);
    return Text(
      text,
      style: styleBuilder(responsive, context),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
