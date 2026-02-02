import '../utils/legacy_hindi.dart';

int _asInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return int.tryParse(value.toString()) ?? fallback;
}

class DashboardWidget {
  final String name;
  final bool isVisible;
  final int position;
  final Map<String, dynamic>? settings;

  DashboardWidget({
    required this.name,
    required this.isVisible,
    required this.position,
    this.settings,
  });

  factory DashboardWidget.fromJson(Map<String, dynamic> json) {
    return DashboardWidget(
      name: json['widget_name'] ?? '',
      isVisible: json['is_visible'] == true || json['is_visible'] == 1,
      position: json['position'] ?? 0,
      settings: json['settings'] is String ? null : json['settings'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'widget_name': name,
      'is_visible': isVisible,
      'position': position,
      'settings': settings,
    };
  }

  DashboardWidget copyWith({
    String? name,
    bool? isVisible,
    int? position,
    Map<String, dynamic>? settings,
  }) {
    return DashboardWidget(
      name: name ?? this.name,
      isVisible: isVisible ?? this.isVisible,
      position: position ?? this.position,
      settings: settings ?? this.settings,
    );
  }

  String get displayName {
    switch (name) {
      case 'stats_cards':
        return 'Statistics Cards';
      case 'charts':
        return 'Charts';
      case 'recent_issues':
        return 'Recent Issues';
      case 'popular_books':
        return 'Popular Books';
      case 'overdue_alerts':
        return 'Overdue Alerts';
      case 'quick_actions':
        return 'Quick Actions';
      default:
        return name.replaceAll('_', ' ').split(' ').map((word) => 
          word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : ''
        ).join(' ');
    }
  }
}

class MemberCategory {
  final int id;
  final String name;
  final int maxBooks;
  final int loanPeriodDays;

  MemberCategory({
    required this.id,
    required this.name,
    required this.maxBooks,
    required this.loanPeriodDays,
  });

  factory MemberCategory.fromJson(Map<String, dynamic> json) {
    return MemberCategory(
      id: _asInt(json['id']),
      name: normalizeLegacyHindiToUnicode(json['name'] ?? ''),
      maxBooks: _asInt(json['max_books'], 3),
      loanPeriodDays: _asInt(json['loan_period_days'], 14),
    );
  }
}

class BookCategory {
  final int id;
  final String name;
  final String? description;

  BookCategory({
    required this.id,
    required this.name,
    this.description,
  });

  factory BookCategory.fromJson(Map<String, dynamic> json) {
    final descriptionRaw = json['description'];
    return BookCategory(
      id: _asInt(json['id']),
      name: normalizeLegacyHindiToUnicode(json['name'] ?? ''),
      description: descriptionRaw == null
          ? null
          : normalizeLegacyHindiToUnicode(descriptionRaw.toString()),
    );
  }
}

class PopularBook {
  final int id;
  final String title;
  final String author;
  final String? category;
  final String? coverImage;
  final int borrowCount;

  PopularBook({
    required this.id,
    required this.title,
    required this.author,
    this.category,
    this.coverImage,
    required this.borrowCount,
  });

  factory PopularBook.fromJson(Map<String, dynamic> json) {
    return PopularBook(
      id: _asInt(json['id']),
      title: normalizeLegacyHindiToUnicode(json['title'] ?? ''),
      author: normalizeLegacyHindiToUnicode(json['author'] ?? ''),
      category: json['category'],
      coverImage: json['cover_image'],
      borrowCount: _asInt(json['borrow_count']),
    );
  }
}

class ActiveMember {
  final int id;
  final String name;
  final String? email;
  final String memberType;
  final String? profilePhoto;
  final int borrowCount;

  ActiveMember({
    required this.id,
    required this.name,
    this.email,
    required this.memberType,
    this.profilePhoto,
    required this.borrowCount,
  });

  factory ActiveMember.fromJson(Map<String, dynamic> json) {
    return ActiveMember(
      id: _asInt(json['id']),
      name: normalizeLegacyHindiToUnicode(json['name'] ?? ''),
      email: json['email'],
      memberType: json['member_type'] ?? 'student',
      profilePhoto: json['profile_photo'],
      borrowCount: _asInt(json['borrow_count']),
    );
  }
}

class MonthlyStats {
  final int month;
  final int issues;
  final int returns;
  final int overdue;

  MonthlyStats({
    required this.month,
    required this.issues,
    required this.returns,
    required this.overdue,
  });

  factory MonthlyStats.fromJson(Map<String, dynamic> json) {
    return MonthlyStats(
      month: _asInt(json['month'], 1),
      issues: _asInt(json['issues']),
      returns: _asInt(json['returns']),
      overdue: _asInt(json['overdue']),
    );
  }

  String get monthName {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

class CategoryStats {
  final String category;
  final int bookCount;
  final int borrowCount;

  CategoryStats({
    required this.category,
    required this.bookCount,
    required this.borrowCount,
  });

  factory CategoryStats.fromJson(Map<String, dynamic> json) {
    return CategoryStats(
      category: json['category'] ?? 'Unknown',
      bookCount: _asInt(json['book_count']),
      borrowCount: _asInt(json['borrow_count']),
    );
  }
}
