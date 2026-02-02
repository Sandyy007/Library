// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:library_management_app/screens/login_screen.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    // Pump the LoginScreen directly to avoid depending on secure storage,
    // backend connectivity, or async auth restoration.
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();

    expect(find.text('Admin Login'), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
  });
}
