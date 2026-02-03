import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:library_management_app/models/user.dart';
import 'package:library_management_app/providers/auth_provider.dart';
import 'package:library_management_app/screens/login_screen.dart';

void main() {
  testWidgets('LoginScreen shows validation errors', (WidgetTester tester) async {
    final auth = AuthProvider(
      loginFn: (u, p) async => User(id: 1, username: u, role: 'admin'),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    // Let initial animations settle.
    await tester.pump(const Duration(milliseconds: 1100));

    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Please enter admin username'), findsOneWidget);
    expect(find.text('Please enter admin password'), findsOneWidget);
  });

  testWidgets('Password visibility toggle works', (WidgetTester tester) async {
    final auth = AuthProvider(
      loginFn: (u, p) async => User(id: 1, username: u, role: 'admin'),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1300));

    final passwordFieldFinder = find.byType(TextFormField).at(1);
    EditableText editable = tester.widget<EditableText>(
      find.descendant(of: passwordFieldFinder, matching: find.byType(EditableText)),
    );
    expect(editable.obscureText, isTrue);

    // Tap the suffix icon button.
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();

    editable = tester.widget<EditableText>(
      find.descendant(of: passwordFieldFinder, matching: find.byType(EditableText)),
    );
    expect(editable.obscureText, isFalse);
  });

  testWidgets('Successful login updates AuthProvider', (WidgetTester tester) async {
    final auth = AuthProvider(
      loginFn: (u, p) async => User(id: 1, username: u, role: 'admin'),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1300));

    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), 'admin');

    expect(auth.isAuthenticated, isFalse);

    await tester.tap(find.text('Sign In'));
    await tester.pump();

    // Wait for the async login call to complete.
    await tester.pump(const Duration(milliseconds: 50));

    expect(auth.isAuthenticated, isTrue);
    expect(auth.user?.role, 'admin');
  });
}
