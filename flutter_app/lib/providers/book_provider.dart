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

  /// Load ALL books without pagination (for local Hindi search filtering)
  /// This fetches all pages to enable client-side filtering
  Future<void> loadAllBooksForLocalSearch({String? category}) async {
    if (_isLoading) return;
    
    _isLoading = true;
    _error = null;
    _currentSearch = null;
    _currentCategory = category;
    notifyListeners();
    
    if (kDebugMode) {
      debugPrint('DEBUG [BookProvider]: Loading ALL books for local search, category=$category');
    }

    try {
      final allBooks = await ApiService.getBooks(category: category);
      
      _books = allBooks;
      _currentPage = 1;
      _totalPages = 1;
      _totalBooks = allBooks.length;
      _hasMore = false;
      
      if (kDebugMode) {
        debugPrint('DEBUG [BookProvider]: Loaded ALL ${allBooks.length} books for local filtering');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [BookProvider]: Error loading all books: $e');
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
      // Optimistic local insert so the UI reflects the new book immediately.
      // We don't bump _totalBooks because the next paginated fetch would
      // get a stale total; refetch the first page to keep the count honest.
      if (_books.isEmpty) {
        _books = [newBook];
      } else {
        _books = [newBook, ..._books];
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DEBUG [BookProvider]: Error adding book: $e');
      }
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
      if (kDebugMode) {
        debugPrint('DEBUG [BookProvider]: Error updating book: $e');
      }
      rethrow;
    }
  }

  Future<void> deleteBook(int id) async {
    try {
      await ApiService.deleteBook(id);
      _books.removeWhere((b) => b.id == id);
      if (_totalBooks > 0) _totalBooks--;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DEBUG [BookProvider]: Error deleting book: $e');
      }
      rethrow;
    }
  }

  /// Removes a book from the local list only (no API call), returning the
  /// removed book and its index so it can be put back via [restoreBookLocally].
  /// Used by the undo-on-delete flow so the row disappears immediately while
  /// the actual server delete is deferred until the undo window closes.
  ({Book book, int index})? removeBookLocally(int id) {
    final index = _books.indexWhere((b) => b.id == id);
    if (index == -1) return null;
    final book = _books.removeAt(index);
    if (_totalBooks > 0) _totalBooks--;
    notifyListeners();
    return (book: book, index: index);
  }

  /// Re-inserts a locally-removed book at [index] (undo).
  void restoreBookLocally(Book book, int index) {
    final i = index.clamp(0, _books.length);
    _books.insert(i, book);
    _totalBooks++;
    notifyListeners();
  }

  /// Performs the server-side delete only (assumes the book was already
  /// removed locally via [removeBookLocally]).
  Future<void> commitDeleteBook(int id) async {
    await ApiService.deleteBook(id);
  }
  
  /// Delete multiple books using bulk delete API
  Future<void> deleteBooks(Set<int> ids) async {
    if (ids.isEmpty) return;
    try {
      await ApiService.bulkDeleteBooks(ids.toList());
      _books.removeWhere((b) => ids.contains(b.id));
      _totalBooks = (_totalBooks - ids.length).clamp(0, _totalBooks);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG [BookProvider]: Error bulk deleting books: $e');
      rethrow;
    }
  }
}
