import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/utils/theme.dart';

/// Unit tests for the layered elevation tokens. AppTheme construction itself is
/// covered by the widget tests that mount full screens (they build the themes),
/// so we keep this file to the pure token logic that has no existing coverage.
void main() {
  group('AppShadows', () {
    const shadow = Color(0xFF000000);

    test('every elevation returns a layered (2-shadow) stack', () {
      for (final isDark in [true, false]) {
        expect(AppShadows.sm(shadow, isDark).length, 2,
            reason: 'sm should stack an ambient + key shadow');
        expect(AppShadows.md(shadow, isDark).length, 2);
        expect(AppShadows.lg(shadow, isDark).length, 2);
      }
    });

    test('elevation grows the key shadow blur (sm < md < lg)', () {
      final sm = AppShadows.sm(shadow, false).last.blurRadius;
      final md = AppShadows.md(shadow, false).last.blurRadius;
      final lg = AppShadows.lg(shadow, false).last.blurRadius;
      expect(sm, lessThan(md));
      expect(md, lessThan(lg));
    });

    test('dark shadows are more opaque than light ones', () {
      final darkAlpha = AppShadows.md(shadow, true).last.color.a;
      final lightAlpha = AppShadows.md(shadow, false).last.color.a;
      expect(darkAlpha, greaterThan(lightAlpha));
    });
  });
}
