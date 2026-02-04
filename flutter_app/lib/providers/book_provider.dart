import 'package:flutter/foundation.dart';
import '../models/book.dart';
import '../services/api_service.dart';

class BookProvider with ChangeNotifier {
  List<Book> _books = [];
  bool _isLoading = false;
  String? _error;
  
  // Pagination state
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalBooks = 0;
  bool _hasMore = false;
  static const int _pageSize = 100;
  
  // Filters
  String? _currentSearch;
  String? _currentCategory;

  List<Book> get books => _books;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalBooks => _totalBooks;
  bool get hasMore => _hasMore;

  /// Load first page of books (resets pagination)
  Future<void> loadBooks({String? search, String? category}) async {
    _currentSearch = search;
    _currentCategory = category;
    _currentPage = 1;
    _books = [];
    
    await _fetchPage(1, replace: true);
  }
  
  /// Load next page of books (for infinite scroll)
  Future<void> loadMoreBooks() async {
    if (_isLoading || !_hasMore) return;
    await _fetchPage(_currentPage + 1, replace: false);
  }
  
  /// Load a specific page
  Future<void> loadPage(int page) async {
    if (_isLoading) return;
    await _fetchPage(page, replace: true);
  }
  
  /// Internal method to fetch a page of books
  Future<void> _fetchPage(int page, {required bool replace}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    if (kDebugMode) {
      debugPrint('DEBUG [BookProvider]: Fetching page $page, search=$_currentSearch, category=$_currentCategory');
    }

    try {
      final response = await ApiService.getBooksPaginated(
        search: _currentSearch,
        category: _currentCategory,
        page: page,
        limit: _pageSize,
      );
      
      if (replace) {
        _books = response.data;
      } else {
        _books = [..._books, ...response.data];
      }
      
      _currentPage = response.pagination.page;
      _totalPages = response.pagination.totalPages;
      _totalBooks = response.pagination.total;
      _hasMore = response.pagination.hasMore;
      
      if (kDebugMode) {
        debugPrint('DEBUG [BookProvider]: Loaded ${response.data.length} books, page $_currentPage/$_totalPages, total $_totalBooks');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [BookProvider]: Error loading books: $e');
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addBook(Book book) async {
    try {
      final newBook = await ApiService.addBook(book);
      _books.insert(0, newBook); // Add to beginning of list
      _totalBooks++;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateBook(int id, Book updatedBook) async {
    try {
      await ApiService.updateBook(id, updatedBook);
      final index = _books.indexWhere((b) => b.id == id);
      if (index != -1) {
        _books[index] = updatedBook.copyWith(id: id);
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteBook(int id) async {
    try {
      await ApiService.deleteBook(id);
      _books.removeWhere((b) => b.id == id);
      _totalBooks--;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Delete multiple books
  Future<void> deleteBooks(Set<int> ids) async {
    for (final id in ids) {
      try {
        await ApiService.deleteBook(id);
        _books.removeWhere((b) => b.id == id);
        _totalBooks--;
      } catch (e) {
        if (kDebugMode) debugPrint('DEBUG [BookProvider]: Error deleting book $id: $e');
      }
    }
    notifyListeners();
  }
}
