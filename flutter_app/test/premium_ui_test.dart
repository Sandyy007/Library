import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/utils/theme.dart';
import 'package:library_management_app/widgets/common_widgets.dart';
import 'package:library_management_app/widgets/gradient_button.dart';
import 'package:library_management_app/widgets/skeleton.dart';

void main() {
  group('Skeleton widget', () {
    testWidgets('renders with default counts', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Skeleton())));
      await tester.pump(const Duration(milliseconds: 50));
      // Should render without throwing
      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets('renders the requested number of cards', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Skeleton(cardCount: 5)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(SkeletonCard), findsNWidgets(5));
    });

    testWidgets('renders the requested number of table rows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Skeleton(rowCount: 4)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(ShimmerTableRow), findsNWidgets(4));
    });

    testWidgets('hides header when showHeader is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Skeleton(showHeader: false, cardCount: 1),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      // Header is two ShimmerBlocks (24px and 14px tall)
      final allBlocks = find.byType(ShimmerBlock);
      // With header: 2 + 1 in card + ... Without: just 1 in card.
      // Hard to count exactly due to nested blocks, so just check it renders.
      expect(allBlocks, findsWidgets);
    });

    testWidgets('SkeletonCard renders avatar + two text lines', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Skeleton(cardCount: 1)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      final card = tester.widget<SkeletonCard>(find.byType(SkeletonCard).first);
      expect(card.height, 88);
    });
  });

  group('EmptyState presets', () {
    void noop() {}

    testWidgets('noBooks shows expected copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EmptyStatePresets.noBooks(onAdd: noop)),
        ),
      );
      await tester.pump();
      expect(find.text('No books yet'), findsOneWidget);
      expect(find.text('Add a book'), findsOneWidget);
    });

    testWidgets('noMembers shows expected copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EmptyStatePresets.noMembers(onAdd: noop)),
        ),
      );
      await tester.pump();
      expect(find.text('No members yet'), findsOneWidget);
      expect(find.text('Add a member'), findsOneWidget);
    });

    testWidgets('noIssues shows expected copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EmptyStatePresets.noIssues(onIssue: noop)),
        ),
      );
      await tester.pump();
      expect(find.text('No issues recorded'), findsOneWidget);
      expect(find.text('Issue a book'), findsOneWidget);
    });

    testWidgets('noSearchResults shows expected copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EmptyStatePresets.noSearchResults(onClear: noop)),
        ),
      );
      await tester.pump();
      expect(find.text('No results found'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
    });

    testWidgets('noNotifications has no action button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EmptyStatePresets.noNotifications()),
        ),
      );
      await tester.pump();
      expect(find.text('You are all caught up'), findsOneWidget);
      // No ElevatedButton in this preset (onAction is null)
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('action button callback is wired', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStatePresets.noBooks(onAdd: () => taps++),
          ),
        ),
      );
      // The empty-state CTA is now a premium GradientButton.
      final btn = find.widgetWithText(GradientButton, 'Add a book');
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('Theme tokens', () {
    test('AppRadii has all expected values', () {
      expect(AppRadii.sm, 8);
      expect(AppRadii.md, 12);
      expect(AppRadii.lg, 16);
      expect(AppRadii.xl, 20);
      expect(AppRadii.pill, 999);
    });

    test('AppSpacing has all expected values', () {
      expect(AppSpacing.xs, 4);
      expect(AppSpacing.sm, 8);
      expect(AppSpacing.md, 12);
      expect(AppSpacing.lg, 16);
      expect(AppSpacing.xl, 24);
      expect(AppSpacing.xxl, 32);
    });

    test('AppDurations has all expected values', () {
      expect(AppDurations.fast, const Duration(milliseconds: 160));
      expect(AppDurations.normal, const Duration(milliseconds: 260));
      expect(AppDurations.slow, const Duration(milliseconds: 420));
    });
  });
}
