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

/// Unicode to KrutiDev mapping for reverse conversion (search support).
/// This is a simplified mapping for common Hindi characters.
const _unicodeToKrutiDev = <String, String>{
  'अ': 'v',
  'आ': 'vk',
  'इ': 'b',
  'ई': 'bZ',
  'उ': 'm',
  'ऊ': 'Å',
  'ऋ': '_',
  'ए': ',',
  'ऐ': ',S',
  'ओ': 'vks',
  'औ': 'vkS',
  'क': 'd',
  'ख': '[k',
  'ग': 'x',
  'घ': '?k',
  'ङ': 'M',
  'च': 'p',
  'छ': 'N',
  'ज': 't',
  'झ': '>',
  'ञ': '×',
  'ट': 'V',
  'ठ': 'B',
  'ड': 'M',
  'ढ': '<',
  'ण': '.k',
  'त': 'r',
  'थ': 'Fk',
  'द': 'n',
  'ध': '/k',
  'न': 'u',
  'प': 'i',
  'फ': 'Q',
  'ब': 'c',
  'भ': 'Hk',
  'म': 'e',
  'य': ';',
  'र': 'j',
  'ल': 'y',
  'व': 'o',
  'श': "'k",
  'ष': "\"k",
  'स': 'l',
  'ह': 'g',
  'क्ष': '{k',
  'त्र': '=',
  'ज्ञ': 'K',
  'ा': 'k',
  'ि': 'f',
  'ी': 'h',
  'ु': 'q',
  'ू': 'w',
  'ृ': '^',
  'े': 's',
  'ै': 'S',
  'ो': 'ks',
  'ौ': 'kS',
  '्': '',
  'ं': 'a',
  'ः': '%',
  'ँ': '¡',
  '।': 'A',
  '॥': 'AA',
  '०': '0',
  '१': '1',
  '२': '2',
  '३': '3',
  '४': '4',
  '५': '5',
  '६': '6',
  '७': '7',
  '८': '8',
  '९': '9',
  ' ': ' ',
  "'": "'",
  '"': '"',
};

/// Convert Unicode Hindi text to approximate KrutiDev encoding for search.
/// This is used to search for Hindi text in databases with legacy encoding.
String unicodeToKrutiDevApprox(String text) {
  if (!containsDevanagari(text)) return text;

  final buffer = StringBuffer();
  for (int i = 0; i < text.length; i++) {
    final char = text[i];
    // Check for two-character combinations first
    if (i + 1 < text.length) {
      final twoChar = text.substring(i, i + 2);
      if (_unicodeToKrutiDev.containsKey(twoChar)) {
        buffer.write(_unicodeToKrutiDev[twoChar]);
        i++; // Skip next character
        continue;
      }
    }
    // Single character lookup
    if (_unicodeToKrutiDev.containsKey(char)) {
      buffer.write(_unicodeToKrutiDev[char]);
    } else {
      buffer.write(char); // Keep as-is if not in mapping
    }
  }
  return buffer.toString();
}

/// Known English prefixes used in activity/notification titles.
/// These should NOT be converted even if followed by legacy Hindi.
final _knownPrefixes = [
  'Overdue:',
  'Issued:',
  'Returned:',
  'New Book Added:',
  'New Book:',
  'New member:',
  'Due Soon:',
  'borrowed',
  'returned',
  'has not returned',
  'which was due on',
  'by',
  'has been added to the library',
  'registered',
];

String normalizeLegacyHindiToUnicode(String text) {
  // If text already contains Devanagari, it's already Unicode Hindi - don't convert
  if (containsDevanagari(text)) return text;

  // Check if text starts with a known English prefix
  // If so, preserve the prefix and only convert the rest
  for (final prefix in _knownPrefixes) {
    if (text.startsWith(prefix)) {
      final rest = text.substring(prefix.length).trim();
      if (rest.isEmpty) return text;

      // Only convert the rest if it looks like legacy Hindi
      if (looksLikeLegacyHindi(rest)) {
        try {
          final converted = KrutidevToUnicode.convertToUnicode(rest);
          if (containsDevanagari(converted)) {
            return '$prefix $converted';
          }
        } catch (_) {
          // Fall through to return original
        }
      }
      return text;
    }
  }

  // For text with mixed content (e.g., "Name borrowed "BookTitle""),
  // try to find and convert only quoted portions that look like legacy Hindi
  final quotedPattern = RegExp(r'"([^"]+)"');
  String result = text;
  bool anyConverted = false;

  for (final match in quotedPattern.allMatches(text)) {
    final quoted = match.group(1)!;
    if (looksLikeLegacyHindi(quoted)) {
      try {
        final converted = KrutidevToUnicode.convertToUnicode(quoted);
        if (containsDevanagari(converted)) {
          result = result.replaceFirst('"$quoted"', '"$converted"');
          anyConverted = true;
        }
      } catch (_) {
        // Keep original
      }
    }
  }

  if (anyConverted) return result;

  // Full text conversion as fallback (original behavior)
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
