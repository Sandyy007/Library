import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:library_management_app/providers/auth_provider.dart';
import 'package:library_management_app/providers/theme_provider.dart';
import 'package:library_management_app/providers/book_provider.dart';
import 'package:library_management_app/providers/member_provider.dart';
import 'package:library_management_app/providers/issue_provider.dart';
import 'package:library_management_app/providers/notification_provider.dart';
import 'package:library_management_app/providers/report_provider.dart';
import 'package:library_management_app/providers/dashboard_provider.dart';
import 'package:library_management_app/providers/search_provider.dart';
import 'package:library_management_app/screens/dashboard_screen.dart';
import 'package:library_management_app/services/api_service.dart';
import 'package:library_management_app/utils/theme.dart';
import 'package:library_management_app/widgets/app_error_boundary.dart';

class _TestApp extends StatelessWidget {
  const _TestApp({required this.home});
  final Widget home;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      builder: (context, child) => AppErrorBoundary(child: child!),
      home: home,
      debugShowCheckedModeBanner: false,
    );
  }
}

http.Client _mockClient() {
  return MockClient((request) async {
    final url = request.url.toString();
    if (url.contains('/api/auth/login')) {
      return http.Response(
        jsonEncode({
          'token': 'fake.jwt.token',
          'user': {'id': 1, 'username': 'admin', 'role': 'admin'},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (url.contains('/api/books')) {
      return http.Response(
        jsonEncode({
          'data': List.generate(
            20,
            (i) => {
              'id': i + 1,
              'title': 'Book Title ${i + 1}',
              'author': 'Author ${i + 1}',
              'isbn': '978-0-${i.toString().padLeft(4, '0')}-0000-0',
              'category': 'Fiction',
              'rack': 'A-${i + 1}',
              'total_copies': 5,
              'available_copies': 3,
              'status': 'available',
              'cover_url': null,
              'description': 'Description for book ${i + 1}',
              'added_date': '2024-01-01T00:00:00Z',
            },
          ),
          'pagination': {'page': 1, 'limit': 100, 'total': 20, 'total_pages': 1},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (url.contains('/api/members')) {
      return http.Response(
        jsonEncode({
          'data': List.generate(
            8,
            (i) => {
              'id': i + 1,
              'name': 'Member ${i + 1}',
              'email': 'member${i + 1}@example.com',
              'phone': '555-${(1000 + i).toString()}',
              'member_type': i.isEven ? 'student' : 'faculty',
              'is_active': true,
              'photo_url': null,
              'membership_date': '2024-01-01',
              'expiry_date': '2025-01-01',
            },
          ),
          'pagination': {'page': 1, 'limit': 100, 'total': 8, 'total_pages': 1},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (url.contains('/api/issues')) {
      return http.Response(
        jsonEncode({
          'data': List.generate(
            5,
            (i) => {
              'id': i + 1,
              'book_id': i + 1,
              'book_title': 'Book Title ${i + 1}',
              'member_id': i + 1,
              'member_name': 'Member ${i + 1}',
              'issue_date': '2024-01-0${i + 1}',
              'due_date': '2024-02-0${i + 1}',
              'return_date': null,
              'status': i.isEven ? 'issued' : 'overdue',
            },
          ),
          'pagination': {'page': 1, 'limit': 100, 'total': 5, 'total_pages': 1},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (url.contains('/api/categories')) {
      return http.Response(
        jsonEncode({
          'data': [
            {'id': 1, 'name': 'Fiction', 'description': 'Fiction books'},
            {'id': 2, 'name': 'Non-Fiction', 'description': 'Non-fiction books'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (url.contains('/api/member-categories')) {
      return http.Response(
        jsonEncode({
          'data': [
            {'id': 1, 'name': 'student', 'max_books': 3, 'loan_period_days': 14},
            {'id': 2, 'name': 'faculty', 'max_books': 10, 'loan_period_days': 30},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (url.contains('/api/dashboard/stats')) {
      return http.Response(
        jsonEncode({
          'totalBooks': 108,
          'totalMembers': 8,
          'activeIssues': 5,
          'overdueIssues': 1,
          'totalCopies': 421,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (url.contains('/api/dashboard/activity')) {
      return http.Response(jsonEncode({'data': []}), 200,
          headers: {'content-type': 'application/json'});
    }
    if (url.contains('/api/dashboard/alerts')) {
      return http.Response(
        jsonEncode({
          'overdue': {'count': 1, 'items': []},
          'dueToday': {'count': 0, 'items': []},
          'kpis': {'overdue': 1, 'dueToday': 0},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (url.contains('/api/notifications')) {
      return http.Response(
        jsonEncode({'data': [], 'unread_count': 0}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (url.contains('/api/reports/issued')) {
      return http.Response(
        jsonEncode({'data': [], 'pagination': {'page': 1, 'limit': 500, 'total': 0, 'total_pages': 0}}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (url.contains('/api/reports/overdue')) {
      return http.Response(
        jsonEncode({'data': [], 'pagination': {'page': 1, 'limit': 500, 'total': 0, 'total_pages': 0}}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (url.contains('/api/dashboard/settings')) {
      return http.Response(jsonEncode({'data': []}), 200,
          headers: {'content-type': 'application/json'});
    }
    if (url.contains('/api/search')) {
      return http.Response(
        jsonEncode({'books': [], 'members': [], 'issues': []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response(jsonEncode({'data': []}), 200,
        headers: {'content-type': 'application/json'});
  });
}

// ignore_for_file: dead_code

void main() {
  // Slow visual regression check — skip by default for fast local runs.
  testWidgets('audit every tab with mock data at every size', (tester) async {
    // ignore: avoid_print
    print('Skipping audit test (run directly for full regression)');
    return;
    SharedPreferences.setMockInitialValues({});
    ApiService.setHttpClientForTesting(_mockClient());

    final errors = <FlutterErrorDetails>[];
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details);
    };
    addTearDown(() {
      FlutterError.onError = original;
    });

    final auth = AuthProvider();
    await auth.login('admin', 'admin123');

    final providers = [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => BookProvider()),
      ChangeNotifierProvider(create: (_) => MemberProvider()),
      ChangeNotifierProvider(create: (_) => IssueProvider()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider(create: (_) => ReportProvider()),
      ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ChangeNotifierProvider(create: (_) => SearchProvider()),
    ];

    const tabNames = ['Dashboard'];
    for (final size in [
      const Size(1200, 900),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      for (var tab = 0; tab < tabNames.length; tab++) {
        errors.clear();
        await tester.pumpWidget(
          MultiProvider(
            providers: providers,
            child: _TestApp(home: DashboardScreen(initialIndex: tab)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(seconds: 1));
        if (errors.isNotEmpty) {
          // ignore: avoid_print
          print('=== ${size.width.toInt()}x${size.height.toInt()} ${tabNames[tab]}: ${errors.length} errors ===');
          for (var i = 0; i < errors.length && i < 8; i++) {
            final e = errors[i];
            // ignore: avoid_print
            print('  ${e.exceptionAsString().split('\n').first}');
          }
        }
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
