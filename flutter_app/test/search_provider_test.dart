import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:library_management_app/providers/search_provider.dart';
import 'package:library_management_app/services/api_service.dart';

Map<String, dynamic> _book(int id, String title) => {
      'id': id,
      'isbn': 'ISBN-$id',
      'title': title,
      'author': 'Author $id',
      'status': 'available',
      'added_date': '2024-01-01',
    };

void main() {
  group('SearchProvider filters', () {
    test('default filter values', () {
      final provider = SearchProvider();
      expect(provider.searchType, 'all');
      expect(provider.categoryFilter, 'all');
      expect(provider.availabilityFilter, 'all');
      expect(provider.sortBy, 'title');
    });

    test('setters update filters and resetFilters restores defaults', () {
      final provider = SearchProvider();
      provider.setSearchType('title');
      provider.setCategoryFilter('Science');
      provider.setAvailabilityFilter('available');
      provider.setSortBy('year');

      expect(provider.searchType, 'title');
      expect(provider.categoryFilter, 'Science');
      expect(provider.availabilityFilter, 'available');
      expect(provider.sortBy, 'year');

      provider.resetFilters();
      expect(provider.searchType, 'all');
      expect(provider.categoryFilter, 'all');
      expect(provider.availabilityFilter, 'all');
      expect(provider.sortBy, 'title');
    });
  });

  group('SearchProvider.searchAll', () {
    test('empty query clears results without a network call', () async {
      var called = false;
      final mock = MockClient((request) async {
        called = true;
        return http.Response('[]', 200);
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = SearchProvider();
      await provider.searchAll('   ');

      expect(called, false);
      expect(provider.searchBooks, isEmpty);
      expect(provider.lastQuery, '');
    });

    test('non-Hindi query parses books/members/issues from backend', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, contains('/search'));
        return http.Response(
          jsonEncode({
            'books': [_book(1, 'Dart Guide'), _book(2, 'Flutter Guide')],
            'members': [],
            'issues': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = SearchProvider();
      await provider.searchAll('Guide');

      expect(provider.searchBooks, hasLength(2));
      expect(provider.searchMembers, isEmpty);
      expect(provider.lastQuery, 'Guide');
      expect(provider.isLoading, false);
    });

    test('clearSearch wipes previous results', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'books': [_book(1, 'Dart Guide')],
            'members': [],
            'issues': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = SearchProvider();
      await provider.searchAll('Guide');
      expect(provider.searchBooks, isNotEmpty);

      provider.clearSearch();
      expect(provider.searchBooks, isEmpty);
      expect(provider.lastQuery, '');
    });
  });
}
