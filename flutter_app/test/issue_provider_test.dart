import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:library_management_app/providers/issue_provider.dart';
import 'package:library_management_app/services/api_service.dart';

// IssueProvider load/report methods go through ApiService._client /
// _getWithRetry (mockable). Mutating methods (issueBook/returnBook/updateIssue)
// use package-level http.* and are covered by the backend integration suite.

Map<String, dynamic> _issue(int id, {String status = 'issued'}) => {
      'id': id,
      'book_id': 100 + id,
      'member_id': 200 + id,
      'issue_date': '2024-01-01',
      'due_date': '2024-01-15',
      'status': status,
      'title': 'Book $id',
      'author': 'Author $id',
      'member_name': 'Member $id',
    };

String _page({
  required List<Map<String, dynamic>> data,
  required int page,
  required int total,
  required int totalPages,
  required bool hasMore,
}) {
  return jsonEncode({
    'data': data,
    'pagination': {
      'page': page,
      'limit': 100,
      'total': total,
      'totalPages': totalPages,
      'hasMore': hasMore,
    },
  });
}

void main() {
  group('IssueProvider', () {
    test('loadIssues populates issues and pagination', () async {
      final mock = MockClient((request) async {
        return http.Response(
          _page(
            data: [_issue(1), _issue(2, status: 'returned')],
            page: 1,
            total: 2,
            totalPages: 1,
            hasMore: false,
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = IssueProvider();
      await provider.loadIssues();

      expect(provider.issues, hasLength(2));
      expect(provider.totalIssues, 2);
      expect(provider.hasMore, false);
      expect(provider.isLoading, false);
      expect(provider.error, isNull);
    });

    test('loadMoreIssues appends the next page', () async {
      var call = 0;
      final mock = MockClient((request) async {
        call++;
        if (call == 1) {
          return http.Response(
            _page(
              data: [_issue(1)],
              page: 1,
              total: 2,
              totalPages: 2,
              hasMore: true,
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          _page(
            data: [_issue(2)],
            page: 2,
            total: 2,
            totalPages: 2,
            hasMore: false,
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = IssueProvider();
      await provider.loadIssues();
      await provider.loadMoreIssues();

      expect(provider.issues.map((i) => i.id), [1, 2]);
      expect(provider.hasMore, false);
    });

    test('loadIssues records error message on failure (does not throw)', () async {
      final mock = MockClient((request) async => http.Response('bad', 500));
      ApiService.setHttpClientForTesting(mock);

      final provider = IssueProvider();
      await provider.loadIssues();

      expect(provider.error, isNotNull);
      expect(provider.issues, isEmpty);
      expect(provider.isLoading, false);
    });

    test('getIssuedReport unwraps {data, pagination}', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 1, 'title': 'Book 1', 'member_name': 'M1'},
            ],
            'pagination': {'page': 1, 'total': 1, 'totalPages': 1, 'hasMore': false},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = IssueProvider();
      final report = await provider.getIssuedReport();
      expect(report, hasLength(1));
    });

    test('removeIssueLocally then restoreIssueLocally round-trips (undo)',
        () async {
      final mock = MockClient((request) async {
        return http.Response(
          _page(
            data: [_issue(1), _issue(2), _issue(3)],
            page: 1,
            total: 3,
            totalPages: 1,
            hasMore: false,
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = IssueProvider();
      await provider.loadIssues();

      final removed = provider.removeIssueLocally(2);
      expect(removed, isNotNull);
      expect(removed!.index, 1);
      expect(provider.issues.map((i) => i.id), [1, 3]);
      expect(provider.totalIssues, 2);

      provider.restoreIssueLocally(removed.issue, removed.index);
      expect(provider.issues.map((i) => i.id), [1, 2, 3]);
      expect(provider.totalIssues, 3);
    });
  });
}
