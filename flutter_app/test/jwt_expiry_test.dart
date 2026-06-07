import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/services/api_service.dart';

void main() {
  // Build a valid JWT in-memory. Header: {"alg":"HS256","typ":"JWT"}.
  // Payload: {"sub":"admin","iat":1700000000,"exp":1700007200}.
  // The signature is bogus - we only need the payload to be decodable.
  String buildToken(int expEpochSeconds) {
    String b64(Map<String, dynamic> m) => base64UrlEncode(utf8.encode(jsonEncode(m)));
    final header = b64({'alg': 'HS256', 'typ': 'JWT'});
    final payload = b64({'sub': 'admin', 'iat': 1700000000, 'exp': expEpochSeconds});
    return '$header.$payload.sig';
  }

  group('ApiService.getTokenExpiry', () {
    test('returns null for malformed token', () {
      expect(ApiService.getTokenExpiry('not.a.token'), isNull);
      expect(ApiService.getTokenExpiry('garbage'), isNull);
    });

    test('returns null for token with two parts', () {
      expect(ApiService.getTokenExpiry('a.b'), isNull);
    });

    test('returns null when exp is not numeric', () {
      final bad = '${base64UrlEncode(utf8.encode('{"alg":"HS256"}'))}'
          '.${base64UrlEncode(utf8.encode('{"exp":"not-a-number"}'))}'
          '.sig';
      expect(ApiService.getTokenExpiry(bad), isNull);
    });

    test('parses exp as int', () {
      final expSeconds = (DateTime.now().millisecondsSinceEpoch / 1000).floor() + 600;
      final token = buildToken(expSeconds);
      final result = ApiService.getTokenExpiry(token);
      expect(result, isNotNull);
      expect(result!.millisecondsSinceEpoch, expSeconds * 1000);
    });

    test('parses exp as double (decimal seconds)', () {
      final expSeconds = 1700007200.5;
      final token = buildToken(expSeconds.toInt());
      final result = ApiService.getTokenExpiry(token);
      expect(result, isNotNull);
    });
  });
}
