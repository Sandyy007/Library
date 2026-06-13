import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Wraps a child so it scales down slightly when pressed and back up
/// on release. Gives buttons a tactile "click" feel that pure
/// Material 3 ripple doesn't quite deliver.
///
/// The animation runs on the Flutter scheduler (not a separate Ticker)
/// so it doesn't allocate a Ticker per instance and is safe to use
/// inside list items.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final Duration duration;
  final HitTestBehavior behavior;
  final bool enabled;

  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.duration = const Duration(milliseconds: 120),
    this.behavior = HitTestBehavior.opaque,
    this.enabled = true,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (!widget.enabled) return;
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    if (!widget.enabled || (widget.onTap == null && widget.onLongPress == null)) {
      return child;
    }
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }
}

/// A frosted-glass panel: a translucent surface with a subtle blur of
/// whatever is behind it. Use sparingly (e.g. for command palette,
/// side-panels, or floating toolbars) - too much blur and the UI
/// becomes visually noisy.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Border? border;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 16,
    this.blur = 16,
    this.opacity = 0.7,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.black : Colors.white;
    final tint = base.withValues(alpha: opacity);

    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ??
                  Border.all(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.08),
                  ),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
