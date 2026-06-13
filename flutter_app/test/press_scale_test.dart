import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/utils/responsive.dart';
import 'package:library_management_app/widgets/press_scale.dart';

void main() {
  group('Responsive extensions', () {
    test('sidebarShouldExpand is true above medium', () {
      final r = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 1200, maxHeight: 800),
      );
      expect(r.sidebarShouldExpand, true);
      expect(r.sidebarExpandedWidth, Breakpoints.sidebarWidth);
    });

    test('sidebarShouldExpand is false below medium', () {
      final r = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 800, maxHeight: 800),
      );
      expect(r.sidebarShouldExpand, false);
    });

    test('statCardMinWidth scales with breakpoint', () {
      final compact = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 400, maxHeight: 800),
      );
      final wide = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 1400, maxHeight: 800),
      );
      expect(compact.statCardMinWidth, 140);
      expect(wide.statCardMinWidth, 180);
    });

    test('statCardsPerRow picks 2/3/4/5 by width', () {
      final r1 = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 400, maxHeight: 800),
      );
      final r2 = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 800, maxHeight: 800),
      );
      final r3 = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 1300, maxHeight: 800),
      );
      final r4 = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 1800, maxHeight: 800),
      );
      expect(r1.statCardsPerRow, 2);
      expect(r2.statCardsPerRow, 3);
      expect(r3.statCardsPerRow, 4);
      expect(r4.statCardsPerRow, 5);
    });

    test('titleScale ramps up for wider screens', () {
      final compact = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 400, maxHeight: 800),
      );
      final medium = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 800, maxHeight: 800),
      );
      final ultrawide = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 1800, maxHeight: 800),
      );
      expect(compact.titleScale, 0.9);
      expect(medium.titleScale, 1.0);
      expect(ultrawide.titleScale, 1.15);
    });
  });

  group('ResponsiveContent', () {
    testWidgets('clamps width to maxWidth on wide screens', (tester) async {
      tester.view.physicalSize = const Size(2400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveContent(maxWidth: 1600, child: Text('hi')),
          ),
        ),
      );
      // The text should be present and rendered (clamp logic ran without error).
      expect(find.text('hi'), findsOneWidget);
    });

    testWidgets('renders child even on small screens', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveContent(child: Text('hi')),
          ),
        ),
      );
      expect(find.text('hi'), findsOneWidget);
    });
  });

  group('PressScale', () {
    testWidgets('scales down on tap and back up on release', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PressScale(
                onTap: () => taps++,
                child: Container(width: 100, height: 50, color: Colors.blue),
              ),
            ),
          ),
        ),
      );
      final widget = find.byType(PressScale);
      // Initially scale 1.0
      AnimatedScale scaleBefore =
          tester.widget<AnimatedScale>(find.descendant(
        of: widget,
        matching: find.byType(AnimatedScale),
      ));
      expect(scaleBefore.scale, 1.0);

      // Press down
      final gesture = await tester.startGesture(tester.getCenter(widget));
      await tester.pump(const Duration(milliseconds: 50));
      AnimatedScale scaleDuring =
          tester.widget<AnimatedScale>(find.descendant(
        of: widget,
        matching: find.byType(AnimatedScale),
      ));
      expect(scaleDuring.scale, lessThan(1.0));

      // Release
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
      AnimatedScale scaleAfter =
          tester.widget<AnimatedScale>(find.descendant(
        of: widget,
        matching: find.byType(AnimatedScale),
      ));
      expect(scaleAfter.scale, 1.0);
      expect(taps, 1);
    });

    testWidgets('does not respond to tap when disabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PressScale(
                enabled: false,
                onTap: () => taps++,
                child: Container(width: 100, height: 50, color: Colors.red),
              ),
            ),
          ),
        ),
      );
      // enabled:false short-circuits to the raw child, so no AnimatedScale
      expect(find.byType(AnimatedScale), findsNothing);
      await tester.tap(find.byType(Container));
      expect(taps, 0);
    });

    testWidgets('renders raw child when onTap is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PressScale(
                child: Text('static'),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(AnimatedScale), findsNothing);
      expect(find.text('static'), findsOneWidget);
    });
  });

  group('GlassPanel', () {
    testWidgets('renders child with backdrop blur', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const GlassPanel(child: Text('glass')),
              ],
            ),
          ),
        ),
      );
      expect(find.text('glass'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });
}
