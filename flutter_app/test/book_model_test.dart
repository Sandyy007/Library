import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/models/book.dart';

void main() {
  test('Book.fromJson reads rack_number and computes available_copies fallback', () {
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
    // For non-available status, fallback should be 0 when available_copies absent.
    expect(book2.availableCopies, 0);
  });
}
