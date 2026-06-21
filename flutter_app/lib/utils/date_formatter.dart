import 'package:intl/intl.dart';

class DateFormatter {
  static DateTime? _parse(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      final parsed = DateTime.tryParse(dateString);
      return parsed?.toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Matches a leading calendar date (YYYY-MM-DD) in any ISO-ish string.
  static final RegExp _datePrefix = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');

  /// Formats a stored calendar date as dd/MM/yyyy.
  ///
  /// Date-only columns (e.g. due_date, membership_date) are serialised by the
  /// backend as UTC midnight (e.g. `2024-02-01T00:00:00.000Z`). Converting
  /// those to local time can roll the day backwards in timezones behind UTC,
  /// so we read the calendar date directly from the string instead of doing a
  /// timezone conversion.
  static String formatDateIndian(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    final match = _datePrefix.firstMatch(dateString.trim());
    if (match != null) {
      return '${match.group(3)}/${match.group(2)}/${match.group(1)}';
    }
    final date = _parse(dateString);
    if (date == null) return dateString;
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Formats an actual timestamp (e.g. activity time) in local time.
  static String formatDateTimeIndian(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    final date = _parse(dateString);
    if (date == null) return dateString;
    return DateFormat('dd/MM/yyyy hh:mm a').format(date);
  }

  static String getCurrentDateIndian() {
    final now = DateTime.now();
    final formatter = DateFormat('dd/MM/yyyy');
    return formatter.format(now);
  }

  static String getCurrentDateTimeIndian() {
    final now = DateTime.now();
    final formatter = DateFormat('dd/MM/yyyy hh:mm a');
    return formatter.format(now);
  }
}