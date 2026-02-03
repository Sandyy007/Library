import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../services/api_service.dart';

class NotificationProvider with ChangeNotifier {
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  Timer? _pollTimer;
  int? _currentUserId;
  StreamSubscription<void>? _dataChangedSub;

  List<AppNotification> get notifications => _notifications;
  List<AppNotification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  void initialize(int userId) {
    if (_currentUserId == userId &&
        (_pollTimer != null || _dataChangedSub != null)) {
      return;
    }
    _currentUserId = userId;

    _dataChangedSub?.cancel();
    _dataChangedSub = ApiService.dataChangedStream.listen((_) {
      // Instant refresh after local mutations (issue/return/add/update/etc).
      refresh(silent: true, full: true);
    });

    loadNotifications();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // Poll periodically to reflect changes made by other clients.
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      refresh(silent: true);
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _dataChangedSub?.cancel();
    super.dispose();
  }

  Future<void> loadNotifications({
    bool unreadOnly = false,
    bool silent = false,
  }) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _notifications = await ApiService.getNotifications(
        unreadOnly: unreadOnly,
      );
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      if (kDebugMode) debugPrint(
        'DEBUG [NotificationProvider]: Loaded ${_notifications.length} notifications',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [NotificationProvider]: Error loading notifications: $e');
    }

    if (!silent) {
      _isLoading = false;
    }
    notifyListeners();
  }

  Future<void> loadUnreadCount() async {
    try {
      _unreadCount = await ApiService.getUnreadNotificationCount();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [NotificationProvider]: Error loading unread count: $e');
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      await ApiService.markNotificationAsRead(id);
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = AppNotification(
          id: _notifications[index].id,
          userId: _notifications[index].userId,
          title: _notifications[index].title,
          message: _notifications[index].message,
          type: _notifications[index].type,
          isRead: true,
          relatedId: _notifications[index].relatedId,
          relatedType: _notifications[index].relatedType,
          createdAt: _notifications[index].createdAt,
        );
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint(
        'DEBUG [NotificationProvider]: Error marking notification as read: $e',
      );
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await ApiService.markAllNotificationsAsRead();
      _notifications = _notifications
          .map(
            (n) => AppNotification(
              id: n.id,
              userId: n.userId,
              title: n.title,
              message: n.message,
              type: n.type,
              isRead: true,
              relatedId: n.relatedId,
              relatedType: n.relatedType,
              createdAt: n.createdAt,
            ),
          )
          .toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [NotificationProvider]: Error marking all as read: $e');
    }
  }

  Future<void> deleteNotification(int id) async {
    try {
      await ApiService.deleteNotification(id);
      _notifications.removeWhere((n) => n.id == id);
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [NotificationProvider]: Error deleting notification: $e');
    }
  }

  Future<void> refresh({bool silent = false, bool full = false}) async {
    // For realtime-ish bell updates, polling unread count is cheaper than fetching
    // the entire notification list repeatedly.
    if (!full && silent) {
      await loadUnreadCount();
      return;
    }
    await loadNotifications(silent: silent);
  }
}
