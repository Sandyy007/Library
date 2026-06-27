import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:library_management_app/providers/member_provider.dart';
import 'package:library_management_app/models/member.dart';
import 'package:library_management_app/services/api_service.dart';

// MemberProvider load/pagination methods use ApiService._client (mockable).
// Mutating methods (addMember/deleteMember) use package-level http.* and are
// covered by the backend integration suite.

Map<String, dynamic> _member(int id, String name) => {
      'id': id,
      'name': name,
      'member_type': 'student',
      'membership_date': '2024-01-01',
      'is_active': true,
    };

String _page({
  required List<Map<String, dynamic>> data,
  required int page,
  required int total,
  required int totalPages,
  required bool hasMore,
}) {
  return jsonEncode({
    'data': data,
    'pagination': {
      'page': page,
      'limit': 100,
      'total': total,
      'totalPages': totalPages,
      'hasMore': hasMore,
    },
  });
}

void main() {
  group('MemberProvider', () {
    test('loadMembers populates members and pagination', () async {
      final mock = MockClient((request) async {
        return http.Response(
          _page(
            data: [_member(1, 'Asha'), _member(2, 'Ravi')],
            page: 1,
            total: 2,
            totalPages: 1,
            hasMore: false,
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = MemberProvider();
      await provider.loadMembers();

      expect(provider.members, hasLength(2));
      expect(provider.members.first.name, 'Asha');
      expect(provider.totalMembers, 2);
      expect(provider.hasMore, false);
      expect(provider.isLoading, false);
      expect(provider.error, isNull);
    });

    test('loadMembers records error and rethrows on failure', () async {
      final mock = MockClient((request) async => http.Response('nope', 500));
      ApiService.setHttpClientForTesting(mock);

      final provider = MemberProvider();
      await expectLater(provider.loadMembers(), throwsA(isA<Exception>()));
      expect(provider.error, isNotNull);
      expect(provider.isLoading, false);
    });

    test('loadPage replaces the current member list', () async {
      var call = 0;
      final mock = MockClient((request) async {
        call++;
        final id = call; // distinct member per call
        return http.Response(
          _page(
            data: [_member(id, 'Member $id')],
            page: call,
            total: 3,
            totalPages: 3,
            hasMore: true,
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = MemberProvider();
      await provider.loadMembers();
      expect(provider.members.single.id, 1);

      await provider.loadPage(2);
      expect(provider.members.single.id, 2);
      expect(provider.currentPage, 2);
    });

    test('removeMemberLocally then restoreMemberLocally round-trips (undo)',
        () async {
      final mock = MockClient((request) async {
        return http.Response(
          _page(
            data: [_member(1, 'Asha'), _member(2, 'Ravi'), _member(3, 'Meena')],
            page: 1,
            total: 3,
            totalPages: 1,
            hasMore: false,
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = MemberProvider();
      await provider.loadMembers();

      final removed = provider.removeMemberLocally(2);
      expect(removed, isNotNull);
      expect(removed!.index, 1);
      expect(provider.members.map((m) => m.id), [1, 3]);
      expect(provider.totalMembers, 2);

      provider.restoreMemberLocally(removed.member, removed.index);
      expect(provider.members.map((m) => m.id), [1, 2, 3]);
      expect(provider.totalMembers, 3);
    });

    test('addMember inserts the created member at the front (via _client)',
        () async {
      var call = 0;
      final mock = MockClient((request) async {
        call++;
        if (call == 1) {
          return http.Response(
            _page(
              data: [_member(1, 'Asha')],
              page: 1,
              total: 1,
              totalPages: 1,
              hasMore: false,
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        // POST /members create response
        return http.Response(jsonEncode({'id': 5}), 200,
            headers: {'content-type': 'application/json'});
      });
      ApiService.setHttpClientForTesting(mock);

      final provider = MemberProvider();
      await provider.loadMembers();
      await provider.addMember(Member(
        id: 0,
        name: 'New',
        memberType: 'student',
        membershipDate: '2024-01-01',
      ));

      expect(provider.members.first.name, 'New');
      expect(provider.totalMembers, 2);
    });
  });
}
