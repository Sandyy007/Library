import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show PdfGoogleFonts;
import 'hindi_text.dart';

/// Centralized helper for PDF generation with proper Hindi font support.
/// Provides fonts and text normalization for all PDF exports.
class HindiPdfHelper {
  static pw.Font? _baseFont;
  static pw.Font? _boldFont;
  static bool _initialized = false;

  /// Initialize Hindi fonts for PDF. Must be called before any PDF generation.
  static Future<void> initialize() async {
    if (_initialized) return;
    _baseFont = await PdfGoogleFonts.notoSansDevanagariRegular();
    _boldFont = await PdfGoogleFonts.notoSansDevanagariBold();
    _initialized = true;
  }

  /// Get the base font for normal text
  static pw.Font get baseFont {
    if (_baseFont == null) {
      throw StateError('HindiPdfHelper not initialized. Call initialize() first.');
    }
    return _baseFont!;
  }

  /// Get the bold font for headers
  static pw.Font get boldFont {
    if (_boldFont == null) {
      throw StateError('HindiPdfHelper not initialized. Call initialize() first.');
    }
    return _boldFont!;
  }

  /// Get the PDF theme with Hindi fonts
  static pw.ThemeData get theme => pw.ThemeData.withFont(
    base: baseFont,
    bold: boldFont,
  );

  /// Normalize Hindi text for PDF display.
  /// Handles both legacy (KrutiDev) and Unicode Hindi.
  static String normalizeForPdf(String text) {
    return normalizeHindiForDisplay(text);
  }

  /// Create a pw.Text widget with Hindi support.
  static pw.Text text(
    String text, {
    pw.TextStyle? style,
    pw.TextAlign textAlign = pw.TextAlign.left,
  }) {
    return pw.Text(
      normalizeForPdf(text),
      style: style,
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
      ),
      textAlign: textAlign,
    );
  }

  /// Create a base text style for tables
  static pw.TextStyle get baseTextStyle => pw.TextStyle(font: baseFont, fontSize: 10);

  /// Create a bold text style for headers
  static pw.TextStyle get headerTextStyle => pw.TextStyle(font: boldFont, fontSize: 11, fontWeight: pw.FontWeight.bold);

  /// Create a cell text style
  static pw.TextStyle cellStyle({double fontSize = 9}) => pw.TextStyle(font: baseFont, fontSize: fontSize);

  /// Create a header cell style
  static pw.TextStyle headerCellStyle({double fontSize = 10}) => pw.TextStyle(font: boldFont, fontSize: fontSize, fontWeight: pw.FontWeight.bold);
}

/// Extension for easier text normalization in PDF generation
extension StringHindiPdfExtension on String {
  /// Normalize this string for PDF display
  String get forPdf => HindiPdfHelper.normalizeForPdf(this);
}