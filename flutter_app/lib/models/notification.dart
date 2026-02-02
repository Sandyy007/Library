class AppNotification {
  final int id;
  final int? userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final int? relatedId;
  final String? relatedType;
  final String createdAt;

  AppNotification({
    required this.id,
    this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.relatedId,
    this.relatedType,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? 0,
      userId: json['user_id'],
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'info',
      isRead: json['is_read'] == true || json['is_read'] == 1,
      relatedId: json['related_id'],
      relatedType: json['related_type'],
      createdAt: json['created_at'] ?? '',
    );
  }

  String get icon {
    switch (type) {
      case 'overdue':
        return '⚠️';
      case 'due_soon':
        return '⏰';
      case 'new_book':
        return '📚';
      case 'warning':
        return '⚠️';
      case 'error':
        return '❌';
      case 'success':
        return '✅';
      case 'system':
        return '🔧';
      default:
        return 'ℹ️';
    }
  }
}
