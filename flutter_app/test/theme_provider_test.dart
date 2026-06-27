import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:library_management_app/providers/theme_provider.dart';

// We assert on the provider's own state (isDarkMode) and its persistence.
// We avoid touching `currentTheme`, since building AppTheme pulls in
// google_fonts which attempts a network fetch under the test sandbox.

/// Wait for the provider's async _loadThemeFromPrefs (SharedPreferences.getInstance)
/// to finish before interacting with it.
Future<ThemeProvider> _readyProvider() async {
  final provider = ThemeProvider();
  await Future.delayed(const Duration(milliseconds: 20));
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeProvider', () {
    test('defaults to light mode when no preference stored', () async {
      final provider = await _readyProvider();
      expect(provider.isDarkMode, false);
    });

    test('reads stored dark-mode preference', () async {
      SharedPreferences.setMockInitialValues({'isDarkMode': true});
      final provider = await _readyProvider();
      expect(provider.isDarkMode, true);
    });

    test('toggleTheme flips and persists the value', () async {
      final provider = await _readyProvider();
      expect(provider.isDarkMode, false);

      await provider.toggleTheme();
      expect(provider.isDarkMode, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isDarkMode'), true);

      await provider.toggleTheme();
      expect(provider.isDarkMode, false);
      expect(prefs.getBool('isDarkMode'), false);
    });

    test('setTheme sets the value explicitly and persists it', () async {
      final provider = await _readyProvider();
      await provider.setTheme(true);
      expect(provider.isDarkMode, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isDarkMode'), true);

      await provider.setTheme(false);
      expect(provider.isDarkMode, false);
    });
  });
}
