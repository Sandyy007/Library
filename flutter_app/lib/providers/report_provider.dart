import 'package:flutter/foundation.dart';
import '../models/report_models.dart';
import '../services/api_service.dart';

class ReportProvider with ChangeNotifier {
  List<PopularBook> _popularBooks = [];
  List<ActiveMember> _activeMembers = [];
  List<MonthlyStats> _monthlyStats = [];
  List<CategoryStats> _categoryStats = [];
  bool _isLoading = false;

  List<PopularBook> get popularBooks => _popularBooks;
  List<ActiveMember> get activeMembers => _activeMembers;
  List<MonthlyStats> get monthlyStats => _monthlyStats;
  List<CategoryStats> get categoryStats => _categoryStats;
  bool get isLoading => _isLoading;

  /// Internal data-only loaders (no _isLoading toggling) for parallel use
  Future<void> _fetchPopularBooks({int limit = 10, String? period}) async {
    try {
      _popularBooks = await ApiService.getPopularBooks(limit: limit, period: period);
      if (kDebugMode) debugPrint('DEBUG [ReportProvider]: Loaded ${_popularBooks.length} popular books');
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [ReportProvider]: Error loading popular books: $e');
    }
  }

  Future<void> _fetchActiveMembers({int limit = 10, String? period}) async {
    try {
      _activeMembers = await ApiService.getActiveMembers(limit: limit, period: period);
      if (kDebugMode) debugPrint('DEBUG [ReportProvider]: Loaded ${_activeMembers.length} active members');
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [ReportProvider]: Error loading active members: $e');
    }
  }

  Future<void> _fetchMonthlyStats({int? year}) async {
    try {
      _monthlyStats = await ApiService.getMonthlyStats(year: year);
      if (kDebugMode) debugPrint('DEBUG [ReportProvider]: Loaded ${_monthlyStats.length} monthly stats');
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [ReportProvider]: Error loading monthly stats: $e');
    }
  }

  Future<void> _fetchCategoryStats() async {
    try {
      _categoryStats = await ApiService.getCategoryStats();
      if (kDebugMode) debugPrint('DEBUG [ReportProvider]: Loaded ${_categoryStats.length} category stats');
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [ReportProvider]: Error loading category stats: $e');
    }
  }

  /// Public single-report loaders (set loading state)
  Future<void> loadPopularBooks({int limit = 10, String? period}) async {
    _isLoading = true;
    notifyListeners();
    await _fetchPopularBooks(limit: limit, period: period);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadActiveMembers({int limit = 10, String? period}) async {
    _isLoading = true;
    notifyListeners();
    await _fetchActiveMembers(limit: limit, period: period);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMonthlyStats({int? year}) async {
    _isLoading = true;
    notifyListeners();
    await _fetchMonthlyStats(year: year);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadCategoryStats() async {
    _isLoading = true;
    notifyListeners();
    await _fetchCategoryStats();
    _isLoading = false;
    notifyListeners();
  }

  /// Load all reports in parallel without _isLoading race condition
  Future<void> loadAllReports() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _fetchPopularBooks(),
        _fetchActiveMembers(),
        _fetchMonthlyStats(),
        _fetchCategoryStats(),
      ]);
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [ReportProvider]: Error loading all reports: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
}
