import '../utils/legacy_hindi.dart';

class Book {
  final int id;
  final String isbn;
  final String title;
  final String author;
  final String? rackNumber;
  final String? category;
  final String? publisher;
  final int? yearPublished;
  final String status;
  final String addedDate;
  final String? coverImage;
  final int totalCopies;
  final int availableCopies;
  final String? description;

  Book({
    required this.id,
    required this.isbn,
    required this.title,
    required this.author,
    this.rackNumber,
    this.category,
    this.publisher,
    this.yearPublished,
    required this.status,
    required this.addedDate,
    this.coverImage,
    this.totalCopies = 1,
    this.availableCopies = 1,
    this.description,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    final publisherRaw = json['publisher'];
    final descriptionRaw = json['description'];

    return Book(
      id: json['id'] ?? 0,
      isbn: json['isbn'] ?? '',
      title: normalizeLegacyHindiToUnicode(json['title'] ?? ''),
      author: normalizeLegacyHindiToUnicode(json['author'] ?? ''),
      rackNumber: json['rack_number'] ?? json['rackNumber'],
      category: json['category'],
      publisher: publisherRaw == null
          ? null
          : normalizeLegacyHindiToUnicode(publisherRaw.toString()),
      yearPublished: json['year_published'],
      status: json['status'] ?? 'available',
      addedDate: json['added_date'] ?? '',
      coverImage: json['cover_image'],
      totalCopies: json['total_copies'] ?? 1,
      availableCopies:
          json['available_copies'] ?? (json['status'] == 'available' ? 1 : 0),
      description: descriptionRaw == null
          ? null
          : normalizeLegacyHindiToUnicode(descriptionRaw.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isbn': isbn,
      'title': title,
      'author': author,
      'rack_number': rackNumber,
      'category': category,
      'publisher': publisher,
      'year_published': yearPublished,
      'cover_image': coverImage,
      'total_copies': totalCopies,
      'description': description,
    };
  }

  Book copyWith({
    int? id,
    String? isbn,
    String? title,
    String? author,
    String? rackNumber,
    String? category,
    String? publisher,
    int? yearPublished,
    String? status,
    String? addedDate,
    String? coverImage,
    int? totalCopies,
    int? availableCopies,
    String? description,
  }) {
    return Book(
      id: id ?? this.id,
      isbn: isbn ?? this.isbn,
      title: title ?? this.title,
      author: author ?? this.author,
      rackNumber: rackNumber ?? this.rackNumber,
      category: category ?? this.category,
      publisher: publisher ?? this.publisher,
      yearPublished: yearPublished ?? this.yearPublished,
      status: status ?? this.status,
      addedDate: addedDate ?? this.addedDate,
      coverImage: coverImage ?? this.coverImage,
      totalCopies: totalCopies ?? this.totalCopies,
      availableCopies: availableCopies ?? this.availableCopies,
      description: description ?? this.description,
    );
  }
}
