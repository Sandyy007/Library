import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/widgets/app_error_boundary.dart';

void main() {
  testWidgets('AppErrorBoundary does not show error screen on normal children', (tester) async {
    await tester.pumpWidget(
      const AppErrorBoundary(
        child: MaterialApp(
          home: Scaffold(body: Text('OK')),
        ),
      ),
    );
    expect(find.text('OK'), findsOneWidget);
    expect(find.text('Something went wrong'), findsNothing);
  });

  testWidgets('AppErrorBoundary renders child without adding extra constraints', (tester) async {
    await tester.pumpWidget(
      const AppErrorBoundary(
        child: MaterialApp(
          home: Scaffold(body: Text('Hello')),
        ),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
  });
}
