import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/models/notification.dart';

void main() {
  group('AppNotification Model', () {
    test('fromJson parses all fields correctly', () {
      final n = AppNotification.fromJson({
        'id': 10,
        'user_id': 1,
        'title': 'Overdue Alert',
        'message': 'Book is overdue',
        'type': 'overdue',
        'is_read': false,
        'related_id': 5,
        'related_type': 'issue',
        'created_at': '2024-01-15T10:00:00Z',
      });

      expect(n.id, 10);
      expect(n.userId, 1);
      expect(n.title, 'Overdue Alert');
      expect(n.message, 'Book is overdue');
      expect(n.type, 'overdue');
      expect(n.isRead, false);
      expect(n.relatedId, 5);
      expect(n.relatedType, 'issue');
      expect(n.createdAt, '2024-01-15T10:00:00Z');
    });

    test('fromJson handles is_read as 0/1', () {
      final readNotif = AppNotification.fromJson({
        'id': 1,
        'title': 't',
        'message': 'm',
        'type': 'info',
        'is_read': 1,
        'created_at': '',
      });
      expect(readNotif.isRead, true);

      final unreadNotif = AppNotification.fromJson({
        'id': 2,
        'title': 't',
        'message': 'm',
        'type': 'info',
        'is_read': 0,
        'created_at': '',
      });
      expect(unreadNotif.isRead, false);
    });

    test('fromJson handles missing/null fields with defaults', () {
      final n = AppNotification.fromJson({});
      expect(n.id, 0);
      expect(n.userId, isNull);
      expect(n.title, '');
      expect(n.message, '');
      expect(n.type, 'info');
      expect(n.isRead, false);
      expect(n.relatedId, isNull);
      expect(n.relatedType, isNull);
      expect(n.createdAt, '');
    });

    test('icon returns correct emoji for each type', () {
      final testCases = {
        'overdue': '⚠️',
        'due_soon': '⏰',
        'new_book': '📚',
        'warning': '⚠️',
        'error': '❌',
        'success': '✅',
        'system': '🔧',
        'info': 'ℹ️',
        'unknown_type': 'ℹ️',
      };

      for (final entry in testCases.entries) {
        final n = AppNotification.fromJson({
          'id': 1,
          'title': '',
          'message': '',
          'type': entry.key,
          'created_at': '',
        });
        expect(n.icon, entry.value,
            reason: 'type ${entry.key} should return ${entry.value}');
      }
    });
  });
}
