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

TextStyle hindiAwareTextStyle(
  BuildContext context, {
  required String text,
  required TextStyle base,
}) {
  final defaultSize = DefaultTextStyle.of(context).style.fontSize ?? 14;
  final effectiveSize = base.fontSize ?? defaultSize;

  // Unicode Hindi: help Windows pick a good Devanagari font.
  if (containsDevanagari(text)) {
    return base.copyWith(
      // Devanagari often looks optically smaller at the same point size.
      fontSize: (effectiveSize * 1.12).clamp(10, 30).toDouble(),
      fontFamilyFallback: const [
        'NotoSansDevanagari', // Bundled font
        'Nirmala UI', // Windows system font
        'Mangal', // Windows system font
        'Noto Sans Devanagari', // Android/Linux system font
      ],
    );
  }

  // Legacy (KrutiDev-style) Hindi: render correctly if the font is installed.
  if (looksLikeLegacyHindi(text)) {
    return base.copyWith(
      fontSize: (effectiveSize * 1.10).clamp(10, 30).toDouble(),
      fontFamily: 'KrutiDev', // Bundled font
      fontFamilyFallback: const [
        'KrutiDev', // Bundled font
        'Kruti Dev 010', // Alternate name / system font
        'Nirmala UI', // Windows fallback
        'Mangal', // Windows fallback
      ],
    );
  }

  // Default: still provide Devanagari fallback so mixed strings display.
  return base.copyWith(
    fontFamilyFallback: const [
      'NotoSansDevanagari', // Bundled font
      'Nirmala UI', // Windows system font
      'Mangal', // Windows system font
      'Noto Sans Devanagari', // Android/Linux system font
    ],
  );
}
