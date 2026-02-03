import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/report_models.dart';
import '../services/api_service.dart';

class DashboardProvider with ChangeNotifier {
  List<DashboardWidget> _widgets = [];
  bool _isLoading = false;

  List<DashboardWidget> get widgets => _widgets;
  List<DashboardWidget> get visibleWidgets => _widgets.where((w) => w.isVisible).toList()
    ..sort((a, b) => a.position.compareTo(b.position));
  bool get isLoading => _isLoading;

  static final List<DashboardWidget> defaultWidgets = [
    DashboardWidget(name: 'stats_cards', isVisible: true, position: 0),
    DashboardWidget(name: 'charts', isVisible: true, position: 1),
    DashboardWidget(name: 'recent_issues', isVisible: true, position: 2),
    DashboardWidget(name: 'popular_books', isVisible: true, position: 3),
    DashboardWidget(name: 'overdue_alerts', isVisible: true, position: 4),
    DashboardWidget(name: 'quick_actions', isVisible: true, position: 5),
  ];

  Future<void> loadSettings(int userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _widgets = await ApiService.getDashboardSettings(userId);
      if (_widgets.isEmpty) {
        _widgets = List.from(defaultWidgets);
      }
      if (kDebugMode) debugPrint('DEBUG [DashboardProvider]: Loaded ${_widgets.length} dashboard widgets');
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [DashboardProvider]: Error loading dashboard settings: $e');
      _widgets = List.from(defaultWidgets);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveSettings(int userId) async {
    try {
      await ApiService.saveDashboardSettings(userId, _widgets);
      if (kDebugMode) debugPrint('DEBUG [DashboardProvider]: Saved dashboard settings');
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [DashboardProvider]: Error saving dashboard settings: $e');
      rethrow;
    }
  }

  void toggleWidgetVisibility(String widgetName) {
    final index = _widgets.indexWhere((w) => w.name == widgetName);
    if (index != -1) {
      _widgets[index] = _widgets[index].copyWith(isVisible: !_widgets[index].isVisible);
      notifyListeners();
    }
  }

  void reorderWidgets(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final visible = visibleWidgets;
    final item = visible.removeAt(oldIndex);
    visible.insert(newIndex, item);
    
    // Update positions
    for (int i = 0; i < visible.length; i++) {
      final globalIndex = _widgets.indexWhere((w) => w.name == visible[i].name);
      if (globalIndex != -1) {
        _widgets[globalIndex] = _widgets[globalIndex].copyWith(position: i);
      }
    }
    
    notifyListeners();
  }

  void resetToDefaults() {
    _widgets = List.from(defaultWidgets);
    notifyListeners();
  }

  bool isWidgetVisible(String widgetName) {
    final widget = _widgets.firstWhere(
      (w) => w.name == widgetName,
      orElse: () => DashboardWidget(name: widgetName, isVisible: true, position: 999),
    );
    return widget.isVisible;
  }
}
