import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/utils/theme.dart';
import 'package:library_management_app/widgets/app_toast.dart';

import '../support/harness.dart';

void main() {
  setUpAll(disableGoogleFontsFetching);

  Widget host(void Function(BuildContext) onPressed) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => onPressed(context),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('success toast shows its message and title', (tester) async {
    await tester.pumpWidget(host(
      (context) => AppToast.success(context, 'Book saved', title: 'Done'),
    ));

    await tester.tap(find.text('go'));
    await tester.pump(); // schedule snackbar
    await tester.pump(const Duration(milliseconds: 400)); // entrance anim

    expect(find.text('Book saved'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('error toast uses the error icon', (tester) async {
    await tester.pumpWidget(host(
      (context) => AppToast.error(context, 'Could not save'),
    ));

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Could not save'), findsOneWidget);
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);
  });

  testWidgets('toast can be dismissed with its close button', (tester) async {
    await tester.pumpWidget(host(
      (context) => AppToast.info(context, 'Heads up'),
    ));

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Heads up'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Heads up'), findsNothing);
  });
}
