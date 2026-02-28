import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/utils/date_formatter.dart';

void main() {
  group('DateFormatter', () {
    test('formatDateIndian formats ISO date correctly', () {
      expect(DateFormatter.formatDateIndian('2024-01-15'), '15/01/2024');
    });

    test('formatDateIndian returns empty string for null', () {
      expect(DateFormatter.formatDateIndian(null), '');
    });

    test('formatDateIndian returns empty string for empty string', () {
      expect(DateFormatter.formatDateIndian(''), '');
    });

    test('formatDateIndian returns original for unparseable string', () {
      expect(DateFormatter.formatDateIndian('not-a-date'), 'not-a-date');
    });

    test('formatDateTimeIndian includes time', () {
      final result = DateFormatter.formatDateTimeIndian('2024-06-15T14:30:00');
      // Should contain date in dd/MM/yyyy format
      expect(result, contains('/06/2024'));
    });

    test('formatDateTimeIndian returns empty for null', () {
      expect(DateFormatter.formatDateTimeIndian(null), '');
    });

    test('getCurrentDateIndian returns dd/MM/yyyy format', () {
      final result = DateFormatter.getCurrentDateIndian();
      expect(RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(result), true,
          reason: 'Expected dd/MM/yyyy, got: $result');
    });

    test('getCurrentDateTimeIndian includes AM/PM', () {
      final result = DateFormatter.getCurrentDateTimeIndian();
      expect(result.contains('AM') || result.contains('PM'), true,
          reason: 'Expected AM/PM in: $result');
    });
  });
}
