import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/models/member.dart';

void main() {
  group('Member Model Tests', () {
    test('Member.fromJson parses all fields correctly', () {
      final member = Member.fromJson({
        'id': 1,
        'name': 'John Doe',
        'email': 'john@example.com',
        'phone': '1234567890',
        'member_type': 'student',
        'membership_date': '2024-01-15',
        'profile_photo': '/uploads/photo.jpg',
        'address': '123 Main St',
        'expiry_date': '2025-01-15',
        'is_active': true,
      });

      expect(member.id, 1);
      expect(member.name, 'John Doe');
      expect(member.email, 'john@example.com');
      expect(member.phone, '1234567890');
      expect(member.memberType, 'student');
      expect(member.membershipDate, '2024-01-15');
      expect(member.profilePhoto, '/uploads/photo.jpg');
      expect(member.address, '123 Main St');
      expect(member.expiryDate, '2025-01-15');
      expect(member.isActive, true);
    });

    test('Member.fromJson handles null optional fields', () {
      final member = Member.fromJson({
        'id': 2,
        'name': 'Jane Smith',
        'phone': '9876543210',
        'member_type': 'faculty',
        'membership_date': '2024-02-01',
      });

      expect(member.id, 2);
      expect(member.name, 'Jane Smith');
      expect(member.email, isNull);
      expect(member.profilePhoto, isNull);
      expect(member.address, isNull);
      expect(member.expiryDate, isNull);
      // Note: when is_active is null, it defaults to false per the fromJson logic
      expect(member.isActive, false);
    });

    test('Member.fromJson handles is_active as 0/1', () {
      final activeMember = Member.fromJson({
        'id': 1,
        'name': 'Active',
        'phone': '123',
        'member_type': 'staff',
        'membership_date': '2024-01-01',
        'is_active': 1,
      });
      expect(activeMember.isActive, true);

      final inactiveMember = Member.fromJson({
        'id': 2,
        'name': 'Inactive',
        'phone': '456',
        'member_type': 'guest',
        'membership_date': '2024-01-01',
        'is_active': 0,
      });
      expect(inactiveMember.isActive, false);
    });

    test('Member.toJson serializes correctly', () {
      final member = Member(
        id: 1,
        name: 'Test User',
        email: 'test@test.com',
        phone: '5555555555',
        memberType: 'faculty',
        membershipDate: '2024-03-01',
        profilePhoto: '/photo.jpg',
        address: '456 Oak Ave',
        expiryDate: '2025-03-01',
        isActive: true,
      );

      final json = member.toJson();
      expect(json['name'], 'Test User');
      expect(json['email'], 'test@test.com');
      expect(json['phone'], '5555555555');
      expect(json['member_type'], 'faculty');
      expect(json['membership_date'], '2024-03-01');
      expect(json['expiry_date'], '2025-03-01');
      expect(json['is_active'], true);
    });

    test('Member.toJson converts empty strings to null', () {
      final member = Member(
        id: 1,
        name: 'Test',
        email: '',
        phone: '123',
        memberType: 'student',
        membershipDate: '2024-01-01',
        address: '',
        expiryDate: '',
      );

      final json = member.toJson();
      expect(json['email'], isNull);
      expect(json['address'], isNull);
      expect(json['expiry_date'], isNull);
    });

    test('Member.copyWith creates correct copy', () {
      final original = Member(
        id: 1,
        name: 'Original',
        email: 'original@test.com',
        phone: '111',
        memberType: 'student',
        membershipDate: '2024-01-01',
      );

      final copy = original.copyWith(
        name: 'Updated',
        memberType: 'faculty',
      );

      expect(copy.id, 1);
      expect(copy.name, 'Updated');
      expect(copy.email, 'original@test.com');
      expect(copy.memberType, 'faculty');
    });
  });
}
