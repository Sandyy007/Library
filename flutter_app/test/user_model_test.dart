import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/models/user.dart';

void main() {
  group('User Model', () {
    test('fromJson parses all fields correctly', () {
      final user = User.fromJson({
        'id': 1,
        'username': 'admin',
        'role': 'admin',
      });
      expect(user.id, 1);
      expect(user.username, 'admin');
      expect(user.role, 'admin');
    });

    test('fromJson with different roles', () {
      for (final role in ['admin', 'librarian', 'staff', 'viewer']) {
        final user = User.fromJson({
          'id': 42,
          'username': 'user_$role',
          'role': role,
        });
        expect(user.role, role);
      }
    });
  });
}
