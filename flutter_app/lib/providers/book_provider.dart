import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/api_service.dart';

class BookProvider with ChangeNotifier {
  List<Book> _books = [];
  bool _isLoading = false;
  String? _error;

  List<Book> get books => _books;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadBooks({String? search, String? category}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    print('DEBUG [BookProvider]: Starting loadBooks, search=$search, category=$category');

    try {
      _books = await ApiService.getBooks(search: search, category: category);
      print('DEBUG [BookProvider]: Successfully loaded ${_books.length} books');
      print('DEBUG [BookProvider]: Sample books: ${_books.take(2).toList()}');
      notifyListeners();
    } catch (e) {
      print('DEBUG [BookProvider]: Error loading books: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addBook(Book book) async {
    try {
      final newBook = await ApiService.addBook(book);
      _books.add(newBook);
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
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}
