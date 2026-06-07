import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/providers/auth_provider.dart';
import 'package:library_management_app/widgets/session_expiring_banner.dart';
import 'package:provider/provider.dart';

class _FakeAuthProvider extends AuthProvider {
  _FakeAuthProvider({this.remaining});

  final Duration? remaining;

  @override
  Duration? get sessionRemaining => remaining;
}

void main() {
  tearDown(() {
    // Ensure the broadcast controller is fresh between tests so a stream
    // event leaked from one test doesn't trigger the next.
  });

  testWidgets('Banner is invisible when sessionRemaining is null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: _FakeAuthProvider(remaining: null),
          child: const Scaffold(body: SessionExpiringBanner()),
        ),
      ),
    );
    expect(find.byType(SessionExpiringBanner), findsOneWidget);
    expect(find.textContaining('Session expires'), findsNothing);
  });

  testWidgets('Banner shows "expires in N minutes" when remaining is set', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: _FakeAuthProvider(remaining: const Duration(minutes: 3)),
          child: const Scaffold(body: SessionExpiringBanner()),
        ),
      ),
    );
    expect(find.text('Session expires in 3 minutes'), findsOneWidget);
    expect(find.text('Re-login'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
  });

  testWidgets('Banner shows "1 minute" (singular) when remaining is 1 min', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: _FakeAuthProvider(remaining: const Duration(minutes: 1)),
          child: const Scaffold(body: SessionExpiringBanner()),
        ),
      ),
    );
    expect(find.text('Session expires in 1 minute'), findsOneWidget);
  });

  testWidgets('Banner shows "<1 minute" when remaining is sub-minute', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: _FakeAuthProvider(remaining: const Duration(seconds: 30)),
          child: const Scaffold(body: SessionExpiringBanner()),
        ),
      ),
    );
    expect(find.text('Session expired in <1 minute'), findsOneWidget);
  });
}
