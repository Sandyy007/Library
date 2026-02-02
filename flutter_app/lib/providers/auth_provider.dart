import 'package:flutter/material.dart';
import 'dart:async';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  late final StreamSubscription<void> _unauthorizedSub;

  final Future<User> Function(String username, String password) _loginFn;
  final Future<void> Function() _logoutFn;
  final Future<String?> Function() _getTokenFn;
  final Future<User> Function() _getMeFn;

  AuthProvider({
    Future<User> Function(String username, String password)? loginFn,
    Future<void> Function()? logoutFn,
    Future<String?> Function()? getTokenFn,
    Future<User> Function()? getMeFn,
  })  : _loginFn = loginFn ?? ApiService.login,
        _logoutFn = logoutFn ?? ApiService.logout,
        _getTokenFn = getTokenFn ?? ApiService.getToken,
        _getMeFn = getMeFn ?? ApiService.getMe {
    _unauthorizedSub = ApiService.unauthorizedStream.listen((_) {
      // Token became invalid/expired during runtime.
      _user = null;
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  Future<void> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _loginFn(username, password);
      
      // Only allow admin role
      if (user.role != 'admin') {
        throw Exception('Only admin users are allowed to access this system');
      }
      
      _user = user;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await _logoutFn();
    _user = null;
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    final token = await _getTokenFn().timeout(
      const Duration(milliseconds: 500),
      onTimeout: () => null,
    );
    if (token == null) return;

    try {
      final me = await _getMeFn();
      if (me.role != 'admin') {
        await logout();
        return;
      }
      _user = me;
      notifyListeners();
    } catch (_) {
      // Token missing/expired/invalid.
      await logout();
    }
  }

  @override
  void dispose() {
    _unauthorizedSub.cancel();
    super.dispose();
  }
}
