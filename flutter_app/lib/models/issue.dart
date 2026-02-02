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
