import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/issue.dart';
import '../services/api_service.dart';

class IssueProvider with ChangeNotifier {
  List<Issue> _issues = [];
  bool _isLoading = false;
  Map<String, int> _stats = {};
  String? _error;

  List<Issue> get issues => _issues;
  bool get isLoading => _isLoading;
  Map<String, int> get stats => _stats;
  String? get error => _error;

  Future<void> loadIssues() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    if (kDebugMode) debugPrint('DEBUG [IssueProvider]: Starting loadIssues');

    try {
      _issues = await ApiService.getIssues();
      if (kDebugMode) debugPrint('DEBUG [IssueProvider]: Successfully loaded ${_issues.length} issues');
      if (kDebugMode) debugPrint('DEBUG [IssueProvider]: Sample issues: ${_issues.take(2).toList()}');
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [IssueProvider]: Error loading issues: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
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
      await loadIssues();
      await loadStats();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> returnBook(int issueId) async {
    try {
      await ApiService.returnBook(issueId);
      await loadIssues();
      await loadStats();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateIssue(int issueId, {String? dueDate, String? returnDate, String? status}) async {
    try {
      await ApiService.updateIssue(issueId, dueDate: dueDate, returnDate: returnDate, status: status);
      await loadIssues();
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
}
