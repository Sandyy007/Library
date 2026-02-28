import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/models/report_models.dart';

void main() {
  group('DashboardWidget', () {
    test('fromJson parses widget correctly', () {
      final w = DashboardWidget.fromJson({
        'widget_name': 'stats_cards',
        'is_visible': 1,
        'position': 0,
        'settings': {'key': 'value'},
      });
      expect(w.name, 'stats_cards');
      expect(w.isVisible, true);
      expect(w.position, 0);
      expect(w.settings, {'key': 'value'});
    });

    test('fromJson with is_visible as bool', () {
      final w = DashboardWidget.fromJson({
        'widget_name': 'charts',
        'is_visible': true,
        'position': 1,
      });
      expect(w.isVisible, true);
    });

    test('fromJson with string settings is treated as null', () {
      final w = DashboardWidget.fromJson({
        'widget_name': 'test',
        'is_visible': false,
        'position': 2,
        'settings': 'invalid_string',
      });
      expect(w.settings, isNull);
    });

    test('toJson roundtrip', () {
      final original = DashboardWidget(
        name: 'charts',
        isVisible: true,
        position: 1,
        settings: {'color': 'blue'},
      );
      final json = original.toJson();
      expect(json['widget_name'], 'charts');
      expect(json['is_visible'], true);
      expect(json['position'], 1);
      expect(json['settings'], {'color': 'blue'});
    });

    test('copyWith creates modified copy', () {
      final w = DashboardWidget(
        name: 'original',
        isVisible: true,
        position: 0,
      );
      final copy = w.copyWith(isVisible: false, position: 5);
      expect(copy.name, 'original');
      expect(copy.isVisible, false);
      expect(copy.position, 5);
    });

    test('displayName returns human-readable name', () {
      final cases = {
        'stats_cards': 'Statistics Cards',
        'charts': 'Charts',
        'recent_issues': 'Recent Issues',
        'popular_books': 'Popular Books',
        'overdue_alerts': 'Overdue Alerts',
        'quick_actions': 'Quick Actions',
        'custom_widget_one': 'Custom Widget One',
      };
      for (final entry in cases.entries) {
        final w = DashboardWidget(
          name: entry.key,
          isVisible: true,
          position: 0,
        );
        expect(w.displayName, entry.value,
            reason: '${entry.key} -> ${entry.value}');
      }
    });
  });

  group('MemberCategory', () {
    test('fromJson with int values', () {
      final mc = MemberCategory.fromJson({
        'id': 1,
        'name': 'Faculty',
        'max_books': 10,
        'loan_period_days': 30,
      });
      expect(mc.id, 1);
      expect(mc.name, 'Faculty');
      expect(mc.maxBooks, 10);
      expect(mc.loanPeriodDays, 30);
    });

    test('fromJson coerces string/double/null to int', () {
      final mc1 = MemberCategory.fromJson({
        'id': '5',
        'name': 'Test',
        'max_books': '3',
        'loan_period_days': 14.7,
      });
      expect(mc1.id, 5);
      expect(mc1.maxBooks, 3);
      expect(mc1.loanPeriodDays, 15); // rounded

      final mc2 = MemberCategory.fromJson({
        'id': null,
        'name': 'Default',
        'max_books': null,
        'loan_period_days': null,
      });
      expect(mc2.id, 0);
      expect(mc2.maxBooks, 3); // default
      expect(mc2.loanPeriodDays, 14); // default
    });
  });

  group('BookCategory', () {
    test('fromJson parses correctly', () {
      final bc = BookCategory.fromJson({
        'id': 2,
        'name': 'Science Fiction',
        'description': 'Sci-fi books',
      });
      expect(bc.id, 2);
      expect(bc.name, 'Science Fiction');
      expect(bc.description, 'Sci-fi books');
    });

    test('fromJson with null description', () {
      final bc = BookCategory.fromJson({
        'id': 3,
        'name': 'History',
      });
      expect(bc.description, isNull);
    });
  });

  group('PopularBook', () {
    test('fromJson parses all fields', () {
      final pb = PopularBook.fromJson({
        'id': 10,
        'title': 'Flutter in Action',
        'author': 'Eric Windmill',
        'category': 'Technology',
        'cover_image': '/covers/flutter.jpg',
        'borrow_count': 42,
      });
      expect(pb.id, 10);
      expect(pb.title, 'Flutter in Action');
      expect(pb.author, 'Eric Windmill');
      expect(pb.category, 'Technology');
      expect(pb.coverImage, '/covers/flutter.jpg');
      expect(pb.borrowCount, 42);
    });

    test('fromJson with null optional fields', () {
      final pb = PopularBook.fromJson({
        'id': 1,
        'title': 'Test',
        'author': 'Author',
        'borrow_count': 0,
      });
      expect(pb.category, isNull);
      expect(pb.coverImage, isNull);
    });
  });

  group('ActiveMember', () {
    test('fromJson parses all fields', () {
      final am = ActiveMember.fromJson({
        'id': 5,
        'name': 'John Doe',
        'email': 'john@example.com',
        'member_type': 'faculty',
        'profile_photo': '/photos/john.jpg',
        'borrow_count': 15,
      });
      expect(am.id, 5);
      expect(am.name, 'John Doe');
      expect(am.email, 'john@example.com');
      expect(am.memberType, 'faculty');
      expect(am.profilePhoto, '/photos/john.jpg');
      expect(am.borrowCount, 15);
    });

    test('fromJson with null optional fields', () {
      final am = ActiveMember.fromJson({
        'id': 1,
        'name': 'Test',
        'borrow_count': 0,
      });
      expect(am.email, isNull);
      expect(am.profilePhoto, isNull);
      expect(am.memberType, 'student'); // default
    });
  });

  group('MonthlyStats', () {
    test('fromJson parses all fields', () {
      final ms = MonthlyStats.fromJson({
        'month': 6,
        'issues': 100,
        'returns': 80,
        'overdue': 5,
      });
      expect(ms.month, 6);
      expect(ms.issues, 100);
      expect(ms.returns, 80);
      expect(ms.overdue, 5);
    });

    test('monthName returns correct three-letter abbreviation', () {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      for (var i = 1; i <= 12; i++) {
        final ms = MonthlyStats.fromJson({
          'month': i,
          'issues': 0,
          'returns': 0,
          'overdue': 0,
        });
        expect(ms.monthName, months[i - 1], reason: 'month $i');
      }
    });

    test('fromJson with string/null values uses _asInt coercion', () {
      final ms = MonthlyStats.fromJson({
        'month': '3',
        'issues': null,
        'returns': '25',
        'overdue': 2.8,
      });
      expect(ms.month, 3);
      expect(ms.issues, 0); // null -> 0
      expect(ms.returns, 25);
      expect(ms.overdue, 3); // rounded
    });
  });

  group('CategoryStats', () {
    test('fromJson parses all fields', () {
      final cs = CategoryStats.fromJson({
        'category': 'Science',
        'book_count': 50,
        'borrow_count': 200,
      });
      expect(cs.category, 'Science');
      expect(cs.bookCount, 50);
      expect(cs.borrowCount, 200);
    });

    test('fromJson with null category defaults to Unknown', () {
      final cs = CategoryStats.fromJson({
        'book_count': 0,
        'borrow_count': 0,
      });
      expect(cs.category, 'Unknown');
    });
  });
}
