import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/widgets/common_widgets.dart';

import '../support/harness.dart';

// Note: PressScale and HoverElevate are covered by press_scale_test.dart and
// hover_elevate_test.dart respectively. This file covers StaggeredFadeSlide,
// which had no existing coverage.
void main() {
  setUpAll(disableGoogleFontsFetching);

  group('StaggeredFadeSlide', () {
    testWidgets('reveals its child after the staggered delay', (tester) async {
      await tester.pumpWidget(wrapApp(
        const StaggeredFadeSlide(index: 2, child: Text('row')),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('row'), findsOneWidget);

      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(StaggeredFadeSlide),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fade.opacity.value, 1.0);
    });
  });
}
