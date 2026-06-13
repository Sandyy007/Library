class Issue {
  final int id;
  final int bookId;
  final int memberId;
  final String issueDate;
  final String dueDate;
  final String? returnDate;
  final String status;
  final String bookTitle;
  final String bookAuthor;
  final String memberName;
  final String? coverImage;
  final String? memberPhoto;
  final String? notes;

  Issue({
    required this.id,
    required this.bookId,
    required this.memberId,
    required this.issueDate,
    required this.dueDate,
    this.returnDate,
    required this.status,
    required this.bookTitle,
    required this.bookAuthor,
    required this.memberName,
    this.coverImage,
    this.memberPhoto,
    this.notes,
  });

  /// Strict integer parse: throws FormatException if the value is null, missing,
  /// or not coercible to a non-null int. Use this for fields that the API
  /// schema guarantees (primary/foreign keys, counts, identifiers) so a
  /// malformed response surfaces loudly instead of being silently coerced to 0.
  static int _reqInt(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) {
      throw FormatException('Issue.fromJson: missing required int field "$key"');
    }
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final parsed = int.tryParse(v);
      if (parsed != null) return parsed;
    }
    throw FormatException('Issue.fromJson: "$key" is not an int (got ${v.runtimeType})');
  }

  /// Strict non-null String parse. The API may legitimately return empty
  /// strings for some fields (e.g. member_name on LEFT JOIN with a deleted
  /// member), so we accept empty but never null/missing.
  static String _reqString(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) {
      throw FormatException('Issue.fromJson: missing required string field "$key"');
    }
    return v.toString();
  }

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: _reqInt(json, 'id'),
      bookId: _reqInt(json, 'book_id'),
      memberId: _reqInt(json, 'member_id'),
      issueDate: _reqString(json, 'issue_date'),
      dueDate: _reqString(json, 'due_date'),
      returnDate: json['return_date']?.toString(),
      status: _reqString(json, 'status'),
      bookTitle: _reqString(json, 'title'),
      bookAuthor: _reqString(json, 'author'),
      memberName: _reqString(json, 'member_name'),
      coverImage: json['cover_image']?.toString(),
      memberPhoto: json['member_photo']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  bool get isOverdue {
    if (status == 'returned') return false;
    final due = DateTime.tryParse(dueDate);
    if (due == null) return false;
    return DateTime.now().isAfter(due);
  }

  int get daysOverdue {
    if (!isOverdue) return 0;
    final due = DateTime.tryParse(dueDate);
    if (due == null) return 0;
    return DateTime.now().difference(due).inDays;
  }
}

/// Pagination information for Issues
class IssuesPagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasMore;

  IssuesPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasMore,
  });

  factory IssuesPagination.fromJson(Map<String, dynamic> json) {
    return IssuesPagination(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 100,
      total: json['total'] ?? 0,
      totalPages: json['totalPages'] ?? 1,
      hasMore: json['hasMore'] ?? false,
    );
  }

  factory IssuesPagination.empty() {
    return IssuesPagination(
      page: 1,
      limit: 100,
      total: 0,
      totalPages: 1,
      hasMore: false,
    );
  }
}

/// Paginated response for Issues
class IssuesResponse {
  final List<Issue> data;
  final IssuesPagination pagination;

  IssuesResponse({
    required this.data,
    required this.pagination,
  });

  factory IssuesResponse.fromJson(Map<String, dynamic> json) {
    // Handle both old (array) and new (paginated) response formats
    if (json.containsKey('data')) {
      final dataList = (json['data'] as List<dynamic>?) ?? [];
      final paginationRaw = json['pagination'];
      final paginationJson = paginationRaw is Map<String, dynamic>
          ? paginationRaw
          : <String, dynamic>{};
      return IssuesResponse(
        data: dataList.map((e) => Issue.fromJson(e)).toList(),
        pagination: IssuesPagination.fromJson(paginationJson),
      );
    } else {
      // Legacy array format - shouldn't happen but handle gracefully
      return IssuesResponse(
        data: [],
        pagination: IssuesPagination.empty(),
      );
    }
  }

  factory IssuesResponse.empty() {
    return IssuesResponse(
      data: [],
      pagination: IssuesPagination.empty(),
    );
  }
}
