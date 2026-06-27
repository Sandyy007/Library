import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:library_management_app/screens/books_content.dart';
import 'package:library_management_app/providers/book_provider.dart';
import 'package:library_management_app/providers/issue_provider.dart';
import 'package:library_management_app/services/api_service.dart';

// A content-screen smoke test: renders BooksContent with mocked, empty data
// and verifies it builds, loads, and shows its empty state without throwing.

String _emptyPage() => jsonEncode({
      'data': [],
      'pagination': {
        'page': 1,
        'limit': 100,
        'total': 0,
        'totalPages': 1,
        'hasMore': false,
      },
    });

Widget _host() => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BookProvider()),
        ChangeNotifierProvider(create: (_) => IssueProvider()),
      ],
      child: const MaterialApp(home: BooksContent()),
    );

void main() {
  setUpAll(() {
    // Don't hit the network for fonts during tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // The content screen is a desktop-first responsive layout; give it a
  // desktop-sized surface so the toolbar/table don't overflow the viewport.
  Future<void> pumpAtDesktopSize(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(widget);
    // Can't use pumpAndSettle: the status-badge pulse/shimmer animations
    // repeat forever and would never settle. Pump bounded frames so the
    // post-frame loadBooks() and its mocked future resolve and rebuild.
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  testWidgets('BooksContent renders and loads an empty list without error',
      (tester) async {
    ApiService.setHttpClientForTesting(
      MockClient((request) async => http.Response(
            _emptyPage(),
            200,
            headers: {'content-type': 'application/json'},
          )),
    );

    await pumpAtDesktopSize(tester, _host());

    expect(find.byType(BooksContent), findsOneWidget);
    // Toolbar search field is always present.
    expect(find.byType(TextField), findsWidgets);
  });
}
