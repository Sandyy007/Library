import 'package:flutter/foundation.dart';
import '../models/member.dart';
import '../services/api_service.dart';

class MemberProvider with ChangeNotifier {
  List<Member> _members = [];
  bool _isLoading = false;
  String? _error;
  
  // Pagination state
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalMembers = 0;
  bool _hasMore = false;
  static const int _pageSize = 100;
  
  // Filters
  String? _currentSearch;
  String? _currentType;

  List<Member> get members => _members;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalMembers => _totalMembers;
  bool get hasMore => _hasMore;

  /// Load first page of members (resets pagination)
  Future<void> loadMembers({String? search, String? type}) async {
    _currentSearch = search;
    _currentType = type;
    _currentPage = 1;
    _members = [];
    
    await _fetchPage(1, replace: true);
  }
  
  /// Load next page of members
  Future<void> loadMoreMembers() async {
    if (_isLoading || !_hasMore) return;
    await _fetchPage(_currentPage + 1, replace: false);
  }
  
  /// Load a specific page
  Future<void> loadPage(int page) async {
    if (_isLoading) return;
    await _fetchPage(page, replace: true);
  }
  
  /// Internal method to fetch a page
  Future<void> _fetchPage(int page, {required bool replace}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    if (kDebugMode) {
      debugPrint('DEBUG [MemberProvider]: Fetching page $page');
    }

    try {
      final response = await ApiService.getMembersPaginated(
        search: _currentSearch,
        type: _currentType,
        page: page,
        limit: _pageSize,
      );
      
      if (replace) {
        _members = response.data;
      } else {
        _members = [..._members, ...response.data];
      }
      
      _currentPage = response.pagination.page;
      _totalPages = response.pagination.totalPages;
      _totalMembers = response.pagination.total;
      _hasMore = response.pagination.hasMore;
      
      if (kDebugMode) {
        debugPrint('DEBUG [MemberProvider]: Loaded ${response.data.length} members, page $_currentPage/$_totalPages');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [MemberProvider]: Error loading members: $e');
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addMember(Member member) async {
    try {
      final newMember = await ApiService.addMember(member);
      _members.insert(0, newMember);
      _totalMembers++;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateMember(int id, Member updatedMember) async {
    try {
      await ApiService.updateMember(id, updatedMember);
      final index = _members.indexWhere((m) => m.id == id);
      if (index != -1) {
        _members[index] = updatedMember.copyWith(id: id);
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteMember(int id) async {
    try {
      await ApiService.deleteMember(id);
      _members.removeWhere((m) => m.id == id);
      _totalMembers--;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}
