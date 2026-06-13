import 'package:flutter/material.dart';
import '../utils/theme.dart';
import 'common_widgets.dart';

/// Reusable loading skeleton composed of the project's existing
/// [ShimmerBlock] pieces. Use as a stand-in for a spinner when a
/// list/grid is loading - it gives users a sense of the layout that
/// will appear and feels much faster than a wheel in the center of
/// the screen.
class Skeleton extends StatelessWidget {
  final int cardCount;
  final int rowCount;
  final bool showHeader;
  final EdgeInsetsGeometry padding;

  const Skeleton({
    super.key,
    this.cardCount = 0,
    this.rowCount = 0,
    this.showHeader = true,
    this.padding = const EdgeInsets.all(AppSpacing.pagePadding),
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) ...[
            const ShimmerBlock(width: 220, height: 24),
            const SizedBox(height: AppSpacing.sm),
            const ShimmerBlock(width: 360, height: 14),
            const SizedBox(height: AppSpacing.xl),
          ],
          for (int i = 0; i < cardCount; i++) ...[
            const SkeletonCard(),
            if (i < cardCount - 1) const SizedBox(height: AppSpacing.md),
          ],
          if (cardCount > 0 && rowCount > 0)
            const SizedBox(height: AppSpacing.lg),
          if (rowCount > 0)
            for (int i = 0; i < rowCount; i++)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: ShimmerTableRow(),
              ),
        ],
      ),
    );
  }
}

/// A single skeleton "card" mimicking a list row with avatar + text.
class SkeletonCard extends StatelessWidget {
  final double height;
  const SkeletonCard({super.key, this.height = 88});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: const Row(
        children: [
          ShimmerBlock(width: 48, height: 48, borderRadius: 12),
          SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShimmerBlock(width: double.infinity, height: 14),
                SizedBox(height: AppSpacing.sm),
                ShimmerBlock(width: 180, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
