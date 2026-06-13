int _toInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

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
      id: _toInt(json['id']),
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : (json['user_id'] is num
              ? (json['user_id'] as num).toInt()
              : null),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'info',
      isRead: json['is_read'] == true || json['is_read'] == 1,
      relatedId: json['related_id'] is int
          ? json['related_id'] as int
          : (json['related_id'] is num
              ? (json['related_id'] as num).toInt()
              : null),
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

  /// Creates a copy with optional field overrides.
  AppNotification copyWith({
    int? id,
    int? userId,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    int? relatedId,
    String? relatedType,
    String? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      relatedId: relatedId ?? this.relatedId,
      relatedType: relatedType ?? this.relatedType,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
