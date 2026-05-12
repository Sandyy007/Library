import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'hindi_text.dart';

/// Centralized helper for PDF generation with proper Hindi font support.
/// Works offline with bundled fonts.
class HindiPdfHelper {
  static pw.Font? _baseFont;
  static pw.Font? _boldFont;
  static pw.Font? _latinFont;
  static pw.Font? _latinBoldFont;
  static bool _initialized = false;
  static bool _fontLoadFailed = false;

  /// Initialize Hindi fonts for PDF. Uses bundled fonts with fallbacks.
  /// Works offline in all Flutter platforms.
  static Future<void> initialize() async {
    if (_initialized) return;

    // Try loading bundled Noto Sans Devanagari fonts from assets
    if (!_fontLoadFailed) {
      try {
        final baseData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
        final boldData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf');
        _baseFont = pw.Font.ttf(baseData);
        _boldFont = pw.Font.ttf(boldData);
        if (kDebugMode) debugPrint('HindiPdfHelper: Hindi fonts loaded successfully');
      } catch (e) {
        _fontLoadFailed = true;
        if (kDebugMode) debugPrint('HindiPdfHelper: Bundled Hindi font loading failed: $e');
      }
    }

    // Fallback to Helvetica (always available in PDF package)
    if (_baseFont == null || _boldFont == null) {
      try {
        _baseFont = pw.Font.helvetica();
        _boldFont = pw.Font.helveticaBold();
        if (kDebugMode) debugPrint('HindiPdfHelper: Using Helvetica fonts');
      } catch (e) {
        // Last resort - use Times
        _baseFont = pw.Font.times();
        _boldFont = pw.Font.timesBold();
        if (kDebugMode) debugPrint('HindiPdfHelper: Using Times fonts');
      }
    }

    _initLatinFallback();
    _initialized = true;
  }

  static void _initLatinFallback() {
    if (_latinFont != null && _latinBoldFont != null) return;
    try {
      _latinFont = pw.Font.helvetica();
      _latinBoldFont = pw.Font.helveticaBold();
    } catch (e) {
      _latinFont = pw.Font.times();
      _latinBoldFont = pw.Font.timesBold();
    }
  }

  /// Get the base font for normal text
  static pw.Font get baseFont {
    return _baseFont ??= pw.Font.helvetica();
  }

  /// Get the bold font for headers
  static pw.Font get boldFont {
    return _boldFont ??= pw.Font.helveticaBold();
  }

  /// Get the PDF theme with Hindi fonts
  static pw.ThemeData get theme => pw.ThemeData.withFont(
    base: baseFont,
    bold: boldFont,
  );

  /// Font fallback list for Latin text and numerals
  static List<pw.Font> get baseFontFallback {
    final latin = _latinFont;
    if (latin == null) return const [];
    return [latin];
  }

  /// Font fallback list for bold Latin text and numerals
  static List<pw.Font> get boldFontFallback {
    final latin = _latinFont;
    final boldLatin = _latinBoldFont;
    if (boldLatin != null && latin != null) return [boldLatin, latin];
    if (boldLatin != null) return [boldLatin];
    if (latin != null) return [latin];
    return const [];
  }

  /// Normalize Hindi text for PDF display.
  /// Handles both legacy (KrutiDev) and Unicode Hindi.
  static String normalizeForPdf(String text) {
    return normalizeHindiForPdf(text);
  }

  /// Create a pw.Text widget with Hindi support.
  static pw.Text text(
    String text, {
    pw.TextStyle? style,
    pw.TextAlign textAlign = pw.TextAlign.left,
  }) {
    final effectiveStyle = style ?? baseStyle();
    return pw.Text(
      normalizeForPdf(text),
      style: effectiveStyle,
      textAlign: textAlign,
    );
  }

  /// Create a pw.Text widget with Hindi support and custom styling.
  static pw.Text styledText(
    String text, {
    double fontSize = 12,
    pw.FontWeight fontWeight = pw.FontWeight.normal,
    PdfColor? color,
    pw.TextAlign textAlign = pw.TextAlign.left,
  }) {
    final isBold = fontWeight == pw.FontWeight.bold;
    return pw.Text(
      normalizeForPdf(text),
      style: pw.TextStyle(
        font: isBold ? boldFont : baseFont,
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        fontFallback: isBold ? boldFontFallback : baseFontFallback,
      ),
      textAlign: textAlign,
    );
  }

  /// Create a base text style with fallback fonts
  static pw.TextStyle baseStyle({
    double fontSize = 12,
    pw.FontWeight fontWeight = pw.FontWeight.normal,
    PdfColor? color,
  }) {
    return pw.TextStyle(
      font: baseFont,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFallback: baseFontFallback,
    );
  }

  /// Create a bold text style with fallback fonts
  static pw.TextStyle boldStyle({
    double fontSize = 12,
    PdfColor? color,
  }) {
    return pw.TextStyle(
      font: boldFont,
      fontSize: fontSize,
      fontWeight: pw.FontWeight.bold,
      color: color,
      fontFallback: boldFontFallback,
    );
  }

  /// Create a base text style for tables
  static pw.TextStyle get baseTextStyle => pw.TextStyle(
    font: baseFont,
    fontSize: 10,
    fontFallback: baseFontFallback,
  );

  /// Create a bold text style for headers
  static pw.TextStyle get headerTextStyle => pw.TextStyle(
    font: boldFont,
    fontSize: 11,
    fontWeight: pw.FontWeight.bold,
    fontFallback: boldFontFallback,
  );

  /// Create a cell text style
  static pw.TextStyle cellStyle({double fontSize = 9}) => pw.TextStyle(
    font: baseFont,
    fontSize: fontSize,
    fontFallback: baseFontFallback,
  );

  /// Create a header cell style
  static pw.TextStyle headerCellStyle({double fontSize = 10}) => pw.TextStyle(
    font: boldFont,
    fontSize: fontSize,
    fontWeight: pw.FontWeight.bold,
    fontFallback: boldFontFallback,
  );
}

/// Extension for easier text normalization in PDF generation
extension StringHindiPdfExtension on String {
  /// Normalize this string for PDF display
  String get forPdf => HindiPdfHelper.normalizeForPdf(this);
}

/// Load organization logo from Flutter assets
Future<Uint8List?> loadPdfLogo() async {
  try {
    final logoData = await rootBundle.load('assets/images/Office_Logo.png');
    return logoData.buffer.asUint8List();
  } catch (e) {
    if (kDebugMode) debugPrint('Could not load logo: $e');
  }
  return null;
}

/// Get default Helvetica fonts for PDF (guaranteed to work offline)
({pw.Font baseFont, pw.Font boldFont}) getDefaultFonts() {
  return (
    baseFont: pw.Font.helvetica(),
    boldFont: pw.Font.helveticaBold(),
  );
}