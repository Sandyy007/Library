import 'package:flutter/material.dart';
import '../utils/theme.dart';
import 'press_scale.dart';

/// A primary call-to-action button with a subtle gradient fill, a soft colored
/// glow, and a tactile press-scale. Use for the single most important action
/// on a screen (Save, Login, Add). Secondary actions should stay as plain
/// [OutlinedButton]/[TextButton] so the hierarchy reads clearly.
///
/// Falls back to a flat, disabled-looking style when [onPressed] is null.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.height = 46,
    this.gradientColors,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// When true the button stretches to fill its parent's width.
  final bool expand;

  /// Shows a spinner and blocks taps while an async action is in flight.
  final bool loading;

  final double height;

  /// Optional custom gradient. Defaults to a primary -> primary-tinted sweep.
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onPressed != null && !loading;

    final colors = gradientColors ??
        [
          cs.primary,
          Color.lerp(cs.primary, cs.secondary, 0.45) ?? cs.primary,
        ];

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        enabled: enabled,
        onTap: enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          height: height,
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: enabled
                  ? colors
                  : [
                      cs.outline.withValues(alpha: 0.35),
                      cs.outline.withValues(alpha: 0.35),
                    ],
            ),
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: colors.first.withValues(alpha: isDark ? 0.45 : 0.32),
                      blurRadius: 16,
                      spreadRadius: -2,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }
}
