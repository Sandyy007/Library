import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/models/book.dart';

void main() {
  group('Book Model', () {
    test('fromJson reads rack_number and computes available_copies fallback',
        () {
      final book1 = Book.fromJson({
        'id': 1,
        'isbn': '123',
        'title': 'Title',
        'author': 'Author',
        'rack_number': 'R-12',
        'status': 'available',
        'added_date': '2024-01-01',
      });
      expect(book1.rackNumber, 'R-12');
      expect(book1.availableCopies, 1);

      final book2 = Book.fromJson({
        'id': 2,
        'isbn': '456',
        'title': 'Title2',
        'author': 'Author2',
        'rackNumber': 'C-3',
        'status': 'issued',
        'added_date': '2024-01-01',
      });
      expect(book2.rackNumber, 'C-3');
      expect(book2.availableCopies, 0);
    });

    test('fromJson uses explicit available_copies when present', () {
      final book = Book.fromJson({
        'id': 1,
        'isbn': '999',
        'title': 'Title',
        'author': 'Author',
        'status': 'available',
        'added_date': '2024-01-01',
        'total_copies': 10,
        'available_copies': 7,
      });
      expect(book.totalCopies, 10);
      expect(book.availableCopies, 7);
    });

    test('fromJson handles empty/minimal json with defaults', () {
      final book = Book.fromJson({});
      expect(book.id, 0);
      expect(book.isbn, '');
      expect(book.title, '');
      expect(book.author, '');
      expect(book.status, 'available');
      expect(book.addedDate, '');
      expect(book.totalCopies, 1);
      expect(book.rackNumber, isNull);
      expect(book.category, isNull);
      expect(book.publisher, isNull);
      expect(book.yearPublished, isNull);
      expect(book.coverImage, isNull);
      expect(book.description, isNull);
    });

    test('toJson serializes correctly', () {
      final book = Book(
        id: 1,
        isbn: '978-0-123',
        title: 'Test Book',
        author: 'Author',
        rackNumber: 'A-1',
        category: 'Fiction',
        publisher: 'Publisher',
        yearPublished: 2024,
        status: 'available',
        addedDate: '2024-01-01',
        coverImage: '/cover.jpg',
        totalCopies: 5,
        availableCopies: 3,
        description: 'A test book',
      );

      final json = book.toJson();
      expect(json['isbn'], '978-0-123');
      expect(json['title'], 'Test Book');
      expect(json['author'], 'Author');
      expect(json['rack_number'], 'A-1');
      expect(json['category'], 'Fiction');
      expect(json['publisher'], 'Publisher');
      expect(json['year_published'], 2024);
      expect(json['cover_image'], '/cover.jpg');
      expect(json['total_copies'], 5);
      expect(json['description'], 'A test book');
      // toJson shouldn't include id, status, addedDate, availableCopies
      expect(json.containsKey('id'), false);
      expect(json.containsKey('status'), false);
    });

    test('copyWith creates modified copy', () {
      final original = Book(
        id: 1,
        isbn: '123',
        title: 'Original',
        author: 'Auth',
        status: 'available',
        addedDate: '2024-01-01',
      );

      final copy = original.copyWith(
        title: 'Updated Title',
        totalCopies: 10,
      );

      expect(copy.id, 1);
      expect(copy.isbn, '123');
      expect(copy.title, 'Updated Title');
      expect(copy.totalCopies, 10);
      expect(copy.author, 'Auth');
    });
  });

  group('BooksPagination', () {
    test('fromJson parses correctly', () {
      final p = BooksPagination.fromJson({
        'page': 2,
        'limit': 50,
        'total': 150,
        'totalPages': 3,
        'hasMore': true,
      });
      expect(p.page, 2);
      expect(p.limit, 50);
      expect(p.total, 150);
      expect(p.totalPages, 3);
      expect(p.hasMore, true);
    });

    test('fromJson with empty map uses defaults', () {
      final p = BooksPagination.fromJson({});
      expect(p.page, 1);
      expect(p.limit, 100);
      expect(p.total, 0);
      expect(p.totalPages, 1);
      expect(p.hasMore, false);
    });
  });

  group('BooksResponse', () {
    test('fromJson parses paginated response', () {
      final response = BooksResponse.fromJson({
        'data': [
          {
            'id': 1,
            'isbn': '111',
            'title': 'Book 1',
            'author': 'Author 1',
            'status': 'available',
            'added_date': '2024-01-01',
          },
          {
            'id': 2,
            'isbn': '222',
            'title': 'Book 2',
            'author': 'Author 2',
            'status': 'issued',
            'added_date': '2024-01-02',
          },
        ],
        'pagination': {
          'page': 1,
          'limit': 100,
          'total': 2,
          'totalPages': 1,
          'hasMore': false,
        },
      });

      expect(response.data.length, 2);
      expect(response.data[0].title, 'Book 1');
      expect(response.data[1].title, 'Book 2');
      expect(response.pagination.total, 2);
    });

    test('fromJson with empty data', () {
      final response = BooksResponse.fromJson({
        'data': [],
        'pagination': {},
      });
      expect(response.data, isEmpty);
      expect(response.pagination.page, 1);
    });

    test('fromJson with null data', () {
      final response = BooksResponse.fromJson({});
      expect(response.data, isEmpty);
    });
  });
}
