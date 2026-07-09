import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/widgets/common_widgets.dart';

import '../support/harness.dart';

void main() {
  setUpAll(disableGoogleFontsFetching);

  testWidgets('counts up to the final grouped value', (tester) async {
    await tester.pumpWidget(wrapApp(const AnimatedCounter(value: 1234)));
    // Let the count-up tween finish.
    await tester.pumpAndSettle();
    expect(find.text('1,234'), findsOneWidget);
  });

  testWidgets('respects useGrouping = false', (tester) async {
    await tester.pumpWidget(
      wrapApp(const AnimatedCounter(value: 1234, useGrouping: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text('1234'), findsOneWidget);
  });

  testWidgets('uses tabular figures so digits do not jitter', (tester) async {
    await tester.pumpWidget(wrapApp(const AnimatedCounter(value: 42)));
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text('42'));
    expect(
      text.style?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });
}
