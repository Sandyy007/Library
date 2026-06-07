import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:library_management_app/services/api_service.dart';

void main() {
  group('ApiService.getDashboardStats retry behaviour', () {
    test('retries on 503 and eventually succeeds', () async {
      var attempt = 0;
      final mock = MockClient((http.Request request) async {
        attempt++;
        if (attempt < 3) {
          return http.Response('Service Unavailable', 503,
              headers: {'content-type': 'text/plain'});
        }
        return http.Response(
          jsonEncode({'total_books': 100, 'issued_books': 5}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      final stats = await ApiService.getDashboardStats();
      expect(attempt, 3);
      expect(stats['total_books'], 100);
      expect(stats['issued_books'], 5);
    });

    test('retries on 502 (Bad Gateway) up to maxRetries', () async {
      var attempt = 0;
      final mock = MockClient((http.Request request) async {
        attempt++;
        return http.Response('Bad Gateway', 502);
      });
      ApiService.setHttpClientForTesting(mock);

      await expectLater(
        () => ApiService.getDashboardStats(),
        throwsA(isA<Exception>()),
      );
      // We expect 3 total attempts (initial + 2 retries).
      expect(attempt, 3);
    });

    test('does NOT retry on 401 (auth error)', () async {
      var attempt = 0;
      final mock = MockClient((http.Request request) async {
        attempt++;
        return http.Response(
          jsonEncode({'error': 'unauthorized', 'code': 'AUTH_INVALID'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      await expectLater(
        () => ApiService.getDashboardStats(),
        throwsA(isA<Exception>()),
      );
      // 401 is not in _retryableStatusCodes, so exactly 1 attempt.
      expect(attempt, 1);
    });

    test('does NOT retry on 400 (client error)', () async {
      var attempt = 0;
      final mock = MockClient((http.Request request) async {
        attempt++;
        return http.Response('Bad Request', 400);
      });
      ApiService.setHttpClientForTesting(mock);

      await expectLater(
        () => ApiService.getDashboardStats(),
        throwsA(isA<Exception>()),
      );
      // 400 is not in _retryableStatusCodes, so exactly 1 attempt.
      expect(attempt, 1);
    });
  });

  group('ApiService.getCategories retry behaviour', () {
    test('retries on 429 (rate limited) and eventually succeeds', () async {
      var attempt = 0;
      final mock = MockClient((http.Request request) async {
        attempt++;
        if (attempt < 2) {
          return http.Response('Too Many Requests', 429);
        }
        return http.Response(
          jsonEncode([
            {'id': 1, 'name': 'Fiction'},
            {'id': 2, 'name': 'Non-Fiction'},
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      // Pass forceRefresh: true so we don't return the cached list.
      final categories = await ApiService.getCategories(forceRefresh: true);
      expect(attempt, 2);
      expect(categories, hasLength(2));
    });
  });
}
