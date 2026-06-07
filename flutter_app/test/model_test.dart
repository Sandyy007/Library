import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/models/issue.dart';
import 'package:library_management_app/models/user.dart';

void main() {
  group('Issue.fromJson', () {
    test('parses a fully-populated issue', () {
      final i = Issue.fromJson({
        'id': 7,
        'book_id': 12,
        'member_id': 34,
        'issue_date': '2099-01-15',
        'due_date': '2099-02-15',
        'return_date': null,
        'status': 'issued',
        'title': 'Sample Book',
        'author': 'Some Author',
        'member_name': 'Alice',
        'cover_image': null,
        'member_photo': null,
        'notes': null,
      });
      expect(i.id, 7);
      expect(i.bookId, 12);
      expect(i.memberId, 34);
      expect(i.dueDate, '2099-02-15');
      expect(i.status, 'issued');
      expect(i.bookTitle, 'Sample Book');
      expect(i.isOverdue, isFalse);
    });

    test('accepts string-encoded integers', () {
      final i = Issue.fromJson({
        'id': '99',
        'book_id': '5',
        'member_id': '3',
        'issue_date': '2025-12-01',
        'due_date': '2026-06-01',
        'status': 'returned',
        'title': 'A',
        'author': 'B',
        'member_name': 'C',
      });
      expect(i.id, 99);
      expect(i.bookId, 5);
      expect(i.memberId, 3);
    });

    test('throws on missing required id', () {
      expect(
        () => Issue.fromJson({
          'book_id': 1,
          'member_id': 1,
          'issue_date': '2026-01-01',
          'due_date': '2026-02-01',
          'status': 'issued',
          'title': 't',
          'author': 'a',
          'member_name': 'm',
        }),
        throwsFormatException,
      );
    });

    test('throws on null required string field', () {
      expect(
        () => Issue.fromJson({
          'id': 1,
          'book_id': 1,
          'member_id': 1,
          'issue_date': null,
          'due_date': '2026-02-01',
          'status': 'issued',
          'title': 't',
          'author': 'a',
          'member_name': 'm',
        }),
        throwsFormatException,
      );
    });
  });

  group('User.fromJson', () {
    test('parses mustChangePassword from snake_case boolean', () {
      final u = User.fromJson({
        'id': 1,
        'username': 'admin',
        'role': 'admin',
        'must_change_password': true,
      });
      expect(u.mustChangePassword, isTrue);
    });

    test('parses mustChangePassword from camelCase boolean', () {
      final u = User.fromJson({
        'id': 1,
        'username': 'admin',
        'role': 'admin',
        'mustChangePassword': false,
      });
      expect(u.mustChangePassword, isFalse);
    });

    test('parses mustChangePassword from 0/1', () {
      final u0 = User.fromJson({
        'id': 1, 'username': 'a', 'role': 'admin', 'must_change_password': 0,
      });
      final u1 = User.fromJson({
        'id': 1, 'username': 'a', 'role': 'admin', 'must_change_password': 1,
      });
      expect(u0.mustChangePassword, isFalse);
      expect(u1.mustChangePassword, isTrue);
    });

    test('defaults to false when missing', () {
      final u = User.fromJson({
        'id': 1, 'username': 'a', 'role': 'admin',
      });
      expect(u.mustChangePassword, isFalse);
    });
  });
}
