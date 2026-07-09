import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Fades and slides a child upward into place once, on first build. Unlike the
/// dashboard's controller-driven entrance, this is fully self-contained (it
/// uses an implicit [TweenAnimationBuilder]), so any screen can drop it around
/// a widget without wiring up an [AnimationController].
///
/// For lists/grids, pass the item's [index] and a per-item [stagger] delay so
/// items cascade in rather than appearing all at once:
///
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, i) => StaggeredReveal(
///     index: i,
///     child: MyCard(items[i]),
///   ),
/// )
/// ```
class StaggeredReveal extends StatefulWidget {
  const StaggeredReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.stagger = const Duration(milliseconds: 45),
    this.duration = AppDurations.slow,
    this.maxStaggerItems = 12,
    this.offsetY = 14,
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;

  /// Position of this item within its list; drives the entrance delay.
  final int index;

  /// Delay added per [index] before this item starts animating.
  final Duration stagger;

  /// Duration of the fade + slide for a single item.
  final Duration duration;

  /// Caps the cumulative stagger so long lists don't wait seconds to finish.
  final int maxStaggerItems;

  /// How far (logical px) the child slides up into place.
  final double offsetY;

  final Curve curve;

  @override
  State<StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<StaggeredReveal> {
  double _t = 0; // 0 = hidden, 1 = fully revealed

  @override
  void initState() {
    super.initState();
    final steps = widget.index.clamp(0, widget.maxStaggerItems);
    final delay = widget.stagger * steps;
    // Kick off after the initial frame so the tween animates from 0 -> 1.
    Future.delayed(delay, () {
      if (mounted) setState(() => _t = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: _t),
      duration: widget.duration,
      curve: widget.curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * widget.offsetY),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
