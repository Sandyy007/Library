import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/models/issue.dart';

void main() {
  group('Issue Model Tests', () {
    test('Issue.fromJson parses all fields correctly', () {
      final issue = Issue.fromJson({
        'id': 1,
        'book_id': 10,
        'member_id': 20,
        'issue_date': '2024-01-15',
        'due_date': '2024-01-29',
        'return_date': '2024-01-25',
        'status': 'returned',
        'notes': 'Test note',
        'title': 'Test Book',
        'author': 'Test Author',
        'cover_image': '/covers/book.jpg',
        'member_name': 'John Doe',
        'member_photo': '/photos/john.jpg',
      });

      expect(issue.id, 1);
      expect(issue.bookId, 10);
      expect(issue.memberId, 20);
      expect(issue.issueDate, '2024-01-15');
      expect(issue.dueDate, '2024-01-29');
      expect(issue.returnDate, '2024-01-25');
      expect(issue.status, 'returned');
      expect(issue.notes, 'Test note');
      expect(issue.bookTitle, 'Test Book');
      expect(issue.bookAuthor, 'Test Author');
      expect(issue.coverImage, '/covers/book.jpg');
      expect(issue.memberName, 'John Doe');
      expect(issue.memberPhoto, '/photos/john.jpg');
    });

    test('Issue.fromJson handles null optional fields', () {
      final issue = Issue.fromJson({
        'id': 2,
        'book_id': 5,
        'member_id': 8,
        'issue_date': '2024-02-01',
        'due_date': '2024-02-15',
        'status': 'issued',
        'title': 'A Book',
        'author': 'An Author',
        'member_name': 'A Member',
      });

      expect(issue.id, 2);
      expect(issue.returnDate, isNull);
      expect(issue.notes, isNull);
      expect(issue.bookTitle, 'A Book');
      expect(issue.memberName, 'A Member');
      expect(issue.coverImage, isNull);
      expect(issue.memberPhoto, isNull);
    });

    test('Issue status values', () {
      final issued = Issue.fromJson({
        'id': 1,
        'book_id': 1,
        'member_id': 1,
        'issue_date': '2024-01-01',
        'due_date': '2024-01-15',
        'status': 'issued',
        'title': 'Book',
        'author': 'Author',
        'member_name': 'Member',
      });
      expect(issued.status, 'issued');

      final returned = Issue.fromJson({
        'id': 2,
        'book_id': 2,
        'member_id': 2,
        'issue_date': '2024-01-01',
        'due_date': '2024-01-15',
        'status': 'returned',
        'title': 'Book',
        'author': 'Author',
        'member_name': 'Member',
      });
      expect(returned.status, 'returned');

      final overdue = Issue.fromJson({
        'id': 3,
        'book_id': 3,
        'member_id': 3,
        'issue_date': '2024-01-01',
        'due_date': '2024-01-15',
        'status': 'overdue',
        'title': 'Book',
        'author': 'Author',
        'member_name': 'Member',
      });
      expect(overdue.status, 'overdue');
    });

    test('Issue.isOverdue returns correct value', () {
      // Past due date, not returned
      final overdueIssue = Issue.fromJson({
        'id': 1,
        'book_id': 1,
        'member_id': 1,
        'issue_date': '2020-01-01',
        'due_date': '2020-01-15', // Way in the past
        'status': 'issued',
        'title': 'Book',
        'author': 'Author',
        'member_name': 'Member',
      });
      expect(overdueIssue.isOverdue, true);

      // Returned issue should not be overdue
      final returnedIssue = Issue.fromJson({
        'id': 2,
        'book_id': 2,
        'member_id': 2,
        'issue_date': '2020-01-01',
        'due_date': '2020-01-15',
        'status': 'returned',
        'return_date': '2020-01-14',
        'title': 'Book',
        'author': 'Author',
        'member_name': 'Member',
      });
      expect(returnedIssue.isOverdue, false);
    });

    test('daysOverdue returns correct count for overdue issue', () {
      final pastDue = DateTime.now().subtract(const Duration(days: 10));
      final issue = Issue.fromJson({
        'id': 1,
        'book_id': 1,
        'member_id': 1,
        'issue_date': '2020-01-01',
        'due_date': pastDue.toIso8601String(),
        'status': 'issued',
        'title': 'Book',
        'author': 'Author',
        'member_name': 'Member',
      });
      expect(issue.daysOverdue, greaterThanOrEqualTo(10));
    });

    test('daysOverdue returns 0 for non-overdue issue', () {
      final futureDue = DateTime.now().add(const Duration(days: 30));
      final issue = Issue.fromJson({
        'id': 1,
        'book_id': 1,
        'member_id': 1,
        'issue_date': '2024-01-01',
        'due_date': futureDue.toIso8601String(),
        'status': 'issued',
        'title': 'Book',
        'author': 'Author',
        'member_name': 'Member',
      });
      expect(issue.daysOverdue, 0);
    });

    test('fromJson with empty map throws (strict parsing)', () {
      // The strict parser refuses to silently coerce missing required fields
      // to defaults; a malformed payload should surface as an exception.
      expect(() => Issue.fromJson({}), throwsFormatException);
    });
  });

  group('IssuesPagination', () {
    test('fromJson parses correctly', () {
      final p = IssuesPagination.fromJson({
        'page': 3,
        'limit': 50,
        'total': 200,
        'totalPages': 4,
        'hasMore': true,
      });
      expect(p.page, 3);
      expect(p.limit, 50);
      expect(p.total, 200);
      expect(p.totalPages, 4);
      expect(p.hasMore, true);
    });

    test('empty returns defaults', () {
      final p = IssuesPagination.empty();
      expect(p.page, 1);
      expect(p.limit, 100);
      expect(p.total, 0);
      expect(p.totalPages, 1);
      expect(p.hasMore, false);
    });
  });

  group('IssuesResponse', () {
    test('fromJson with data key', () {
      final response = IssuesResponse.fromJson({
        'data': [
          {
            'id': 1,
            'book_id': 10,
            'member_id': 20,
            'issue_date': '2024-01-01',
            'due_date': '2024-01-15',
            'status': 'issued',
            'title': 'Book',
            'author': 'Author',
            'member_name': 'Member',
          }
        ],
        'pagination': {
          'page': 1,
          'limit': 100,
          'total': 1,
          'totalPages': 1,
          'hasMore': false,
        },
      });
      expect(response.data.length, 1);
      expect(response.data[0].bookTitle, 'Book');
      expect(response.pagination.total, 1);
    });

    test('fromJson without data key (legacy array)', () {
      final response = IssuesResponse.fromJson({
        'issues': [  // not 'data'
          {
            'id': 1,
            'book_id': 1,
            'member_id': 1,
            'issue_date': '2024-01-01',
            'due_date': '2024-01-15',
            'status': 'issued',
            'title': 'Book',
            'author': 'Author',
            'member_name': 'Member',
          }
        ],
      });
      // Without 'data' key, should still work as empty data list
      expect(response.data, isEmpty);
    });

    test('empty returns defaults', () {
      final response = IssuesResponse.empty();
      expect(response.data, isEmpty);
      expect(response.pagination.page, 1);
    });
  });
}
