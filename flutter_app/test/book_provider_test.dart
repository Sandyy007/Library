import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:library_management_app/providers/book_provider.dart';
import 'package:library_management_app/services/api_service.dart';

// NOTE: BookProvider load/pagination methods go through ApiService._client
// (the injectable client). Mutating methods (addBook/deleteBook) use the
// package-level http.* functions which can't be mocked, so they're exercised
// by the backend integration suite instead of here.

Map<String, dynamic> _book(int id, String title) => {
      'id': id,
      'isbn': 'ISBN-$id',
      'title': title,
      'author': 'Author $id',
      'status': 'available',
      'added_date': '2024-01-01',
      'total_copies': 3,
      'available_copies': 2,
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
  group('BookProvider', () {
    test('loadBooks populates books and pagination from first page', () async {
      final mock = MockClient((request) async {
        return http.Response(
          _page(
            data: [_book(1, 'Alpha'), _book(2, 'Beta')],
            page: 1,
            total: 5,
            totalPages: 3,
            hasMore: true,
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = BookProvider();
      await provider.loadBooks();

      expect(provider.books, hasLength(2));
      expect(provider.books.first.title, 'Alpha');
      expect(provider.currentPage, 1);
      expect(provider.totalPages, 3);
      expect(provider.totalBooks, 5);
      expect(provider.hasMore, true);
      expect(provider.isLoading, false);
      expect(provider.error, isNull);
    });

    test('loadMoreBooks appends the next page', () async {
      var call = 0;
      final mock = MockClient((request) async {
        call++;
        if (call == 1) {
          return http.Response(
            _page(
              data: [_book(1, 'Alpha')],
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
            data: [_book(2, 'Beta')],
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

      final provider = BookProvider();
      await provider.loadBooks();
      await provider.loadMoreBooks();

      expect(provider.books, hasLength(2));
      expect(provider.books.map((b) => b.id), [1, 2]);
      expect(provider.hasMore, false);
      expect(provider.currentPage, 2);
    });

    test('loadMoreBooks is a no-op when there are no more pages', () async {
      var calls = 0;
      final mock = MockClient((request) async {
        calls++;
        return http.Response(
          _page(
            data: [_book(1, 'Alpha')],
            page: 1,
            total: 1,
            totalPages: 1,
            hasMore: false,
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = BookProvider();
      await provider.loadBooks();
      await provider.loadMoreBooks();

      expect(calls, 1); // second call short-circuits on !hasMore
    });

    test('loadBooks surfaces error and rethrows on failure', () async {
      final mock = MockClient((request) async {
        return http.Response('boom', 500);
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = BookProvider();
      await expectLater(provider.loadBooks(), throwsA(isA<Exception>()));
      expect(provider.error, isNotNull);
      expect(provider.isLoading, false);
    });

    test('removeBookLocally then restoreBookLocally round-trips the row (undo)',
        () async {
      final mock = MockClient((request) async {
        return http.Response(
          _page(
            data: [_book(1, 'Alpha'), _book(2, 'Beta'), _book(3, 'Gamma')],
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

      final provider = BookProvider();
      await provider.loadBooks();
      expect(provider.totalBooks, 3);

      // Remove the middle book (id 2) locally — no API call.
      final removed = provider.removeBookLocally(2);
      expect(removed, isNotNull);
      expect(removed!.index, 1);
      expect(provider.books.map((b) => b.id), [1, 3]);
      expect(provider.totalBooks, 2);

      // Undo: restore at the original index.
      provider.restoreBookLocally(removed.book, removed.index);
      expect(provider.books.map((b) => b.id), [1, 2, 3]);
      expect(provider.totalBooks, 3);
    });

    test('removeBookLocally returns null for an unknown id', () async {
      final mock = MockClient((request) async {
        return http.Response(
          _page(
            data: [_book(1, 'Alpha')],
            page: 1,
            total: 1,
            totalPages: 1,
            hasMore: false,
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = BookProvider();
      await provider.loadBooks();

      expect(provider.removeBookLocally(999), isNull);
      expect(provider.books, hasLength(1));
    });
  });
}
