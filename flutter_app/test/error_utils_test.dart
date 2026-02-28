import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/utils/error_utils.dart';

void main() {
  group('cleanErrorMessage', () {
    test('returns fallback for null', () {
      expect(cleanErrorMessage(null), 'An error occurred');
    });

    test('strips Exception: prefix', () {
      expect(cleanErrorMessage(Exception('Something broke')),
          'Something broke');
    });

    test('strips FormatException: prefix', () {
      expect(
        cleanErrorMessage('FormatException: Bad JSON'),
        'Bad JSON',
      );
    });

    test('truncates long messages', () {
      final long = 'A' * 200;
      final result = cleanErrorMessage(long);
      expect(result.length, lessThanOrEqualTo(83)); // 80 + '...'
    });

    test('returns fallback for empty string', () {
      expect(cleanErrorMessage(''), 'An error occurred');
    });

    test('uses custom fallback', () {
      expect(
        cleanErrorMessage(null, fallback: 'Custom error'),
        'Custom error',
      );
    });
  });

  group('getOperationErrorMessage', () {
    test('identifies connection errors', () {
      expect(
        getOperationErrorMessage('Load', 'SocketException: connect refused'),
        'Cannot connect to server',
      );
    });

    test('identifies timeout errors', () {
      expect(
        getOperationErrorMessage('Load', 'TimeoutException after 0:00:30'),
        'Connection timed out',
      );
    });

    test('identifies 404 errors', () {
      expect(
        getOperationErrorMessage('Delete', 'not found'),
        'Delete: Item not found',
      );
    });

    test('identifies 401 errors', () {
      expect(
        getOperationErrorMessage('Load', '401 unauthorized'),
        'Please log in again',
      );
    });

    test('identifies 403 errors', () {
      expect(
        getOperationErrorMessage('Update', '403 forbidden'),
        'Access denied',
      );
    });

    test('returns operation failed for long messages', () {
      final long = 'Some very long error message that exceeds the fifty character limit we have set';
      expect(
        getOperationErrorMessage('Save', long),
        'Save failed',
      );
    });

    test('returns short error messages as-is', () {
      expect(
        getOperationErrorMessage('Load', 'Bad data format'),
        'Bad data format',
      );
    });
  });
}
