import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/widgets/press_scale.dart';

void main() {
  group('HoverElevate', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: HoverElevate(
                child: Text('card-content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('card-content'), findsOneWidget);
      expect(find.byType(MouseRegion), findsWidgets);
    });

    testWidgets('lifts on pointer hover and settles on exit', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: HoverElevate(
                liftY: 6,
                child: SizedBox(width: 100, height: 100, child: Text('hoverable')),
              ),
            ),
          ),
        ),
      );

      Matrix4 transformOf() {
        final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        return container.transform!;
      }

      // Resting: no vertical translation.
      expect(transformOf().getTranslation().y, 0);

      // Move a mouse pointer over the widget.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('hoverable')));
      await tester.pumpAndSettle();

      // Hovering: lifted upward (negative Y).
      expect(transformOf().getTranslation().y, lessThan(0));

      // Move away: settles back to rest.
      await gesture.moveTo(const Offset(500, 500));
      await tester.pumpAndSettle();
      expect(transformOf().getTranslation().y, 0);
    });
  });
}
