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

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: json['id'] ?? 0,
      bookId: json['book_id'] ?? 0,
      memberId: json['member_id'] ?? 0,
      issueDate: json['issue_date'] ?? '',
      dueDate: json['due_date'] ?? '',
      returnDate: json['return_date'],
      status: json['status'] ?? 'issued',
      bookTitle: json['title'] ?? '',
      bookAuthor: json['author'] ?? '',
      memberName: json['member_name'] ?? '',
      coverImage: json['cover_image'],
      memberPhoto: json['member_photo'],
      notes: json['notes'],
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
      final paginationJson = json['pagination'] as Map<String, dynamic>? ?? {};
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
