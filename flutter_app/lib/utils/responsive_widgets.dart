import 'package:flutter/material.dart';
import 'responsive.dart';

/// Responsive image containers with adaptive sizing and aspect ratios.
/// 
/// These widgets help ensure images scale properly across different screen sizes
/// and maintain proper aspect ratios for different content types.

/// Book cover image container - maintains 3:4 aspect ratio
class ResponsiveBookCover extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BoxDecoration? decoration;
  final BorderRadius borderRadius;

  const ResponsiveBookCover({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(4),
    this.decoration,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        padding: padding,
        decoration: decoration,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: child,
        ),
      ),
    );
  }
}

/// Responsive thumbnail image - square aspect ratio
class ResponsiveThumbnail extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BoxDecoration? decoration;
  final BorderRadius borderRadius;
  final double? size;

  const ResponsiveThumbnail({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(2),
    this.decoration,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive(context);
    final containerSize = size ?? (responsive.isCompact ? 60.0 : 80.0);

    return SizedBox(
      width: containerSize,
      height: containerSize,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          padding: padding,
          decoration: decoration,
          child: ClipRRect(
            borderRadius: borderRadius,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Responsive hero/banner image - maintains 16:9 aspect ratio
class ResponsiveHeroImage extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BoxDecoration? decoration;
  final BorderRadius borderRadius;

  const ResponsiveHeroImage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(8),
    this.decoration,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        padding: padding,
        decoration: decoration,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: child,
        ),
      ),
    );
  }
}

/// Responsive square card image container
class ResponsiveCardImage extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BoxDecoration? decoration;
  final BorderRadius borderRadius;

  const ResponsiveCardImage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(6),
    this.decoration,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: padding,
        decoration: decoration,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: child,
        ),
      ),
    );
  }
}

/// Generic responsive image wrapper with custom aspect ratio
class ResponsiveImage extends StatelessWidget {
  final Widget child;
  final double aspectRatio;
  final EdgeInsetsGeometry padding;
  final BoxDecoration? decoration;
  final BorderRadius borderRadius;
  final double? maxHeight;
  final double? maxWidth;

  const ResponsiveImage({
    super.key,
    required this.child,
    required this.aspectRatio,
    this.padding = const EdgeInsets.all(4),
    this.decoration,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.maxHeight,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: maxHeight ?? double.infinity,
          maxWidth: maxWidth ?? double.infinity,
        ),
        padding: padding,
        decoration: decoration,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: child,
        ),
      ),
    );
  }
}

/// Responsive grid item with adaptive sizing based on screen width
class ResponsiveGridItem extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BoxDecoration? decoration;

  const ResponsiveGridItem({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(8),
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive(context);
    final aspect = responsive.landscapeCardAspectRatio;

    return Container(
      padding: padding,
      decoration: decoration,
      child: AspectRatio(
        aspectRatio: aspect,
        child: child,
      ),
    );
  }
}

/// Responsive card wrapper with adaptive padding and elevation
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? shadowColor;
  final double? elevation;
  final BorderRadius? borderRadius;
  final GestureTapCallback? onTap;

  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.shadowColor,
    this.elevation,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive(context);
    final effectivePadding = padding ?? EdgeInsets.all(responsive.pagePadding);
    final effectiveMargin = margin ?? EdgeInsets.all(responsive.pagePadding / 2);
    final effectiveElevation = elevation ?? 2.0;
    final effectiveRadius = borderRadius ?? BorderRadius.circular(12);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: color,
        shadowColor: shadowColor,
        elevation: effectiveElevation,
        shape: RoundedRectangleBorder(borderRadius: effectiveRadius),
        margin: effectiveMargin,
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );
  }
}
