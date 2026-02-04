import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/providers/auth_provider.dart';
import 'package:library_management_app/models/user.dart';

void main() {
  group('AuthProvider Tests', () {
    test('initial state is not authenticated', () {
      final provider = AuthProvider(
        loginFn: (u, p) async => User(id: 1, username: u, role: 'admin'),
      );
      expect(provider.isAuthenticated, false);
      expect(provider.user, isNull);
      expect(provider.isLoading, false);
    });

    test('login sets authenticated state on success', () async {
      final provider = AuthProvider(
        loginFn: (u, p) async => User(id: 1, username: u, role: 'admin'),
      );

      expect(provider.isAuthenticated, false);

      await provider.login('admin', 'admin');

      expect(provider.isAuthenticated, true);
      expect(provider.user, isNotNull);
      expect(provider.user!.username, 'admin');
      expect(provider.user!.role, 'admin');
    });

    test('login throws on failure', () async {
      final provider = AuthProvider(
        loginFn: (u, p) async => throw Exception('Invalid credentials'),
      );

      expect(
        () => provider.login('wrong', 'wrong'),
        throwsException,
      );

      expect(provider.isAuthenticated, false);
    });

    test('logout clears authentication state', () async {
      final provider = AuthProvider(
        loginFn: (u, p) async => User(id: 1, username: u, role: 'admin'),
        logoutFn: () async {},
      );

      await provider.login('admin', 'admin');
      expect(provider.isAuthenticated, true);

      await provider.logout();

      expect(provider.isAuthenticated, false);
      expect(provider.user, isNull);
    });

    test('isLoading is true during login', () async {
      final provider = AuthProvider(
        loginFn: (u, p) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return User(id: 1, username: u, role: 'admin');
        },
      );

      final loginFuture = provider.login('admin', 'admin');
      
      // Give a tiny bit of time for the async operation to start
      await Future.delayed(const Duration(milliseconds: 10));
      expect(provider.isLoading, true);

      await loginFuture;
      expect(provider.isLoading, false);
    });

    test('rejects non-admin users', () async {
      final provider = AuthProvider(
        loginFn: (u, p) async => User(id: 1, username: u, role: 'user'),
      );

      expect(
        () => provider.login('user', 'password'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
