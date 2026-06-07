import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:library_management_app/services/api_service.dart';

void main() {
  group('ApiService.getIssuedReport', () {
    test('unwraps {data, pagination} response shape from backend', () async {
      final mockClient = MockClient((http.Request request) async {
        expect(request.url.path, endsWith('/reports/issued'));
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 1, 'title': 'Book A', 'member_name': 'Alice', 'due_date': '2025-01-01', 'status': 'issued'},
              {'id': 2, 'title': 'Book B', 'member_name': 'Bob', 'due_date': '2025-01-02', 'status': 'issued'},
            ],
            'pagination': {'page': 1, 'limit': 5000, 'total': 2},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mockClient);

      final rows = await ApiService.getIssuedReport();
      expect(rows, hasLength(2));
      expect(rows[0]['title'], 'Book A');
      expect(rows[1]['title'], 'Book B');
    });

    test('returns empty list when data is missing', () async {
      final mockClient = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode({
            'data': [],
            'pagination': {'page': 1, 'limit': 5000, 'total': 0},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mockClient);

      final rows = await ApiService.getIssuedReport();
      expect(rows, isEmpty);
    });

    test('tolerates legacy bare-array responses for backward compatibility', () async {
      // The server was changed from bare array to {data,pagination}, but
      // we keep this guard so a downgrade doesn't crash the client.
      final mockClient = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode([
            {'id': 1, 'title': 'Legacy', 'member_name': 'X', 'due_date': '2025-01-01', 'status': 'issued'},
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mockClient);

      final rows = await ApiService.getIssuedReport();
      expect(rows, hasLength(1));
    });
  });

  group('ApiService.getOverdueReport', () {
    test('unwraps {data, pagination} response shape from backend', () async {
      final mockClient = MockClient((http.Request request) async {
        expect(request.url.path, endsWith('/reports/overdue'));
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 1, 'title': 'Book A', 'member_name': 'Alice', 'due_date': '2024-01-01', 'status': 'overdue'},
            ],
            'pagination': {'page': 1, 'limit': 5000, 'total': 1},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mockClient);

      final rows = await ApiService.getOverdueReport();
      expect(rows, hasLength(1));
      expect(rows[0]['title'], 'Book A');
    });

    test('returns empty list when data is missing', () async {
      final mockClient = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode({
            'data': [],
            'pagination': {'page': 1, 'limit': 5000, 'total': 0},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mockClient);

      final rows = await ApiService.getOverdueReport();
      expect(rows, isEmpty);
    });
  });
}
