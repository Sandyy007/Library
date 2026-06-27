import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/providers/dashboard_provider.dart';

// DashboardProvider's persistence (loadSettings/saveSettings) uses package-level
// http.* and is covered by the backend integration suite. Here we test the
// pure widget-arrangement logic, which is fully deterministic and offline.

void main() {
  group('DashboardProvider widget logic', () {
    test('resetToDefaults seeds the default widget set', () {
      final provider = DashboardProvider();
      provider.resetToDefaults();
      expect(provider.widgets, hasLength(DashboardProvider.defaultWidgets.length));
    });

    test('visibleWidgets are sorted by position and exclude hidden ones', () {
      final provider = DashboardProvider();
      provider.resetToDefaults();

      final visible = provider.visibleWidgets;
      expect(visible, isNotEmpty);
      // Sorted ascending by position.
      for (var i = 0; i < visible.length - 1; i++) {
        expect(visible[i].position <= visible[i + 1].position, true);
      }
    });

    test('toggleWidgetVisibility hides then shows a widget', () {
      final provider = DashboardProvider();
      provider.resetToDefaults();

      const name = 'charts';
      expect(provider.isWidgetVisible(name), true);

      provider.toggleWidgetVisibility(name);
      expect(provider.isWidgetVisible(name), false);
      expect(provider.visibleWidgets.any((w) => w.name == name), false);

      provider.toggleWidgetVisibility(name);
      expect(provider.isWidgetVisible(name), true);
    });

    test('isWidgetVisible defaults to true for unknown widgets', () {
      final provider = DashboardProvider();
      provider.resetToDefaults();
      expect(provider.isWidgetVisible('does_not_exist'), true);
    });

    test('reorderWidgets moves a widget to a new position', () {
      final provider = DashboardProvider();
      provider.resetToDefaults();

      final before = provider.visibleWidgets.map((w) => w.name).toList();
      expect(before.length, greaterThan(2));

      // Move the first widget to the end.
      provider.reorderWidgets(0, before.length);

      final after = provider.visibleWidgets.map((w) => w.name).toList();
      expect(after.first, before[1]);
      expect(after.last, before.first);
      expect(after.toSet(), before.toSet()); // same set, different order
    });
  });
}
