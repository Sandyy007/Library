import 'package:flutter/foundation.dart';
import '../models/book.dart';
import '../models/member.dart';
import '../models/issue.dart';
import '../services/api_service.dart';
import '../utils/hindi_text.dart';

class SearchProvider with ChangeNotifier {
  List<Book> _searchBooks = [];
  List<Member> _searchMembers = [];
  List<Issue> _searchIssues = [];
  List<Book> _recommendations = [];
  bool _isLoading = false;
  String _lastQuery = '';

  // Advanced search filters
  String _searchType = 'all'; // all, title, author, isbn
  String _categoryFilter = 'all';
  String _availabilityFilter = 'all'; // all, available, borrowed
  String _sortBy = 'title'; // title, author, year, popularity

  List<Book> get searchBooks => _searchBooks;
  List<Member> get searchMembers => _searchMembers;
  List<Issue> get searchIssues => _searchIssues;
  List<Book> get recommendations => _recommendations;
  bool get isLoading => _isLoading;
  String get lastQuery => _lastQuery;
  String get searchType => _searchType;
  String get categoryFilter => _categoryFilter;
  String get availabilityFilter => _availabilityFilter;
  String get sortBy => _sortBy;

  void setSearchType(String type) {
    _searchType = type;
    notifyListeners();
  }

  void setCategoryFilter(String filter) {
    _categoryFilter = filter;
    notifyListeners();
  }

  void setAvailabilityFilter(String filter) {
    _availabilityFilter = filter;
    notifyListeners();
  }

  void setSortBy(String sort) {
    _sortBy = sort;
    notifyListeners();
  }

  void resetFilters() {
    _searchType = 'all';
    _categoryFilter = 'all';
    _availabilityFilter = 'all';
    _sortBy = 'title';
    notifyListeners();
  }

  Future<void> searchAll(String query) async {
    if (query.trim().isEmpty) {
      _clearResults();
      return;
    }

    _isLoading = true;
    _lastQuery = query.trim();
    notifyListeners();

    try {
      // Check if query contains Hindi (Devanagari) characters or looks like Krutidev
      final containsHindi = RegExp(r'[\u0900-\u097F]').hasMatch(query);
      final looksLikeKrutidev = looksLikeLegacyHindi(query);

      if (containsHindi || looksLikeKrutidev) {
        // For Hindi search (Unicode or Krutidev), fetch all data and filter locally
        // since backend may have data in different encodings
        final results = await ApiService.advancedSearch();

        final queryLower = query.toLowerCase();
        final normalizedQuery = normalizeHindiForDisplay(query).toLowerCase();
        final krutiDevQuery = unicodeToKrutiDevApprox(query).toLowerCase();

        // Filter books with comprehensive Hindi matching
        final allBooks = (results['books'])?.cast<Book>() ?? [];
        _searchBooks = allBooks.where((book) {
          final rawTitle = book.title.toLowerCase();
          final rawAuthor = book.author.toLowerCase();
          final normalizedTitle = normalizeHindiForDisplay(
            book.title,
          ).toLowerCase();
          final normalizedAuthor = normalizeHindiForDisplay(
            book.author,
          ).toLowerCase();
          return rawTitle.contains(queryLower) ||
              rawAuthor.contains(queryLower) ||
              normalizedTitle.contains(queryLower) ||
              normalizedAuthor.contains(queryLower) ||
              normalizedTitle.contains(normalizedQuery) ||
              normalizedAuthor.contains(normalizedQuery) ||
              rawTitle.contains(krutiDevQuery) ||
              rawAuthor.contains(krutiDevQuery) ||
              rawTitle.contains(normalizedQuery) ||
              rawAuthor.contains(normalizedQuery);
        }).toList();

        // Filter members with comprehensive Hindi matching
        final allMembers = (results['members'])?.cast<Member>() ?? [];
        _searchMembers = allMembers.where((member) {
          final rawName = member.name.toLowerCase();
          final normalizedName = normalizeHindiForDisplay(
            member.name,
          ).toLowerCase();
          return rawName.contains(queryLower) ||
              normalizedName.contains(queryLower) ||
              normalizedName.contains(normalizedQuery) ||
              rawName.contains(krutiDevQuery) ||
              rawName.contains(normalizedQuery);
        }).toList();

        // Filter issues with comprehensive Hindi matching
        final allIssues = (results['issues'])?.cast<Issue>() ?? [];
        _searchIssues = allIssues.where((issue) {
          final rawTitle = issue.bookTitle.toLowerCase();
          final rawMember = issue.memberName.toLowerCase();
          final normalizedTitle = normalizeHindiForDisplay(
            issue.bookTitle,
          ).toLowerCase();
          final normalizedMember = normalizeHindiForDisplay(
            issue.memberName,
          ).toLowerCase();
          return rawTitle.contains(queryLower) ||
              rawMember.contains(queryLower) ||
              normalizedTitle.contains(queryLower) ||
              normalizedMember.contains(queryLower) ||
              normalizedTitle.contains(normalizedQuery) ||
              normalizedMember.contains(normalizedQuery) ||
              rawTitle.contains(krutiDevQuery) ||
              rawMember.contains(krutiDevQuery) ||
              rawTitle.contains(normalizedQuery) ||
              rawMember.contains(normalizedQuery);
        }).toList();
      } else {
        // For non-Hindi search, use backend search
        final results = await ApiService.advancedSearch(query: query);
        _searchBooks = (results['books'])?.cast<Book>() ?? [];
        _searchMembers = (results['members'])?.cast<Member>() ?? [];
        _searchIssues = (results['issues'])?.cast<Issue>() ?? [];
      }

      notifyListeners();
    } catch (e) {
      _clearResults();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> advancedSearch(String query) async {
    if (query.trim().isEmpty) {
      _searchBooks = [];
      _lastQuery = '';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _lastQuery = query.trim();
    notifyListeners();

    try {
      // Check if query contains Hindi (Devanagari) characters
      final containsHindi = RegExp(r'[\u0900-\u097F]').hasMatch(query);
      // Check if query looks like Krutidev (legacy Hindi encoding)
      final looksLikeKrutidev = looksLikeLegacyHindi(query);

      List<Book> allBooks;
      if (containsHindi || looksLikeKrutidev) {
        // For Hindi search (Unicode or Krutidev), fetch all books and filter locally
        // since backend may have data in different encodings
        final results = await ApiService.advancedSearch(
          category: _categoryFilter == 'all' ? null : _categoryFilter,
          status: _availabilityFilter == 'all' ? null : _availabilityFilter,
        );
        allBooks = (results['books'])?.cast<Book>() ?? [];

        // Filter locally with comprehensive Hindi normalization
        final queryLower = query.toLowerCase();
        // Convert Krutidev query to Unicode for matching
        final normalizedQuery = normalizeHindiForDisplay(query).toLowerCase();
        // Convert Unicode query to KrutiDev for matching legacy data
        final krutiDevQuery = unicodeToKrutiDevApprox(query).toLowerCase();

        _searchBooks = allBooks.where((book) {
          final rawTitle = book.title.toLowerCase();
          final rawAuthor = book.author.toLowerCase();
          final normalizedTitle = normalizeHindiForDisplay(
            book.title,
          ).toLowerCase();
          final normalizedAuthor = normalizeHindiForDisplay(
            book.author,
          ).toLowerCase();

          // Match all combinations of query and data encodings
          return rawTitle.contains(queryLower) ||
              rawAuthor.contains(queryLower) ||
              normalizedTitle.contains(queryLower) ||
              normalizedAuthor.contains(queryLower) ||
              normalizedTitle.contains(normalizedQuery) ||
              normalizedAuthor.contains(normalizedQuery) ||
              rawTitle.contains(krutiDevQuery) ||
              rawAuthor.contains(krutiDevQuery) ||
              rawTitle.contains(normalizedQuery) ||
              rawAuthor.contains(normalizedQuery);
        }).toList();
      } else {
        // For non-Hindi search, use backend search
        final results = await ApiService.advancedSearch(
          query: query,
          category: _categoryFilter == 'all' ? null : _categoryFilter,
          status: _availabilityFilter == 'all' ? null : _availabilityFilter,
        );
        _searchBooks = (results['books'])?.cast<Book>() ?? [];
      }

      if (kDebugMode) {
        debugPrint(
          'DEBUG [SearchProvider]: Found ${_searchBooks.length} results for "$query"',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DEBUG [SearchProvider]: Error in advanced search: $e');
      }
      _searchBooks = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadRecommendations(int memberId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _recommendations = await ApiService.getRecommendations(memberId);
      if (kDebugMode) {
        debugPrint(
          'DEBUG [SearchProvider]: Loaded ${_recommendations.length} recommendations',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DEBUG [SearchProvider]: Error loading recommendations: $e');
      }
      _recommendations = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearRecommendations() {
    _recommendations = [];
    notifyListeners();
  }

  void _clearResults() {
    _searchBooks = [];
    _searchMembers = [];
    _searchIssues = [];
    _lastQuery = '';
    notifyListeners();
  }

  void clearSearch() {
    _clearResults();
  }
}
