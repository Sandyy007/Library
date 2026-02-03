import 'package:flutter/material.dart';
import '../models/member.dart';
import '../services/api_service.dart';

class MemberProvider with ChangeNotifier {
  List<Member> _members = [];
  bool _isLoading = false;
  String? _error;

  List<Member> get members => _members;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMembers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    print('DEBUG [MemberProvider]: Starting loadMembers');

    try {
      _members = await ApiService.getMembers();
      print('DEBUG [MemberProvider]: Successfully loaded ${_members.length} members');
      print('DEBUG [MemberProvider]: Sample members: ${_members.take(2).toList()}');
      notifyListeners();
    } catch (e) {
      print('DEBUG [MemberProvider]: Error loading members: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addMember(Member member) async {
    try {
      final newMember = await ApiService.addMember(member);
      _members.add(newMember);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateMember(int id, Member updatedMember) async {
    try {
      await ApiService.updateMember(id, updatedMember);
      final index = _members.indexWhere((m) => m.id == id);
      if (index != -1) {
        _members[index] = updatedMember.copyWith(id: id);
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteMember(int id) async {
    try {
      await ApiService.deleteMember(id);
      _members.removeWhere((m) => m.id == id);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}
