import 'package:krutidevtounicode/krutidevtounicode.dart';

bool containsDevanagari(String text) {
  return RegExp(r'[\u0900-\u097F]').hasMatch(text);
}

bool looksLikeLegacyHindi(String text) {
  final s = text.trim();
  if (s.isEmpty) return false;
  if (containsDevanagari(s)) return false;

  // Heuristic for KrutiDev-style legacy Hindi: lots of ASCII letters + punctuation like ';' or '*'.
  final letters = RegExp(r'[A-Za-z]').allMatches(s).length;
  if (letters < 6) return false;
  final special = RegExp(r'[;*]').allMatches(s).length;
  if (special < 1) return false;
  final ratio = letters / s.length.clamp(1, 1 << 30);
  return ratio >= 0.55;
}

String normalizeLegacyHindiToUnicode(String text) {
  if (!looksLikeLegacyHindi(text)) return text;

  try {
    final converted = KrutidevToUnicode.convertToUnicode(text);
    // Only trust the conversion if it actually produced Devanagari.
    if (containsDevanagari(converted)) return converted;
  } catch (_) {
    // Ignore conversion failures and fall back to original.
  }

  return text;
}
