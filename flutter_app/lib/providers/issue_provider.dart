import 'package:flutter/foundation.dart';
import '../models/issue.dart';
import '../services/api_service.dart';

class IssueProvider with ChangeNotifier {
  List<Issue> _issues = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  Map<String, int> _stats = {};
  String? _error;
  
  // Pagination state
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalIssues = 0;
  bool _hasMore = false;
  final int _pageSize = 100;
  
  // Current filters
  int? _memberId;
  int? _bookId;
  String? _statusFilter;

  List<Issue> get issues => _issues;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  Map<String, int> get stats => _stats;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalIssues => _totalIssues;
  bool get hasMore => _hasMore;

  /// Load first page of issues (clears existing data)
  Future<void> loadIssues({int? memberId, int? bookId, String? status}) async {
    _isLoading = true;
    _error = null;
    _currentPage = 1;
    _issues = [];
    _memberId = memberId;
    _bookId = bookId;
    _statusFilter = status;
    notifyListeners();
    if (kDebugMode) debugPrint('DEBUG [IssueProvider]: Starting loadIssues');

    try {
      final response = await ApiService.getIssuesPaginated(
        memberId: _memberId,
        bookId: _bookId,
        status: _statusFilter,
        page: 1,
        limit: _pageSize,
      );
      
      _issues = response.data;
      _currentPage = response.pagination.page;
      _totalPages = response.pagination.totalPages;
      _totalIssues = response.pagination.total;
      _hasMore = response.pagination.hasMore;
      
      if (kDebugMode) {
        debugPrint('DEBUG [IssueProvider]: Loaded page $_currentPage of $_totalPages');
        debugPrint('DEBUG [IssueProvider]: Got ${_issues.length} issues, total: $_totalIssues');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [IssueProvider]: Error loading issues: $e');
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load more issues (next page)
  Future<void> loadMoreIssues() async {
    if (_isLoadingMore || !_hasMore) return;
    
    _isLoadingMore = true;
    notifyListeners();
    
    try {
      final nextPage = _currentPage + 1;
      final response = await ApiService.getIssuesPaginated(
        memberId: _memberId,
        bookId: _bookId,
        status: _statusFilter,
        page: nextPage,
        limit: _pageSize,
      );
      
      _issues.addAll(response.data);
      _currentPage = response.pagination.page;
      _hasMore = response.pagination.hasMore;
      
      if (kDebugMode) {
        debugPrint('DEBUG [IssueProvider]: Loaded more, now at page $_currentPage');
        debugPrint('DEBUG [IssueProvider]: Total issues now: ${_issues.length}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [IssueProvider]: Error loading more issues: $e');
      _error = e.toString();
    }
    
    _isLoadingMore = false;
    notifyListeners();
  }

  /// Load specific page
  Future<void> loadPage(int page) async {
    if (page < 1 || page > _totalPages || _isLoading) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await ApiService.getIssuesPaginated(
        memberId: _memberId,
        bookId: _bookId,
        status: _statusFilter,
        page: page,
        limit: _pageSize,
      );
      
      _issues = response.data;
      _currentPage = response.pagination.page;
      _totalPages = response.pagination.totalPages;
      _totalIssues = response.pagination.total;
      _hasMore = response.pagination.hasMore;
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [IssueProvider]: Error loading page $page: $e');
      _error = e.toString();
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadStats() async {
    try {
      if (kDebugMode) debugPrint('DEBUG [IssueProvider]: Starting loadStats');
      _stats = await ApiService.getDashboardStats();
      if (kDebugMode) debugPrint('DEBUG [IssueProvider]: Successfully loaded dashboard stats: $_stats');
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [IssueProvider]: Error loading stats: $e');
      rethrow;
    }
  }

  Future<void> issueBook(int bookId, int memberId, String dueDate) async {
    try {
      await ApiService.issueBook(bookId, memberId, dueDate);
      await loadIssues(memberId: _memberId, bookId: _bookId, status: _statusFilter);
      await loadStats();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> returnBook(int issueId) async {
    try {
      await ApiService.returnBook(issueId);
      await loadIssues(memberId: _memberId, bookId: _bookId, status: _statusFilter);
      await loadStats();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateIssue(int issueId, {String? dueDate, String? returnDate, String? status}) async {
    try {
      await ApiService.updateIssue(issueId, dueDate: dueDate, returnDate: returnDate, status: status);
      await loadIssues(memberId: _memberId, bookId: _bookId, status: _statusFilter);
      await loadStats();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getIssuedReport() async {
    try {
      return await ApiService.getIssuedReport();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getOverdueReport() async {
    try {
      return await ApiService.getOverdueReport();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Refresh data (reload current page)
  Future<void> refresh() async {
    await loadIssues(memberId: _memberId, bookId: _bookId, status: _statusFilter);
  }
}
