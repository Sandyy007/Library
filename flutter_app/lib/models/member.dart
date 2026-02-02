import '../utils/legacy_hindi.dart';

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
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    final addressRaw = json['address'];

    return Member(
      id: json['id'] ?? 0,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'member_type': memberType,
      'membership_date': membershipDate,
      'profile_photo': profilePhoto,
      'address': address,
      'expiry_date': expiryDate,
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
    );
  }

  // Get borrowing limit based on member type
  int get maxBooks {
    switch (memberType) {
      case 'faculty':
        return 10;
      case 'staff':
        return 5;
      case 'student':
      case 'guest':
      default:
        return 3;
    }
  }

  // Get loan period in days based on member type
  int get loanPeriodDays {
    switch (memberType) {
      case 'faculty':
        return 30;
      case 'staff':
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
      case 'faculty':
        return 'Faculty';
      case 'staff':
        return 'Staff';
      default:
        return memberType;
    }
  }
}
