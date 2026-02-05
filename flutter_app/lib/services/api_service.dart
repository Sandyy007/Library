import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/book.dart';
import '../models/member.dart';
import '../models/issue.dart';
import '../models/notification.dart';
import '../models/report_models.dart';

class ApiService {
  // Configure at build time:
  // flutter run --dart-define=API_BASE_URL=https://example.com/api --dart-define=API_SERVER_ORIGIN=https://example.com
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );
  static const String serverOrigin = String.fromEnvironment(
    'API_SERVER_ORIGIN',
    defaultValue: 'http://localhost:3000',
  );
  static const Duration timeout = Duration(
    seconds: 15,
  ); // Reduced for faster feedback
  static const Duration longTimeout = Duration(
    minutes: 10,
  ); // For large file uploads

  // Persistent HTTP client for connection reuse (keep-alive)
  static final http.Client _client = http.Client();

  // Cache duration for categories
  static const Duration _categoriesCacheDuration = Duration(minutes: 5);

  static const String _tokenKey = 'token';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static final StreamController<void> _unauthorizedController =
      StreamController<void>.broadcast();
  static Stream<void> get unauthorizedStream => _unauthorizedController.stream;

  static final StreamController<void> _dataChangedController =
      StreamController<void>.broadcast();
  static Stream<void> get dataChangedStream => _dataChangedController.stream;

  static void _notifyDataChanged() {
    if (!_dataChangedController.isClosed) {
      _dataChangedController.add(null);
    }
  }

  static Future<void> _throwIfUnauthorized(http.Response response) async {
    if (response.statusCode == 401 || response.statusCode == 403) {
      await clearToken();
      _unauthorizedController.add(null);
      throw Exception('Session expired. Please login again.');
    }
  }

  /// Throws appropriate exception for rate limit (429) responses
  static void _throwIfRateLimited(http.Response response, [String? context]) {
    if (response.statusCode == 429) {
      throw Exception(
        context ?? 'Too many requests. Please wait a moment and try again.',
      );
    }
  }

  /// Safely parses JSON error response, returns null if parsing fails
  static String? _parseErrorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }
    } catch (_) {
      // Response is not valid JSON
    }
    return null;
  }

  /// Standard error handler for API responses - handles 429, auth, and JSON parsing
  static void _handleErrorResponse(http.Response response, String operation) {
    _throwIfRateLimited(
      response,
      'Too many requests during $operation. Please wait.',
    );
    final errorMsg = _parseErrorMessage(response);
    throw Exception(
      errorMsg ??
          '$operation failed: ${response.reasonPhrase ?? 'Unknown error'}',
    );
  }

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static String resolvePublicUrl(String urlOrPath) {
    if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
      return urlOrPath;
    }
    if (urlOrPath.startsWith('/')) {
      return '$serverOrigin$urlOrPath';
    }
    return '$serverOrigin/$urlOrPath';
  }

  static MediaType _guessImageMediaType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.bmp')) return MediaType('image', 'bmp');
    if (lower.endsWith('.tif') || lower.endsWith('.tiff')) {
      return MediaType('image', 'tiff');
    }
    if (lower.endsWith('.ico')) return MediaType('image', 'x-icon');
    if (lower.endsWith('.svg')) return MediaType('image', 'svg+xml');
    // Fallback so the backend's `/image\//` mimetype check passes.
    return MediaType('image', 'jpeg');
  }

  static Future<String?> getToken() async {
    // flutter_secure_storage has limited support on some web targets.
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    }
    try {
      final token = await _secureStorage.read(key: _tokenKey);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {
      // Fall back below.
    }

    // Fallback for desktop targets where secure storage may be unavailable or
    // misconfigured.
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setToken(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      return;
    }
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
    } catch (_) {
      // Ignore when secure storage is unavailable (e.g., widget tests).
    }

    // Always also store in SharedPreferences as a fallback for desktop.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (_) {
      // Ignore.
    }
  }

  static Future<void> clearToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      return;
    }
    try {
      await _secureStorage.delete(key: _tokenKey);
    } catch (_) {
      // Ignore when secure storage is unavailable (e.g., widget tests).
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {
      // Ignore.
    }
  }

  static Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<bool> testConnection() async {
    try {
      _log('DEBUG: Testing connection to $baseUrl');
      final response = await http
          .get(Uri.parse(serverOrigin), headers: await getHeaders())
          .timeout(timeout);
      _log('DEBUG: Connection test response: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 404;
    } catch (e) {
      _log('DEBUG: Connection test failed: $e');
      return false;
    }
  }

  // ==================== AUTH ====================

  static Future<User> login(String username, String password) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await setToken(data['token']);
        return User.fromJson(data['user']);
      } else if (response.statusCode == 429) {
        // Rate limited
        throw Exception(
          'Too many login attempts. Please wait a moment and try again.',
        );
      } else {
        // Try to parse error from JSON response
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['error'] ?? 'Login failed');
        } catch (e) {
          if (e is FormatException) {
            // Response is not valid JSON
            throw Exception(
              'Login failed: ${response.reasonPhrase ?? 'Unknown error'}',
            );
          }
          rethrow;
        }
      }
    } on SocketException catch (_) {
      throw Exception(
        'Cannot connect to server. Please check your connection.',
      );
    } on TimeoutException catch (_) {
      throw Exception('Connection timed out. Please try again.');
    }
  }

  static Future<void> logout() async {
    await clearToken();
  }

  static Future<User> getMe() async {
    try {
      final headers = await getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/auth/me'), headers: headers)
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return User.fromJson(data['user']);
      }

      _throwIfRateLimited(response, 'Too many requests. Please wait.');
      await _throwIfUnauthorized(response);
      _handleErrorResponse(response, 'Loading user');
      throw Exception('Failed to load current user');
    } on SocketException catch (_) {
      throw Exception(
        'Cannot connect to server. Please check your connection.',
      );
    } on TimeoutException catch (_) {
      throw Exception('Connection timed out. Please try again.');
    }
  }

  // ==================== BOOKS ====================

  /// Paginated response for books
  static Future<BooksResponse> getBooksPaginated({
    String? search,
    String? category,
    String? author,
    int? year,
    String? status,
    bool? available,
    int page = 1,
    int limit = 100,
  }) async {
    final headers = await getHeaders();
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }
    if (author != null && author.isNotEmpty) queryParams['author'] = author;
    if (year != null) queryParams['year'] = year.toString();
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (available == true) queryParams['available'] = 'true';

    final uri = Uri.parse(
      '$baseUrl/books',
    ).replace(queryParameters: queryParams);
    _log('DEBUG: Fetching books paginated from $uri');

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(timeout);
      _log('DEBUG: Books response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return BooksResponse.fromJson(decoded);
      } else {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Loading books');
        throw Exception('Failed to load books');
      }
    } on SocketException catch (e) {
      _log('DEBUG: Socket error loading books: $e');
      throw Exception(
        'Cannot connect to server. Make sure backend is running at $serverOrigin',
      );
    } on TimeoutException catch (e) {
      _log('DEBUG: Timeout loading books: $e');
      throw Exception('Request timeout. Server is not responding.');
    } catch (e) {
      _log('DEBUG: Error loading books: $e');
      rethrow;
    }
  }

  /// Get all books (loads all pages for backward compatibility)
  /// For large datasets, prefer getBooksPaginated
  static Future<List<Book>> getBooks({
    String? search,
    String? category,
    String? author,
    int? year,
    String? status,
    bool? available,
  }) async {
    final headers = await getHeaders();
    final queryParams = <String, String>{
      'limit': '1000', // Get more books per page for efficiency
    };
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }
    if (author != null && author.isNotEmpty) queryParams['author'] = author;
    if (year != null) queryParams['year'] = year.toString();
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (available == true) queryParams['available'] = 'true';

    try {
      final List<Book> allBooks = [];
      int currentPage = 1;
      bool hasMore = true;

      while (hasMore) {
        queryParams['page'] = currentPage.toString();
        final uri = Uri.parse(
          '$baseUrl/books',
        ).replace(queryParameters: queryParams);
        _log('DEBUG: Fetching books page $currentPage from $uri');

        final response = await _client
            .get(uri, headers: headers)
            .timeout(timeout);
        _log('DEBUG: Books response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);

          // Handle both old (array) and new (paginated) response formats
          if (decoded is List) {
            // Old format: just an array of books
            _log('DEBUG: Parsed ${decoded.length} books (legacy format)');
            return decoded.map((json) => Book.fromJson(json)).toList();
          } else if (decoded is Map<String, dynamic>) {
            // New format: paginated response
            final data = decoded['data'] as List<dynamic>? ?? [];
            final pagination = decoded['pagination'] as Map<String, dynamic>?;

            allBooks.addAll(data.map((json) => Book.fromJson(json)));
            _log(
              'DEBUG: Loaded page $currentPage with ${data.length} books (total so far: ${allBooks.length})',
            );

            hasMore = pagination?['hasMore'] == true;
            currentPage++;
          } else {
            throw Exception('Unexpected response format');
          }
        } else {
          _throwIfRateLimited(response);
          await _throwIfUnauthorized(response);
          _handleErrorResponse(response, 'Loading books');
          throw Exception('Failed to load books');
        }
      }

      _log('DEBUG: Total books loaded: ${allBooks.length}');
      return allBooks;
    } on SocketException catch (e) {
      _log('DEBUG: Socket error loading books: $e');
      throw Exception(
        'Cannot connect to server. Make sure backend is running at $serverOrigin',
      );
    } on TimeoutException catch (e) {
      _log('DEBUG: Timeout loading books: $e');
      throw Exception('Request timeout. Server is not responding.');
    } catch (e) {
      _log('DEBUG: Error loading books: $e');
      rethrow;
    }
  }

  static Future<Book> getBook(int id) async {
    try {
      final headers = await getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/books/$id'), headers: headers)
          .timeout(timeout);

      if (response.statusCode == 200) {
        return Book.fromJson(jsonDecode(response.body));
      } else {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Loading book');
        throw Exception('Failed to load book');
      }
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Request timed out.');
    }
  }

  static Future<Book> addBook(Book book) async {
    final headers = await getHeaders();
    _log('DEBUG: Adding book: ${book.title}');
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/books'),
            headers: headers,
            body: jsonEncode(book.toJson()),
          )
          .timeout(timeout);

      _log('DEBUG: Add book response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _log('DEBUG: Book added with id: ${data['id']}');
        _notifyDataChanged();
        return book.copyWith(id: data['id']);
      } else {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Adding book');
        throw Exception('Failed to add book');
      }
    } on SocketException catch (e) {
      _log('DEBUG: Socket error adding book: $e');
      throw Exception(
        'Cannot connect to server. Make sure backend is running at $serverOrigin',
      );
    } on TimeoutException catch (e) {
      _log('DEBUG: Timeout adding book: $e');
      throw Exception('Request timeout. Server is not responding.');
    } catch (e) {
      _log('DEBUG: Error adding book: $e');
      rethrow;
    }
  }

  static Future<void> updateBook(int id, Book book) async {
    final headers = await getHeaders();
    _log('DEBUG: Updating book $id: ${book.title}');
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/books/$id'),
            headers: headers,
            body: jsonEncode(book.toJson()),
          )
          .timeout(timeout);

      _log('DEBUG: Update book response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Updating book');
      }
      _notifyDataChanged();
    } on SocketException catch (e) {
      _log('DEBUG: Socket error updating book: $e');
      throw Exception(
        'Cannot connect to server. Make sure backend is running at http://localhost:3000',
      );
    } on TimeoutException catch (e) {
      _log('DEBUG: Timeout updating book: $e');
      throw Exception('Request timeout. Server is not responding.');
    } catch (e) {
      _log('DEBUG: Error updating book: $e');
      rethrow;
    }
  }

  static Future<void> deleteBook(int id) async {
    final headers = await getHeaders();
    _log('DEBUG: Deleting book $id');
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/books/$id'), headers: headers)
          .timeout(timeout);

      _log('DEBUG: Delete book response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Deleting book');
      }
      _notifyDataChanged();
    } on SocketException catch (e) {
      _log('DEBUG: Socket error deleting book: $e');
      throw Exception(
        'Cannot connect to server. Make sure backend is running at http://localhost:3000',
      );
    } on TimeoutException catch (e) {
      _log('DEBUG: Timeout deleting book: $e');
      throw Exception('Request timeout. Server is not responding.');
    } catch (e) {
      _log('DEBUG: Error deleting book: $e');
      rethrow;
    }
  }

  /// Bulk delete books - optimized for large deletions
  static Future<Map<String, dynamic>> bulkDeleteBooks(List<int> ids) async {
    final headers = await getHeaders();
    _log('DEBUG: Bulk deleting ${ids.length} books');
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/books/bulk-delete'),
            headers: headers,
            body: jsonEncode({'ids': ids}),
          )
          .timeout(longTimeout); // Use long timeout for bulk operations

      _log('DEBUG: Bulk delete response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Bulk deleting books');
      }
      _notifyDataChanged();
      return jsonDecode(response.body);
    } on SocketException catch (e) {
      _log('DEBUG: Socket error bulk deleting books: $e');
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (e) {
      _log('DEBUG: Timeout bulk deleting books: $e');
      throw Exception('Request timeout. Server is not responding.');
    } catch (e) {
      _log('DEBUG: Error bulk deleting books: $e');
      rethrow;
    }
  }

  /// Bulk delete members - optimized for large deletions
  static Future<Map<String, dynamic>> bulkDeleteMembers(List<int> ids) async {
    final headers = await getHeaders();
    _log('DEBUG: Bulk deleting ${ids.length} members');
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/members/bulk-delete'),
            headers: headers,
            body: jsonEncode({'ids': ids}),
          )
          .timeout(longTimeout); // Use long timeout for bulk operations

      _log(
        'DEBUG: Bulk delete members response status: ${response.statusCode}',
      );
      if (response.statusCode != 200) {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Bulk deleting members');
      }
      _notifyDataChanged();
      return jsonDecode(response.body);
    } on SocketException catch (e) {
      _log('DEBUG: Socket error bulk deleting members: $e');
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (e) {
      _log('DEBUG: Timeout bulk deleting members: $e');
      throw Exception('Request timeout. Server is not responding.');
    } catch (e) {
      _log('DEBUG: Error bulk deleting members: $e');
      rethrow;
    }
  }

  /// Bulk delete issues - optimized for large deletions
  static Future<Map<String, dynamic>> bulkDeleteIssues(List<int> ids) async {
    final headers = await getHeaders();
    _log('DEBUG: Bulk deleting ${ids.length} issues');
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/issues/bulk-delete'),
            headers: headers,
            body: jsonEncode({'ids': ids}),
          )
          .timeout(longTimeout); // Use long timeout for bulk operations

      _log('DEBUG: Bulk delete issues response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Bulk deleting issues');
      }
      _notifyDataChanged();
      return jsonDecode(response.body);
    } on SocketException catch (e) {
      _log('DEBUG: Socket error bulk deleting issues: $e');
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (e) {
      _log('DEBUG: Timeout bulk deleting issues: $e');
      throw Exception('Request timeout. Server is not responding.');
    } catch (e) {
      _log('DEBUG: Error bulk deleting issues: $e');
      rethrow;
    }
  }

  /// Import books from CSV/XLSX file. Uses long timeout for large files (10k+ books).
  static Future<Map<String, dynamic>> importBooksFile({
    required String filePath,
    String fieldName = 'file',
  }) async {
    final uri = Uri.parse('$baseUrl/books/import');
    final request = http.MultipartRequest('POST', uri);

    final token = await getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final file = File(filePath);
    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'books_import';
    final lower = fileName.toLowerCase();

    MediaType? contentType;
    if (lower.endsWith('.csv')) {
      contentType = MediaType('text', 'csv');
    } else if (lower.endsWith('.xlsx')) {
      contentType = MediaType(
        'application',
        'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } else if (lower.endsWith('.xls')) {
      contentType = MediaType('application', 'vnd.ms-excel');
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        fieldName,
        filePath,
        filename: fileName,
        contentType: contentType,
      ),
    );

    // Use long timeout for large file imports (10k+ books can take several minutes)
    final response = await request.send().timeout(longTimeout);
    final body = await response.stream.bytesToString();

    if (response.statusCode == 401 || response.statusCode == 403) {
      await clearToken();
      _unauthorizedController.add(null);
      throw Exception('Session expired. Please login again.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'ok': true, 'data': decoded};
    }

    throw Exception(
      'Import failed: ${response.statusCode} - ${body.isEmpty ? 'No response body' : body}',
    );
  }

  // ==================== CATEGORIES ====================

  // Cache for categories list
  static List<BookCategory>? _categoriesListCache;
  static DateTime? _categoriesListCacheTime;

  /// Clear categories cache (call after adding new category)
  static void clearCategoriesCache() {
    _categoriesListCache = null;
    _categoriesListCacheTime = null;
  }

  static Future<List<BookCategory>> getCategories({
    bool forceRefresh = false,
  }) async {
    // Return cached data if still valid
    if (!forceRefresh &&
        _categoriesListCache != null &&
        _categoriesListCacheTime != null &&
        DateTime.now().difference(_categoriesListCacheTime!) <
            _categoriesCacheDuration) {
      return _categoriesListCache!;
    }

    final headers = await getHeaders();
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/categories'), headers: headers)
          .timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final categories = data
            .map((json) => BookCategory.fromJson(json))
            .toList();
        // Cache the result
        _categoriesListCache = categories;
        _categoriesListCacheTime = DateTime.now();
        return categories;
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (e) {
      _log('DEBUG: Error loading categories: $e');
      // Return cached data if available, otherwise defaults
      if (_categoriesListCache != null) {
        return _categoriesListCache!;
      }
      // Return default categories on error
      return [
            'Fiction',
            'Non-Fiction',
            'Science',
            'History',
            'Biography',
            'Technology',
            'Computer Science',
            'Literature',
            'Philosophy',
          ]
          .asMap()
          .entries
          .map((e) => BookCategory(id: e.key + 1, name: e.value))
          .toList();
    }
  }

  static Future<void> addCategory(String name, String? description) async {
    final headers = await getHeaders();
    final response = await _client
        .post(
          Uri.parse('$baseUrl/categories'),
          headers: headers,
          body: jsonEncode({'name': name, 'description': description}),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('Failed to add category');
    }
    // Clear cache so new category is fetched
    clearCategoriesCache();
  }

  // ==================== MEMBERS ====================

  /// Get all members (loads all pages for backward compatibility)
  static Future<List<Member>> getMembers({
    String? search,
    String? type,
    bool? active,
  }) async {
    final headers = await getHeaders();
    final queryParams = <String, String>{
      'limit': '1000', // Get more members per page
    };
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (type != null && type.isNotEmpty) queryParams['type'] = type;
    if (active != null) queryParams['active'] = active.toString();

    try {
      final List<Member> allMembers = [];
      int currentPage = 1;
      bool hasMore = true;

      while (hasMore) {
        queryParams['page'] = currentPage.toString();
        final uri = Uri.parse(
          '$baseUrl/members',
        ).replace(queryParameters: queryParams);
        _log('DEBUG: Fetching members page $currentPage from $uri');

        final response = await _client
            .get(uri, headers: headers)
            .timeout(timeout);
        _log('DEBUG: Members response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);

          // Handle both old (array) and new (paginated) response formats
          if (decoded is List) {
            _log('DEBUG: Parsed ${decoded.length} members (legacy format)');
            return decoded.map((json) => Member.fromJson(json)).toList();
          } else if (decoded is Map<String, dynamic>) {
            final data = decoded['data'] as List<dynamic>? ?? [];
            final pagination = decoded['pagination'] as Map<String, dynamic>?;

            allMembers.addAll(data.map((json) => Member.fromJson(json)));
            _log('DEBUG: Loaded page $currentPage with ${data.length} members');

            hasMore = pagination?['hasMore'] == true;
            currentPage++;
          }
        } else {
          _throwIfRateLimited(response);
          await _throwIfUnauthorized(response);
          _handleErrorResponse(response, 'Loading members');
          throw Exception('Failed to load members');
        }
      }

      _log('DEBUG: Total members loaded: ${allMembers.length}');
      return allMembers;
    } on SocketException catch (e) {
      _log('DEBUG: Socket error loading members: $e');
      throw Exception(
        'Cannot connect to server. Make sure backend is running at http://localhost:3000',
      );
    } on TimeoutException catch (e) {
      _log('DEBUG: Timeout loading members: $e');
      throw Exception('Request timeout. Server is not responding.');
    } catch (e) {
      _log('DEBUG: Error loading members: $e');
      rethrow;
    }
  }

  /// Paginated members fetch
  static Future<MembersResponse> getMembersPaginated({
    String? search,
    String? type,
    bool? active,
    int page = 1,
    int limit = 100,
  }) async {
    final headers = await getHeaders();
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (type != null && type.isNotEmpty) queryParams['type'] = type;
    if (active != null) queryParams['active'] = active.toString();

    final uri = Uri.parse(
      '$baseUrl/members',
    ).replace(queryParameters: queryParams);
    _log('DEBUG: Fetching members paginated from $uri');

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(timeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return MembersResponse.fromJson(decoded);
      } else {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Loading members');
        throw Exception('Failed to load members');
      }
    } on SocketException catch (e) {
      _log('DEBUG: Socket error: $e');
      throw Exception('Cannot connect to server.');
    } on TimeoutException {
      throw Exception('Request timeout.');
    }
  }

  static Future<Member> getMember(int id) async {
    try {
      final headers = await getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/members/$id'), headers: headers)
          .timeout(timeout);

      if (response.statusCode == 200) {
        return Member.fromJson(jsonDecode(response.body));
      } else {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Loading member');
        throw Exception('Failed to load member');
      }
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Request timed out.');
    }
  }

  static Future<Member> addMember(Member member) async {
    final headers = await getHeaders();
    _log('DEBUG: Adding member: ${member.name}');
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/members'),
            headers: headers,
            body: jsonEncode(member.toJson()),
          )
          .timeout(timeout);

      _log('DEBUG: Add member response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _log('DEBUG: Member added with id: ${data['id']}');
        _notifyDataChanged();
        return member.copyWith(id: data['id']);
      } else {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Adding member');
        throw Exception('Failed to add member');
      }
    } on SocketException catch (e) {
      _log('DEBUG: Socket error adding member: $e');
      throw Exception(
        'Cannot connect to server. Make sure backend is running at http://localhost:3000',
      );
    } on TimeoutException catch (e) {
      _log('DEBUG: Timeout adding member: $e');
      throw Exception('Request timeout. Server is not responding.');
    } catch (e) {
      _log('DEBUG: Error adding member: $e');
      rethrow;
    }
  }

  static Future<void> updateMember(int id, Member member) async {
    final headers = await getHeaders();
    _log('DEBUG: Updating member $id: ${member.name}');
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/members/$id'),
            headers: headers,
            body: jsonEncode(member.toJson()),
          )
          .timeout(timeout);

      _log('DEBUG: Update member response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Updating member');
      }

      _notifyDataChanged();
    } on SocketException catch (e) {
      _log('DEBUG: Socket error updating member: $e');
      throw Exception(
        'Cannot connect to server. Make sure backend is running at http://localhost:3000',
      );
    } on TimeoutException catch (e) {
      _log('DEBUG: Timeout updating member: $e');
      throw Exception('Request timeout. Server is not responding.');
    } catch (e) {
      _log('DEBUG: Error updating member: $e');
      rethrow;
    }
  }

  static Future<void> deleteMember(int id) async {
    final headers = await getHeaders();
    _log('DEBUG: Deleting member $id');
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/members/$id'), headers: headers)
          .timeout(timeout);

      _log('DEBUG: Delete member response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Deleting member');
      }

      _notifyDataChanged();
    } on SocketException catch (e) {
      _log('DEBUG: Socket error deleting member: $e');
      throw Exception(
        'Cannot connect to server. Make sure backend is running at http://localhost:3000',
      );
    } on TimeoutException catch (e) {
      _log('DEBUG: Timeout deleting member: $e');
      throw Exception('Request timeout. Server is not responding.');
    } catch (e) {
      _log('DEBUG: Error deleting member: $e');
      rethrow;
    }
  }

  static Future<List<Issue>> getMemberHistory(int memberId) async {
    // Use the shared Issues endpoint (supports filtering + consistent joins).
    // This avoids cases where the dedicated history endpoint returns an empty
    // list due to schema/restore differences.
    return getIssues(memberId: memberId);
  }

  static Future<List<MemberCategory>> getMemberCategories() async {
    final headers = await getHeaders();
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/member-categories'), headers: headers)
          .timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => MemberCategory.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load member categories');
      }
    } catch (e) {
      _log('DEBUG: Error loading member categories: $e');
      // Return defaults
      return [
        MemberCategory(id: 1, name: 'guest', maxBooks: 3, loanPeriodDays: 14),
        MemberCategory(
          id: 2,
          name: 'faculty',
          maxBooks: 10,
          loanPeriodDays: 30,
        ),
        MemberCategory(id: 3, name: 'staff', maxBooks: 5, loanPeriodDays: 21),
      ];
    }
  }

  // ==================== ISSUES ====================

  /// Get all issues (loads all pages for backward compatibility)
  static Future<List<Issue>> getIssues({
    int? memberId,
    int? bookId,
    String? status,
  }) async {
    final headers = await getHeaders();
    final queryParams = <String, String>{
      'limit': '1000', // Get more issues per page
    };
    if (memberId != null) queryParams['member_id'] = memberId.toString();
    if (bookId != null) queryParams['book_id'] = bookId.toString();
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    try {
      final List<Issue> allIssues = [];
      int currentPage = 1;
      bool hasMore = true;

      while (hasMore) {
        queryParams['page'] = currentPage.toString();
        final uri = Uri.parse(
          '$baseUrl/issues',
        ).replace(queryParameters: queryParams);
        _log('DEBUG: Fetching issues page $currentPage from $uri');

        final response = await _client
            .get(uri, headers: headers)
            .timeout(timeout);
        _log('DEBUG: Issues response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);

          // Handle both old (array) and new (paginated) response formats
          if (decoded is List) {
            _log('DEBUG: Parsed ${decoded.length} issues (legacy format)');
            return decoded.map((json) => Issue.fromJson(json)).toList();
          } else if (decoded is Map<String, dynamic>) {
            final data = decoded['data'] as List<dynamic>? ?? [];
            final pagination = decoded['pagination'] as Map<String, dynamic>?;

            allIssues.addAll(data.map((json) => Issue.fromJson(json)));
            _log('DEBUG: Loaded page $currentPage with ${data.length} issues');

            hasMore = pagination?['hasMore'] == true;
            currentPage++;
          }
        } else {
          _throwIfRateLimited(response);
          await _throwIfUnauthorized(response);
          _handleErrorResponse(response, 'Loading issues');
          throw Exception('Failed to load issues');
        }
      }

      _log('DEBUG: Total issues loaded: ${allIssues.length}');
      return allIssues;
    } on SocketException catch (e) {
      _log('DEBUG: Socket error loading issues: $e');
      throw Exception(
        'Cannot connect to server. Make sure backend is running at http://localhost:3000',
      );
    } on TimeoutException catch (e) {
      _log('DEBUG: Timeout loading issues: $e');
      throw Exception('Request timeout. Server is not responding.');
    } catch (e) {
      _log('DEBUG: Error loading issues: $e');
      rethrow;
    }
  }

  /// Paginated issues fetch
  static Future<IssuesResponse> getIssuesPaginated({
    int? memberId,
    int? bookId,
    String? status,
    int page = 1,
    int limit = 100,
  }) async {
    final headers = await getHeaders();
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (memberId != null) queryParams['member_id'] = memberId.toString();
    if (bookId != null) queryParams['book_id'] = bookId.toString();
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final uri = Uri.parse(
      '$baseUrl/issues',
    ).replace(queryParameters: queryParams);
    _log('DEBUG: Fetching issues paginated from $uri');

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(timeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return IssuesResponse.fromJson(decoded);
      } else {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Loading issues');
        throw Exception('Failed to load issues');
      }
    } on SocketException catch (e) {
      _log('DEBUG: Socket error: $e');
      throw Exception('Cannot connect to server.');
    } on TimeoutException {
      throw Exception('Request timeout.');
    }
  }

  static Future<void> issueBook(
    int bookId,
    int memberId,
    String dueDate,
  ) async {
    final headers = await getHeaders();
    _log('DEBUG: Issuing book $bookId to member $memberId until $dueDate');
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/issues'),
            headers: headers,
            body: jsonEncode({
              'book_id': bookId,
              'member_id': memberId,
              'due_date': dueDate,
            }),
          )
          .timeout(timeout);

      _log('DEBUG: Issue book response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Issuing book');
      }

      _notifyDataChanged();
    } on SocketException catch (e) {
      _log('DEBUG: Socket error issuing book: $e');
      throw Exception(
        'Cannot connect to server. Make sure backend is running at http://localhost:3000',
      );
    } on TimeoutException catch (e) {
      _log('DEBUG: Timeout issuing book: $e');
      throw Exception('Request timeout. Server is not responding.');
    } catch (e) {
      _log('DEBUG: Error issuing book: $e');
      rethrow;
    }
  }

  static Future<void> returnBook(int issueId) async {
    final headers = await getHeaders();
    _log('DEBUG: Returning book for issue $issueId');
    try {
      final response = await http
          .put(Uri.parse('$baseUrl/issues/$issueId/return'), headers: headers)
          .timeout(timeout);

      _log('DEBUG: Return book response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Returning book');
      }

      _notifyDataChanged();
    } on SocketException catch (e) {
      _log('DEBUG: Socket error returning book: $e');
      throw Exception(
        'Cannot connect to server. Make sure backend is running at http://localhost:3000',
      );
    } on TimeoutException catch (e) {
      _log('DEBUG: Timeout returning book: $e');
      throw Exception('Request timeout. Server is not responding.');
    } catch (e) {
      _log('DEBUG: Error returning book: $e');
      rethrow;
    }
  }

  static Future<void> updateIssue(
    int issueId, {
    String? dueDate,
    String? returnDate,
    String? status,
  }) async {
    final headers = await getHeaders();
    final body = <String, dynamic>{};

    if (dueDate != null) body['due_date'] = dueDate;
    if (returnDate != null) body['return_date'] = returnDate;
    if (status != null) body['status'] = status;

    _log('DEBUG: Updating issue $issueId with: $body');
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/issues/$issueId'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(timeout);

      _log('DEBUG: Update issue response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Updating issue');
      }

      _notifyDataChanged();
    } on SocketException catch (e) {
      _log('DEBUG: Socket error updating issue: $e');
      throw Exception(
        'Cannot connect to server. Make sure backend is running at http://localhost:3000',
      );
    } on TimeoutException catch (e) {
      _log('DEBUG: Timeout updating issue: $e');
      throw Exception('Request timeout. Server is not responding.');
    } catch (e) {
      _log('DEBUG: Error updating issue: $e');
      rethrow;
    }
  }

  // ==================== DASHBOARD ====================

  static Future<Map<String, int>> getDashboardStats() async {
    final headers = await getHeaders();
    final uri = Uri.parse('$baseUrl/dashboard/stats');
    _log('DEBUG: Fetching dashboard stats from $uri');

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(timeout);
      _log('DEBUG: Dashboard stats response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _log('DEBUG: Parsed dashboard stats: $data');
        return Map<String, int>.from(
          data.map(
            (k, v) =>
                MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0),
          ),
        );
      } else {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Loading dashboard stats');
        throw Exception('Failed to load dashboard stats');
      }
    } on SocketException catch (e) {
      _log('DEBUG: Socket error loading dashboard stats: $e');
      throw Exception(
        'Cannot connect to server. Make sure backend is running at http://localhost:3000',
      );
    } on TimeoutException catch (e) {
      _log('DEBUG: Timeout loading dashboard stats: $e');
      throw Exception('Request timeout. Server is not responding.');
    } catch (e) {
      _log('DEBUG: Error loading dashboard stats: $e');
      rethrow;
    }
  }

  static Future<List<DashboardWidget>> getDashboardSettings(int userId) async {
    final headers = await getHeaders();
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/dashboard/settings/$userId'),
            headers: headers,
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => DashboardWidget.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load dashboard settings');
      }
    } catch (e) {
      _log('DEBUG: Error loading dashboard settings: $e');
      // Return defaults
      return [
        DashboardWidget(name: 'stats_cards', isVisible: true, position: 0),
        DashboardWidget(name: 'charts', isVisible: true, position: 1),
        DashboardWidget(name: 'recent_issues', isVisible: true, position: 2),
        DashboardWidget(name: 'popular_books', isVisible: true, position: 3),
        DashboardWidget(name: 'overdue_alerts', isVisible: true, position: 4),
        DashboardWidget(name: 'quick_actions', isVisible: true, position: 5),
      ];
    }
  }

  static Future<void> saveDashboardSettings(
    int userId,
    List<DashboardWidget> widgets,
  ) async {
    final headers = await getHeaders();
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/dashboard/settings/$userId'),
            headers: headers,
            body: jsonEncode({
              'widgets': widgets.map((w) => w.toJson()).toList(),
            }),
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw Exception('Failed to save dashboard settings');
      }
    } catch (e) {
      _log('DEBUG: Error saving dashboard settings: $e');
      rethrow;
    }
  }

  // ==================== DASHBOARD (ALERTS & ACTIVITY) ====================

  static Future<Map<String, dynamic>> getDashboardAlerts({
    int limit = 10,
    int overdueDays = 7,
    int lowStockThreshold = 1,
    int inactiveDays = 60,
  }) async {
    final headers = await getHeaders();
    final uri = Uri.parse('$baseUrl/dashboard/alerts').replace(
      queryParameters: {
        'limit': limit.toString(),
        'overdue_days': overdueDays.toString(),
        'low_stock_threshold': lowStockThreshold.toString(),
        'inactive_days': inactiveDays.toString(),
      },
    );

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(timeout);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      _throwIfRateLimited(response);
      await _throwIfUnauthorized(response);
      _handleErrorResponse(response, 'Loading dashboard alerts');
      throw Exception('Failed to load dashboard alerts');
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Request timed out.');
    } catch (e) {
      _log('DEBUG: Error loading dashboard alerts: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getDashboardActivity({
    int limit = 25,
  }) async {
    final headers = await getHeaders();
    final uri = Uri.parse(
      '$baseUrl/dashboard/activity',
    ).replace(queryParameters: {'limit': limit.toString()});

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
      _throwIfRateLimited(response);
      await _throwIfUnauthorized(response);
      _handleErrorResponse(response, 'Loading dashboard activity');
      throw Exception('Failed to load dashboard activity');
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Request timed out.');
    } catch (e) {
      _log('DEBUG: Error loading dashboard activity: $e');
      rethrow;
    }
  }

  static Future<void> clearDashboardActivity() async {
    final headers = await getHeaders();
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/dashboard/activity/clear'),
            headers: headers,
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Clearing activity');
      }
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Request timed out.');
    } catch (e) {
      _log('DEBUG: Error clearing dashboard activity: $e');
      rethrow;
    }
  }

  static Future<void> remindIssue(int issueId) async {
    final headers = await getHeaders();
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/issues/$issueId/remind'), headers: headers)
          .timeout(timeout);
      if (response.statusCode != 200) {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Sending reminder');
      }
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Request timed out.');
    } catch (e) {
      _log('DEBUG: Error sending reminder: $e');
      rethrow;
    }
  }

  static Future<void> deactivateMember(int memberId) async {
    final headers = await getHeaders();
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/members/$memberId/deactivate'),
            headers: headers,
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Deactivating member');
      }

      _notifyDataChanged();
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Request timed out.');
    } catch (e) {
      _log('DEBUG: Error deactivating member: $e');
      rethrow;
    }
  }

  static Future<void> activateMember(int memberId) async {
    final headers = await getHeaders();
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/members/$memberId/activate'),
            headers: headers,
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Activating member');
      }

      _notifyDataChanged();
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Request timed out.');
    } catch (e) {
      _log('DEBUG: Error activating member: $e');
      rethrow;
    }
  }

  // ==================== REPORTS ====================

  static Future<List<Map<String, dynamic>>> getIssuedReport() async {
    final headers = await getHeaders();
    final uri = Uri.parse('$baseUrl/reports/issued');
    _log('DEBUG: Fetching issued report from $uri');

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _log('DEBUG: Parsed ${data.length} issued reports');
        return List<Map<String, dynamic>>.from(data);
      } else {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Loading issued report');
        throw Exception('Failed to load issued report');
      }
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Request timed out.');
    } catch (e) {
      _log('DEBUG: Error loading issued report: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getOverdueReport() async {
    final headers = await getHeaders();
    final uri = Uri.parse('$baseUrl/reports/overdue');
    _log('DEBUG: Fetching overdue report from $uri');

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _log('DEBUG: Parsed ${data.length} overdue reports');
        return List<Map<String, dynamic>>.from(data);
      } else {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Loading overdue report');
        throw Exception('Failed to load overdue report');
      }
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Request timed out.');
    } catch (e) {
      _log('DEBUG: Error loading overdue report: $e');
      rethrow;
    }
  }

  static Future<List<PopularBook>> getPopularBooks({
    int limit = 10,
    String? period,
  }) async {
    final headers = await getHeaders();
    final queryParams = <String, String>{'limit': limit.toString()};
    if (period != null) queryParams['period'] = period;

    final uri = Uri.parse(
      '$baseUrl/reports/popular-books',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => PopularBook.fromJson(json)).toList();
      } else {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Loading popular books');
        throw Exception('Failed to load popular books');
      }
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Request timed out.');
    } catch (e) {
      _log('DEBUG: Error loading popular books: $e');
      rethrow;
    }
  }

  static Future<List<ActiveMember>> getActiveMembers({
    int limit = 10,
    String? period,
  }) async {
    final headers = await getHeaders();
    final queryParams = <String, String>{'limit': limit.toString()};
    if (period != null) queryParams['period'] = period;

    final uri = Uri.parse(
      '$baseUrl/reports/active-members',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ActiveMember.fromJson(json)).toList();
      } else {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Loading active members');
        throw Exception('Failed to load active members');
      }
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Request timed out.');
    } catch (e) {
      _log('DEBUG: Error loading active members: $e');
      rethrow;
    }
  }

  static Future<List<MonthlyStats>> getMonthlyStats({int? year}) async {
    final headers = await getHeaders();
    final queryParams = <String, String>{};
    if (year != null) queryParams['year'] = year.toString();

    final uri = Uri.parse(
      '$baseUrl/reports/monthly-stats',
    ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => MonthlyStats.fromJson(json)).toList();
      } else {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Loading monthly stats');
        throw Exception('Failed to load monthly stats');
      }
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Request timed out.');
    } catch (e) {
      _log('DEBUG: Error loading monthly stats: $e');
      rethrow;
    }
  }

  static Future<List<CategoryStats>> getCategoryStats() async {
    final headers = await getHeaders();

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/reports/category-stats'), headers: headers)
          .timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => CategoryStats.fromJson(json)).toList();
      } else {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Loading category stats');
        throw Exception('Failed to load category stats');
      }
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Request timed out.');
    } catch (e) {
      _log('DEBUG: Error loading category stats: $e');
      rethrow;
    }
  }

  // ==================== NOTIFICATIONS ====================

  static Future<List<AppNotification>> getNotifications({
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    final headers = await getHeaders();
    final queryParams = <String, String>{'limit': limit.toString()};
    if (unreadOnly) queryParams['unread_only'] = 'true';

    final uri = Uri.parse(
      '$baseUrl/notifications',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(timeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => AppNotification.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      _log('DEBUG: Error loading notifications: $e');
      return [];
    }
  }

  static Future<int> getUnreadNotificationCount() async {
    final headers = await getHeaders();

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/notifications/count'), headers: headers)
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] ?? 0;
      } else {
        return 0;
      }
    } catch (e) {
      _log('DEBUG: Error loading notification count: $e');
      return 0;
    }
  }

  static Future<void> markNotificationAsRead(int id) async {
    final headers = await getHeaders();
    try {
      await http
          .put(Uri.parse('$baseUrl/notifications/$id/read'), headers: headers)
          .timeout(timeout);
    } catch (e) {
      _log('DEBUG: Error marking notification as read: $e');
    }
  }

  static Future<void> markAllNotificationsAsRead() async {
    final headers = await getHeaders();
    try {
      await http
          .put(Uri.parse('$baseUrl/notifications/read-all'), headers: headers)
          .timeout(timeout);
    } catch (e) {
      _log('DEBUG: Error marking all notifications as read: $e');
    }
  }

  static Future<void> deleteNotification(int id) async {
    final headers = await getHeaders();
    try {
      await http
          .delete(Uri.parse('$baseUrl/notifications/$id'), headers: headers)
          .timeout(timeout);
    } catch (e) {
      _log('DEBUG: Error deleting notification: $e');
    }
  }

  // ==================== SEARCH & RECOMMENDATIONS ====================

  static Future<Map<String, List<dynamic>>> advancedSearch({
    String? query,
    String? category,
    String? author,
    int? yearFrom,
    int? yearTo,
    String? status,
    String? memberType,
  }) async {
    final headers = await getHeaders();
    final queryParams = <String, String>{};
    if (query != null && query.isNotEmpty) queryParams['q'] = query;
    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }
    if (author != null && author.isNotEmpty) queryParams['author'] = author;
    if (yearFrom != null) queryParams['year_from'] = yearFrom.toString();
    if (yearTo != null) queryParams['year_to'] = yearTo.toString();
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (memberType != null && memberType.isNotEmpty) {
      queryParams['member_type'] = memberType;
    }

    final uri = Uri.parse(
      '$baseUrl/search',
    ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'books':
              (data['books'] as List?)
                  ?.map((json) => Book.fromJson(json))
                  .toList() ??
              [],
          'members':
              (data['members'] as List?)
                  ?.map((json) => Member.fromJson(json))
                  .toList() ??
              [],
          'issues':
              (data['issues'] as List?)
                  ?.map((json) => Issue.fromJson(json))
                  .toList() ??
              [],
        };
      } else {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Search');
        throw Exception('Search failed');
      }
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Request timed out.');
    } catch (e) {
      _log('DEBUG: Error in advanced search: $e');
      rethrow;
    }
  }

  static Future<List<Book>> getRecommendations(int memberId) async {
    final headers = await getHeaders();

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/recommendations/$memberId'),
            headers: headers,
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Book.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load recommendations');
      }
    } catch (e) {
      _log('DEBUG: Error loading recommendations: $e');
      return [];
    }
  }

  // ==================== BACKUP & RESTORE ====================

  static Future<Map<String, dynamic>> getBackup() async {
    final headers = await getHeaders();

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/backup'), headers: headers)
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Creating backup');
        throw Exception('Failed to create backup');
      }
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Backup request timed out.');
    } catch (e) {
      _log('DEBUG: Error creating backup: $e');
      rethrow;
    }
  }

  static Future<void> restoreBackup(
    Map<String, dynamic> data, {
    bool clearExisting = false,
  }) async {
    final headers = await getHeaders();

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/restore'),
            headers: headers,
            body: jsonEncode({
              'data': data['data'],
              'clear_existing': clearExisting,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Restoring backup');
      }
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Restore request timed out.');
    } catch (e) {
      _log('DEBUG: Error restoring backup: $e');
      rethrow;
    }
  }

  /// Export data (books, members, issues) as CSV or JSON
  /// Uses longer timeout for large datasets
  /// Returns raw bytes to handle BOM and encoding properly
  static Future<List<int>> exportData(
    String type, {
    String format = 'json',
  }) async {
    final headers = await getHeaders();

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/export/$type?format=$format'),
            headers: headers,
          )
          .timeout(longTimeout); // Use long timeout for large exports

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        _throwIfRateLimited(response);
        await _throwIfUnauthorized(response);
        _handleErrorResponse(response, 'Exporting data');
        throw Exception('Failed to export data');
      }
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Export request timed out.');
    } catch (e) {
      _log('DEBUG: Error exporting data: $e');
      rethrow;
    }
  }

  // ==================== FILE UPLOADS ====================

  static Future<String?> uploadBookCover(
    List<int> bytes,
    String filename,
  ) async {
    final token = await getToken();

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/uploads/book-cover'),
      );

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'cover',
          bytes,
          filename: filename,
          contentType: _guessImageMediaType(filename),
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final url = data['url'];
        return url;
      } else if (response.statusCode == 429) {
        throw Exception('Too many uploads. Please wait a moment.');
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await clearToken();
        _unauthorizedController.add(null);
        throw Exception('Session expired. Please login again.');
      } else {
        final errorMsg = _parseErrorMessage(response);
        throw Exception(errorMsg ?? 'Failed to upload cover image');
      }
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Upload timed out.');
    } catch (e) {
      _log('DEBUG: Error uploading book cover: $e');
      rethrow;
    }
  }

  static Future<String?> uploadMemberPhoto(
    List<int> bytes,
    String filename,
  ) async {
    final token = await getToken();

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/uploads/member-photo'),
      );

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          bytes,
          filename: filename,
          contentType: _guessImageMediaType(filename),
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final url = data['url'];
        return url;
      } else if (response.statusCode == 429) {
        throw Exception('Too many uploads. Please wait a moment.');
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await clearToken();
        _unauthorizedController.add(null);
        throw Exception('Session expired. Please login again.');
      } else {
        final errorMsg = _parseErrorMessage(response);
        throw Exception(errorMsg ?? 'Failed to upload member photo');
      }
    } on SocketException catch (_) {
      throw Exception('Cannot connect to server.');
    } on TimeoutException catch (_) {
      throw Exception('Upload timed out.');
    } catch (e) {
      _log('DEBUG: Error uploading member photo: $e');
      rethrow;
    }
  }
}
