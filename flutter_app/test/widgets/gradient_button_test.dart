import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/widgets/gradient_button.dart';

import '../support/harness.dart';

void main() {
  setUpAll(disableGoogleFontsFetching);

  testWidgets('renders its label and fires onPressed when tapped',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrapApp(GradientButton(label: 'Save', onPressed: () => taps++)),
    );

    expect(find.text('Save'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('is inert when onPressed is null', (tester) async {
    await tester.pumpWidget(wrapApp(const GradientButton(label: 'Disabled')));
    // Tapping should not throw and there is no callback to fire.
    await tester.tap(find.text('Disabled'));
    await tester.pump();
    expect(find.text('Disabled'), findsOneWidget);
  });

  testWidgets('shows a spinner and blocks taps while loading', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrapApp(GradientButton(
        label: 'Submit',
        loading: true,
        onPressed: () => taps++,
      )),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(GradientButton));
    await tester.pump();
    expect(taps, 0, reason: 'loading buttons must not fire their action');
  });

  testWidgets('exposes a semantic button for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrapApp(GradientButton(label: 'Add book', onPressed: () {})),
    );
    // A tappable button node with the label must exist in the semantics tree.
    expect(find.bySemanticsLabel('Add book'), findsWidgets);
    handle.dispose();
  });
}
