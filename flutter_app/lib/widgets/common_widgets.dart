import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../utils/color_extensions.dart';
import '../utils/theme.dart';
import 'gradient_button.dart';

/// Network image with on-disk + in-memory caching (via cached_network_image)
/// and a graceful fade-in. Use this everywhere instead of `Image.network` so
/// book covers and member photos served from the backend `uploads/` folder
/// aren't re-downloaded and re-decoded on every rebuild/scroll.
///
/// [errorWidget] is shown both on load failure and as the placeholder while
/// loading, so callers get a single consistent fallback (their existing
/// placeholder) without a spinner flashing inside tiny avatars/thumbnails.
class AppCachedImage extends StatelessWidget {
  const AppCachedImage({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String url;

  /// Shown while loading and on error (callers pass their own placeholder).
  final Widget fallback;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// Cap the decoded bitmap size in memory. Set to the rendered pixel size
  /// (logical * devicePixelRatio) for thumbnails to cut memory + decode cost.
  final int? memCacheWidth;
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (context, _) => fallback,
      errorWidget: (context, _, _) => fallback,
    );
  }
}


/// Reusable status badge with dot indicator, border, and themed colors.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 11,
  });

  /// Pre-built active/inactive badge
  factory StatusBadge.active(bool isActive) {
    return StatusBadge(
      label: isActive ? 'Active' : 'Inactive',
      color: isActive ? Colors.green : Colors.red,
    );
  }

  /// Pre-built book availability badge
  factory StatusBadge.bookStatus(int availableCopies) {
    return StatusBadge(
      label: availableCopies > 0 ? 'Available' : 'Borrowed',
      color: availableCopies > 0 ? Colors.green : Colors.orange,
    );
  }

  /// Pre-built issue status badge
  factory StatusBadge.issueStatus(String status) {
    Color c;
    switch (status.toLowerCase()) {
      case 'returned':
        c = Colors.green;
        break;
      case 'overdue':
        c = Colors.red;
        break;
      default:
        c = Colors.orange;
    }
    return StatusBadge(
      label: status.isNotEmpty
          ? status[0].toUpperCase() + status.substring(1)
          : status,
      color: c,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

/// Member type badge with icon and themed color.
class TypeBadge extends StatelessWidget {
  final String memberType;

  const TypeBadge({super.key, required this.memberType});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color color;
    IconData icon;
    String label;
    switch (memberType.toLowerCase()) {
      case 'additional_director':
        color = cs.faculty;
        icon = Icons.apartment;
        label = 'Additional Director';
        break;
      case 'joint_director':
        color = cs.faculty;
        icon = Icons.apartment_outlined;
        label = 'Joint Director';
        break;
      case 'deputy_director':
        color = cs.faculty;
        icon = Icons.badge;
        label = 'Deputy Director';
        break;
      case 'assistant_commissioner':
        color = cs.staff;
        icon = Icons.account_balance;
        label = 'Assistant Commissioner';
        break;
      case 'state_tax_officer':
        color = cs.staff;
        icon = Icons.account_balance_wallet;
        label = 'State Tax Officer';
        break;
      case 'assistant':
        color = cs.staff;
        icon = Icons.person;
        label = 'Assistant';
        break;
      case 'faculty':
        color = cs.faculty;
        icon = Icons.school;
        label = 'Faculty';
        break;
      case 'staff':
        color = cs.staff;
        icon = Icons.work;
        label = 'Staff';
        break;
      case 'guest':
        color = cs.guest;
        icon = Icons.person_outline;
        label = 'Guest';
        break;
      default:
        color = cs.student;
        icon = Icons.menu_book;
        label = 'Student';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

/// Borrow count badge with tap-to-view behavior.
class CountBadge extends StatelessWidget {
  final int current;
  final int max;
  final VoidCallback? onTap;

  const CountBadge({
    super.key,
    required this.current,
    required this.max,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAtLimit = current >= max;
    final isNearLimit = current >= max - 1;

    Color badgeColor;
    if (isAtLimit) {
      badgeColor = Colors.red;
    } else if (isNearLimit) {
      badgeColor = Colors.orange;
    } else if (current > 0) {
      badgeColor = Colors.blue;
    } else {
      badgeColor = Colors.grey;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Tooltip(
        message: current > 0
            ? 'Click to view borrowed books ($current/$max)'
            : 'No books borrowed (0/$max)',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book, size: 12, color: badgeColor),
              const SizedBox(width: 4),
              Text(
                '$current/$max',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer placeholder for loading states.
class ShimmerBlock extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBlock({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? const Color(0xFF2C2E3C) : const Color(0xFFE2E8F0);
    final highlightColor =
        isDark ? const Color(0xFF3F4260) : const Color(0xFFF1F5F9);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// A table-row shimmer placeholder.
class ShimmerTableRow extends StatelessWidget {
  final int columns;
  final double height;

  const ShimmerTableRow({super.key, this.columns = 6, this.height = 55});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: List.generate(columns, (i) {
          final flex = i == 1 ? 3 : (i == 2 ? 2 : 1);
          return Expanded(
            flex: flex,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ShimmerBlock(
                width: double.infinity,
                height: i == 0 ? 36 : 16,
                borderRadius: i == 0 ? 18 : 4,
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Full shimmer loading placeholder for tables.
class ShimmerTable extends StatelessWidget {
  final int rows;
  final int columns;

  const ShimmerTable({super.key, this.rows = 8, this.columns = 6});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header shimmer
        Container(
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: List.generate(
              columns,
              (i) => Expanded(
                flex: i == 1 ? 3 : (i == 2 ? 2 : 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ShimmerBlock(
                    width: double.infinity,
                    height: 12,
                    borderRadius: 4,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Row shimmers
        ...List.generate(rows, (_) => ShimmerTableRow(columns: columns)),
      ],
    );
  }
}

/// Animated number counter for dashboard stat cards.
class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  final TextAlign? textAlign;

  /// When true (default) large numbers are grouped with thousands
  /// separators, e.g. 4210 -> "4,210", for a more polished read.
  final bool useGrouping;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.textAlign,
    this.useGrouping = true,
  });

  static final NumberFormat _grouped = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        // Tabular figures keep every digit the same width, so the number
        // doesn't shift/jitter horizontally as it counts up.
        final effectiveStyle = (style ?? const TextStyle()).copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        );
        return Text(
          useGrouping ? _grouped.format(animatedValue) : animatedValue.toString(),
          style: effectiveStyle,
          textAlign: textAlign,
        );
      },
    );
  }
}

/// Consistent card wrapper for content pages.
class ContentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? margin;

  const ContentCard({super.key, required this.child, this.margin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.2),
        ),
        boxShadow: AppShadows.sm(cs.shadow, isDark),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Empty state widget with icon, title, subtitle, and optional action button.
class EmptyStateWidget extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onAction,
    this.actionLabel,
  });

  @override
  State<EmptyStateWidget> createState() => _EmptyStateWidgetState();
}

class _EmptyStateWidgetState extends State<EmptyStateWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _bounceAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _bounceAnimation.value),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        cs.primary.withValues(alpha: 0.15),
                        cs.secondary.withValues(alpha: 0.10),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 48,
                    color: cs.primary.withValues(alpha: 0.6),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),

          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
          if (widget.onAction != null) ...[
            const SizedBox(height: 24),
            GradientButton(
              onPressed: widget.onAction,
              icon: Icons.refresh_rounded,
              label: widget.actionLabel ?? 'Retry',
            ),
          ],
        ],
      ),
    );
  }
}

/// Pre-built empty states for the most common screens. Saves the call
/// site from re-typing the same copy and keeps a consistent voice across
/// the app.
extension EmptyStatePresets on EmptyStateWidget {
  static Widget noBooks({VoidCallback? onAdd}) => EmptyStateWidget(
        icon: Icons.menu_book_outlined,
        title: 'No books yet',
        subtitle:
            'Add your first book to start building the library catalogue. '
            'You can import from CSV or add one at a time.',
        actionLabel: 'Add a book',
        onAction: onAdd,
      );

  static Widget noMembers({VoidCallback? onAdd}) => EmptyStateWidget(
        icon: Icons.people_outline,
        title: 'No members yet',
        subtitle:
            'Register a member to start tracking who is borrowing from '
            'the library.',
        actionLabel: 'Add a member',
        onAction: onAdd,
      );

  static Widget noIssues({VoidCallback? onIssue}) => EmptyStateWidget(
        icon: Icons.assignment_outlined,
        title: 'No issues recorded',
        subtitle:
            'When a member borrows a book, the issue will show up here. '
            'Issue a book to get started.',
        actionLabel: 'Issue a book',
        onAction: onIssue,
      );

  static Widget noSearchResults({VoidCallback? onClear}) => EmptyStateWidget(
        icon: Icons.search_off,
        title: 'No results found',
        subtitle: 'Try adjusting your search or filters to find what '
            'you are looking for.',
        actionLabel: 'Clear filters',
        onAction: onClear,
      );

  static Widget noNotifications() => const EmptyStateWidget(
        icon: Icons.notifications_none,
        title: 'You are all caught up',
        subtitle:
            'New notifications will appear here when something happens '
            'in the library.',
      );
}

/// Truncated text cell with automatic tooltip on overflow.
class TruncatedTextCell extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;

  const TruncatedTextCell({
    super.key,
    required this.text,
    this.style,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveStyle =
            style ?? DefaultTextStyle.of(context).style;
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: effectiveStyle),
          maxLines: maxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final isOverflowing = textPainter.didExceedMaxLines;

        final textWidget = Text(
          text,
          style: effectiveStyle,
          overflow: TextOverflow.ellipsis,
          maxLines: maxLines,
        );

        if (isOverflowing) {
          return Tooltip(
            message: text,
            waitDuration: const Duration(milliseconds: 500),
            child: textWidget,
          );
        }
        return textWidget;
      },
    );
  }
}

/// Relative time formatter ("2 hours ago", "Yesterday", etc.)
String formatRelativeTime(String? dateTimeStr) {
  if (dateTimeStr == null || dateTimeStr.isEmpty) return '';
  try {
    final dt = DateTime.parse(dateTimeStr);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h ${h == 1 ? 'hour' : 'hours'} ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) {
      final w = (diff.inDays / 7).floor();
      return '$w ${w == 1 ? 'week' : 'weeks'} ago';
    }
    if (diff.inDays < 365) {
      final mo = (diff.inDays / 30).floor();
      return '$mo ${mo == 1 ? 'month' : 'months'} ago';
    }
    final y = (diff.inDays / 365).floor();
    return '$y ${y == 1 ? 'year' : 'years'} ago';
  } catch (_) {
    return dateTimeStr;
  }
}

/// Standardized alert card with icon, title, subtitle, trailing badge,
/// optional overdue warning, and a row of action buttons.
class AlertCard extends StatefulWidget {
  const AlertCard({
    super.key,
    required this.color,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.overdueWarning,
    this.actions = const [],
    this.onTap,
  });

  final Color color;
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? overdueWarning;
  final List<Widget> actions;
  final VoidCallback? onTap;

  @override
  State<AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<AlertCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOverdue = widget.overdueWarning != null;
    final color = widget.color;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.surfaceContainerHighest.withValues(alpha: isOverdue ? 0.5 : 0.4),
                      cs.surfaceContainerHighest.withValues(alpha: isOverdue ? 0.35 : 0.25),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isOverdue
                        ? color.withValues(alpha: 0.25)
                        : cs.outlineVariant.withValues(alpha: 0.15),
                  ),
                  boxShadow: _hovered
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: color.withValues(alpha: 0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: cs.shadow.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (widget.icon != null)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(widget.icon, color: color, size: 16),
                          ),
                        if (widget.icon != null) const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (widget.trailing != null) ...[
                          const SizedBox(width: 8),
                          Flexible(child: widget.trailing!),
                        ],
                      ],
                    ),
                    if (isOverdue) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_rounded, size: 14, color: color),
                            const SizedBox(width: 6),
                            Text(
                              widget.overdueWarning!,
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (widget.actions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: widget.actions,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animates a child with fade + slide, staggered by [index].
class StaggeredFadeSlide extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration itemDelay;

  const StaggeredFadeSlide({
    super.key,
    required this.index,
    required this.child,
    this.itemDelay = const Duration(milliseconds: 60),
  });

  @override
  State<StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<StaggeredFadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    final delay = Duration(
      milliseconds: (widget.index * widget.itemDelay.inMilliseconds).round(),
    );
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}

/// Shimmer placeholder for loading states.
class ShimmerLoader extends StatefulWidget {
  final double height;
  final double? width;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const ShimmerLoader({
    super.key,
    this.height = 4,
    this.width,
    this.borderRadius = 4,
    this.margin,
  });

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final sweep = -0.3 + _controller.value * 1.6;
        return Container(
          height: widget.height,
          width: widget.width,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [
                cs.surfaceContainerHighest.withValues(alpha: 0.4),
                cs.surfaceContainerHighest.withValues(alpha: 0.7),
                cs.surfaceContainerHighest.withValues(alpha: 0.4),
              ],
              stops: [sweep - 0.3, sweep, sweep + 0.3]
                  .map((s) => s.clamp(0.0, 1.0))
                  .toList(),
            ),
          ),
        );
      },
    );
  }
}

/// Wraps child with hover scale + glow shadow.
class HoverWrap extends StatefulWidget {
  final Widget child;
  final Color? glowColor;
  final Duration duration;

  const HoverWrap({
    super.key,
    required this.child,
    this.glowColor,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<HoverWrap> createState() => _HoverWrapState();
}

class _HoverWrapState extends State<HoverWrap> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final glow = widget.glowColor ?? cs.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [BoxShadow(
                  color: Colors.transparent,
                  blurRadius: 0,
                )],
        ),
        child: widget.child,
      ),
    );
  }
}


/// Semantic type for [showAppSnack].
enum AppSnackType { success, error, info, warning }

/// Shows a premium, icon-led floating snackbar with a colored accent strip.
/// Use this instead of a bare [SnackBar] for consistent, polished feedback.
/// Optionally pass [actionLabel] + [onAction] (e.g. an "Undo").
void showAppSnack(
  BuildContext context, {
  required String message,
  AppSnackType type = AppSnackType.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final cs = Theme.of(context).colorScheme;
  final sem = context.semantic;
  final (Color accent, IconData icon) = switch (type) {
    AppSnackType.success => (sem.success, Icons.check_circle_rounded),
    AppSnackType.error => (cs.error, Icons.error_outline_rounded),
    AppSnackType.warning => (sem.warning, Icons.warning_amber_rounded),
    AppSnackType.info => (cs.primary, Icons.info_outline_rounded),
  };

  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: duration,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      content: _AppSnackContent(
        message: message,
        accent: accent,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction == null
            ? null
            : () {
                messenger.hideCurrentSnackBar();
                onAction();
              },
      ),
    ),
  );
}

class _AppSnackContent extends StatelessWidget {
  const _AppSnackContent({
    required this.message,
    required this.accent,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final Color accent;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF21242F) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 5, color: accent),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(icon, color: accent, size: 22),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(foregroundColor: accent),
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}
