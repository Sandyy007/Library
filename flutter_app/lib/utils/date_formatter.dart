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

  static String formatDateIndian(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    final date = _parse(dateString);
    if (date == null) return dateString;
    return DateFormat('dd/MM/yyyy').format(date);
  }

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