import 'package:flutter/material.dart';

import 'legacy_hindi.dart';
export 'legacy_hindi.dart'
    show containsDevanagari, looksLikeLegacyHindi, unicodeToKrutiDevApprox;

/// Known garbled prefixes that result from incorrectly converting English text
/// like "Overdue:", "Issued:", etc. using KrutiDev converter.
/// These patterns are very specific to avoid matching valid Hindi text.
final _garbledPrefixPatterns = [
  // Very specific pattern: "वृअमतकनमरू" followed by space (corrupted "Overdue:")
  RegExp(r'^वृअमतकनमरू\s+'),
  // Very specific pattern: "प्ॅनमकरू" (another corrupted prefix)
  RegExp(r'^प्ॅनमकरू\s+'),
  // Pattern for "ठवइ श्वीदेवद" (corrupted "Issued:")
  RegExp(r'^ठवइ\s+श्वीदेवद\s+'),
  // Pattern for corrupted "Returned:" - various KrutiDev conversions
  RegExp(r'^नदतहेस\s+'),
  RegExp(r'^टनदवत\s+'),
  // Pattern for corrupted "Issued:"
  RegExp(r'^इसतएद\s+'),
  RegExp(r'^इशउद\s+'),
  // Pattern for corrupted "New"
  RegExp(r'^नय\s+'),
  RegExp(r'^नई\s+'),
  // Pattern for corrupted "Due"
  RegExp(r'^डय\s+'),
  RegExp(r'^डयू\s+'),
  // Pattern for corrupted "Book"
  RegExp(r'^बक\s+'),
  RegExp(r'^बुक\s+'),
  // Pattern for corrupted "Member"
  RegExp(r'^मबर\s+'),
  RegExp(r'^मेमबर\s+'),
];

/// Additional garbled patterns that appear at various positions in text
final _garbledPatterns = [
  // Common corrupted phrases
  RegExp(r'वृअमतकनमरू'),
  RegExp(r'प्ॅनमकरू'),
  RegExp(r'ठवइ\s+श्वीदेवद'),
  RegExp(r'नदतहेस'),
  RegExp(r'टनदवत'),
  RegExp(r'इसतएद'),
  RegExp(r'श्वीदेवद'),
];

String _cleanGarbledText(String text) {
  String cleaned = text;

  // Remove very specific known garbled prefixes
  for (final pattern in _garbledPrefixPatterns) {
    cleaned = cleaned.replaceAll(pattern, '');
  }

  // Remove garbled patterns from anywhere in the text
  for (final pattern in _garbledPatterns) {
    cleaned = cleaned.replaceAll(pattern, '');
  }

  return cleaned.trim();
}

/// Strips leading unwanted symbols like quotes, asterisks from text.
/// These often appear at the start of Hindi book titles/author names in the database.
String _stripLeadingSymbols(String text) {
  // Only strip simple punctuation that shouldn't appear at the start of titles
  // Be very conservative to avoid stripping valid Hindi characters
  String result = text;

  // Strip leading whitespace first
  result = result.trimLeft();

  // Strip only leading quotes and asterisks - nothing else
  while (result.isNotEmpty) {
    final firstChar = result[0];
    if (firstChar == "'" ||
        firstChar == '"' ||
        firstChar == '*' ||
        firstChar == '`') {
      result = result.substring(1).trimLeft();
    } else {
      break;
    }
  }

  return result;
}

String normalizeHindiForDisplay(String text) {
  // First try standard legacy Hindi conversion
  String result = normalizeLegacyHindiToUnicode(text);

  // Then clean up any garbled prefixes from corrupted data
  result = _cleanGarbledText(result);

  // Strip leading unwanted symbols (quotes, etc.) from the result
  result = _stripLeadingSymbols(result);

  return result.trim();
}

/// Normalize Hindi text for PDF output.
///
/// PDF output should avoid aggressive cleanup that can remove valid words
/// from book titles. We still convert legacy Hindi to Unicode and strip
/// leading junk symbols, but we do not remove content using garbled patterns.
String normalizeHindiForPdf(String text) {
  // Convert legacy Hindi to Unicode if needed, but avoid aggressive
  // garbled-pattern cleanup for PDFs so book titles stay intact.
  String result = normalizeLegacyHindiToUnicode(text);

  // Strip only leading junk symbols; keep the rest as-is.
  result = _stripLeadingSymbols(result);

  return result.trim();
}

/// Returns a copy of [base] that renders Hindi/Devanagari glyphs correctly
/// **without** changing the size, weight, letter-spacing or line-height of the
/// surrounding UI. The only thing that changes for Hindi text is the font
/// fallback chain, so Hindi and English read at a consistent scale.
TextStyle hindiAwareTextStyle(
  BuildContext context, {
  required String text,
  required TextStyle base,
}) {
  const devanagariFallback = [
    'NotoSansDevanagari',
    'Nirmala UI',
    'Mangal',
    'Noto Sans Devanagari',
  ];

  if (containsDevanagari(text)) {
    return base.copyWith(fontFamilyFallback: devanagariFallback);
  }

  if (looksLikeLegacyHindi(text)) {
    return base.copyWith(
      fontFamily: 'KrutiDev',
      fontFamilyFallback: const [
        'KrutiDev',
        'Kruti Dev 010',
        ...devanagariFallback,
        'DevLys',
      ],
    );
  }

  return base.copyWith(fontFamilyFallback: devanagariFallback);
}
