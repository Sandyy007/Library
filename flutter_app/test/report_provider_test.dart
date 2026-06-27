import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:library_management_app/providers/report_provider.dart';
import 'package:library_management_app/services/api_service.dart';

// These report loaders use ApiService._client (mockable). getCategoryStats /
// the combined loadAllReports also hit category-stats via package-level http.*,
// so they're left to the backend integration suite.

void main() {
  group('ReportProvider', () {
    test('loadPopularBooks populates and clears loading', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {'id': 1, 'title': 'Pop 1', 'author': 'A1', 'borrow_count': 9},
            {'id': 2, 'title': 'Pop 2', 'author': 'A2', 'borrow_count': 4},
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = ReportProvider();
      await provider.loadPopularBooks();

      expect(provider.popularBooks, hasLength(2));
      expect(provider.popularBooks.first.borrowCount, 9);
      expect(provider.isLoading, false);
    });

    test('loadActiveMembers populates list', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {'id': 1, 'name': 'Asha', 'member_type': 'student', 'borrow_count': 7},
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = ReportProvider();
      await provider.loadActiveMembers();

      expect(provider.activeMembers, hasLength(1));
      expect(provider.activeMembers.first.name, 'Asha');
    });

    test('loadMonthlyStats populates list', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {'month': 1, 'issues': 10, 'returns': 8, 'overdue': 2},
            {'month': 2, 'issues': 5, 'returns': 5, 'overdue': 0},
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = ReportProvider();
      await provider.loadMonthlyStats();

      expect(provider.monthlyStats, hasLength(2));
      expect(provider.monthlyStats.first.issues, 10);
    });

    test('loadPopularBooks swallows server errors and leaves list empty', () async {
      final mock = MockClient((request) async => http.Response('err', 500));
      ApiService.setHttpClientForTesting(mock);

      final provider = ReportProvider();
      await provider.loadPopularBooks();

      expect(provider.popularBooks, isEmpty);
      expect(provider.isLoading, false);
    });
  });
}
