import 'package:flutter/material.dart';
import '../utils/color_extensions.dart';

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
        isDark ? const Color(0xFF2D3348) : const Color(0xFFE2E8F0);
    final highlightColor =
        isDark ? const Color(0xFF3F4562) : const Color(0xFFF1F5F9);

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

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          animatedValue.toString(),
          style: style,
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
    return Card(
      elevation: 0,
      margin: margin ?? EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.2),
        ),
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
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.onAction != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onAction,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(widget.actionLabel ?? 'Retry'),
            ),
          ],
        ],
      ),
    );
  }
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
