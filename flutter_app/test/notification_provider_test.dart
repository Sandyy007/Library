import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:library_management_app/providers/notification_provider.dart';
import 'package:library_management_app/services/api_service.dart';

// loadNotifications uses ApiService._client (mockable). The mutating helpers
// (markAsRead/markAllAsRead/delete) and the count endpoint use package-level
// http.* and are exercised by the backend integration suite.

Map<String, dynamic> _notif(int id, {bool read = false}) => {
      'id': id,
      'title': 'Title $id',
      'message': 'Message $id',
      'type': 'info',
      'is_read': read,
      'created_at': '2024-01-01T00:00:00Z',
    };

void main() {
  group('NotificationProvider', () {
    test('loadNotifications populates list and derives unread count', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode([
            _notif(1),
            _notif(2, read: true),
            _notif(3),
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = NotificationProvider();
      await provider.loadNotifications();

      expect(provider.notifications, hasLength(3));
      expect(provider.unreadCount, 2);
      expect(provider.unreadNotifications, hasLength(2));
      expect(provider.isLoading, false);
    });

    test('unread count is zero when all notifications are read', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode([_notif(1, read: true), _notif(2, read: true)]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = NotificationProvider();
      await provider.loadNotifications();

      expect(provider.unreadCount, 0);
      expect(provider.unreadNotifications, isEmpty);
    });

    test('loadNotifications yields an empty list on server error', () async {
      // ApiService.getNotifications returns [] on non-200 rather than throwing,
      // so the provider ends up with an empty, non-loading state.
      final mock = MockClient((request) async => http.Response('boom', 500));
      ApiService.setHttpClientForTesting(mock);

      final provider = NotificationProvider();
      await provider.loadNotifications();

      expect(provider.notifications, isEmpty);
      expect(provider.unreadCount, 0);
      expect(provider.isLoading, false);
    });
  });
}
