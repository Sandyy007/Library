import '../utils/legacy_hindi.dart';

int _toInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

class Member {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String memberType;
  final String membershipDate;
  final String? profilePhoto;
  final String? address;
  final String? expiryDate;
  final bool isActive;
  final int borrowCount;

  Member({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.memberType,
    required this.membershipDate,
    this.profilePhoto,
    this.address,
    this.expiryDate,
    this.isActive = true,
    this.borrowCount = 0,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    final addressRaw = json['address'];

    return Member(
      id: _toInt(json['id']),
      name: normalizeLegacyHindiToUnicode(json['name'] ?? ''),
      email: json['email'],
      phone: json['phone'],
      memberType: json['member_type'] ?? 'student',
      membershipDate: json['membership_date'] ?? '',
      profilePhoto: json['profile_photo'],
      address: addressRaw == null
          ? null
          : normalizeLegacyHindiToUnicode(addressRaw.toString()),
      expiryDate: json['expiry_date'],
      isActive: json['is_active'] == true || json['is_active'] == 1,
      borrowCount: _toInt(json['borrow_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email?.isEmpty == true ? null : email,
      'phone': phone,
      'member_type': memberType,
      'membership_date': membershipDate,
      'profile_photo': profilePhoto,
      'address': address?.isEmpty == true ? null : address,
      'expiry_date': expiryDate?.isEmpty == true ? null : expiryDate,
      'is_active': isActive,
    };
  }

  Member copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? memberType,
    String? membershipDate,
    String? profilePhoto,
    String? address,
    String? expiryDate,
    bool? isActive,
    int? borrowCount,
  }) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      memberType: memberType ?? this.memberType,
      membershipDate: membershipDate ?? this.membershipDate,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      address: address ?? this.address,
      expiryDate: expiryDate ?? this.expiryDate,
      isActive: isActive ?? this.isActive,
      borrowCount: borrowCount ?? this.borrowCount,
    );
  }

  // Universal borrowing limit: 5 books per member
  int get maxBooks => 5;

  // Get loan period in days based on member type
  int get loanPeriodDays {
    switch (memberType) {
      case 'faculty':
        return 30;
      case 'staff':
      case 'additional_director':
      case 'joint_director':
      case 'deputy_director':
      case 'assistant_commissioner':
      case 'state_tax_officer':
      case 'assistant':
        return 21;
      case 'student':
      case 'guest':
      default:
        return 14;
    }
  }

  String get memberTypeLabel {
    switch (memberType.toLowerCase()) {
      case 'student':
      case 'guest':
        return 'Guest';
      case 'additional_director':
        return 'Additional Director';
      case 'joint_director':
        return 'Joint Director';
      case 'deputy_director':
        return 'Deputy Director';
      case 'assistant_commissioner':
        return 'Assistant Commissioner';
      case 'state_tax_officer':
        return 'State Tax Officer';
      case 'assistant':
        return 'Assistant';
      case 'faculty':
        return 'Faculty';
      case 'staff':
        return 'Staff';
      default:
        return memberType;
    }
  }
}

/// Pagination metadata for member list responses
class MembersPagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasMore;

  MembersPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.hasMore,
  });

  factory MembersPagination.fromJson(Map<String, dynamic> json) {
    return MembersPagination(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 100,
      total: json['total'] ?? 0,
      totalPages: json['totalPages'] ?? 1,
      hasMore: json['hasMore'] ?? false,
    );
  }
}

/// Paginated response for member list
class MembersResponse {
  final List<Member> data;
  final MembersPagination pagination;

  MembersResponse({
    required this.data,
    required this.pagination,
  });

  factory MembersResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List<dynamic>? ?? [];
    final paginationJson = json['pagination'];
    return MembersResponse(
      data: dataList.map((item) => Member.fromJson(item)).toList(),
      pagination: MembersPagination.fromJson(
        paginationJson is Map<String, dynamic>
            ? paginationJson
            : <String, dynamic>{},
      ),
    );
  }
}
