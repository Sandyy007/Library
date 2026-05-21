import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/utils/responsive.dart';

void main() {
  group('Breakpoints', () {
    test('has standard threshold values', () {
      expect(Breakpoints.compact, 600);
      expect(Breakpoints.medium, 900);
      expect(Breakpoints.expanded, 1200);
      expect(Breakpoints.extraExpanded, 1600);
    });
  });

  group('Responsive.fromConstraints', () {
    test('isCompact for narrow width', () {
      final r = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 480, maxHeight: 800),
      );
      expect(r.isCompact, true);
      expect(r.isMedium, true);
      expect(r.isExpanded, false);
      expect(r.isExtraExpanded, false);
    });

    test('isMedium but not compact for tablet width', () {
      final r = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 700, maxHeight: 1000),
      );
      expect(r.isCompact, false);
      expect(r.isMedium, true);
      expect(r.isExpanded, false);
    });

    test('isExpanded for desktop width', () {
      final r = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 1400, maxHeight: 900),
      );
      expect(r.isCompact, false);
      expect(r.isMedium, false);
      expect(r.isExpanded, true);
      expect(r.isExtraExpanded, false);
    });

    test('isExtraExpanded for ultra-wide', () {
      final r = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 1920, maxHeight: 1080),
      );
      expect(r.isExtraExpanded, true);
    });

    test('pagePadding scales with width', () {
      final compact = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 400, maxHeight: 800),
      );
      final medium = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 700, maxHeight: 800),
      );
      final expanded = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 1200, maxHeight: 800),
      );

      expect(compact.pagePadding, 8);
      expect(medium.pagePadding, 14);
      expect(expanded.pagePadding, 24);
    });

    test('toolbarPaddingH scales with width', () {
      final compact = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 400, maxHeight: 800),
      );
      final wide = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 1000, maxHeight: 800),
      );

      expect(compact.toolbarPaddingH, 8);
      expect(wide.toolbarPaddingH, 16);
    });

    test('dialogWidth scales appropriately', () {
      final compact = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 400, maxHeight: 800),
      );
      expect(compact.dialogWidth(), closeTo(400 * 0.92, 1));

      final medium = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 700, maxHeight: 800),
      );
      expect(medium.dialogWidth(), closeTo(700 * 0.7, 1));

      final wide = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 1400, maxHeight: 800),
      );
      expect(wide.dialogWidth(), 520);
    });

    test('dialogPadding is smaller on compact', () {
      final compact = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 400, maxHeight: 800),
      );
      final wide = Responsive.fromConstraints(
        const BoxConstraints(maxWidth: 1000, maxHeight: 800),
      );

      expect(compact.dialogPadding.horizontal, 24); // 12 * 2
      expect(wide.dialogPadding.horizontal, 40); // 20 * 2
    });
  });
}
