import 'package:flutter/material.dart';

import 'legacy_hindi.dart';

String normalizeHindiForDisplay(String text) {
  return normalizeLegacyHindiToUnicode(text);
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
        'Nirmala UI',
        'Mangal',
        'Noto Sans Devanagari',
      ],
    );
  }

  // Legacy (KrutiDev-style) Hindi: render correctly if the font is installed.
  if (looksLikeLegacyHindi(text)) {
    return base.copyWith(
      fontSize: (effectiveSize * 1.10).clamp(10, 30).toDouble(),
      fontFamily: 'Kruti Dev 010',
      fontFamilyFallback: const ['Kruti Dev 010', 'Nirmala UI', 'Mangal'],
    );
  }

  // Default: still provide Devanagari fallback so mixed strings display.
  return base.copyWith(
    fontFamilyFallback: const [
      'Nirmala UI',
      'Mangal',
      'Noto Sans Devanagari',
    ],
  );
}
