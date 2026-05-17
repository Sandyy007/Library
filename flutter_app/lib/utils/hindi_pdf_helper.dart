import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' as painting;
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
  static bool _usingFallbackFonts = false;
  static final Map<String, HindiRasterText> _rasterCache = {};
  static const double _minRasterScale = 3.0; // Higher scale for sharper Hindi text
  static final Uint8List _transparentPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
  );

  /// Initialize Hindi fonts for PDF. Uses bundled fonts with fallbacks.
  /// Works offline in all Flutter platforms.
  static Future<void> initialize({bool forceReload = false}) async {
    if (_initialized && !_usingFallbackFonts && !forceReload) return;

    bool loadedHindiFonts = false;

    // Try loading bundled Noto Sans Devanagari fonts from assets
    try {
      final baseData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf');
      _baseFont = pw.Font.ttf(baseData);
      _boldFont = pw.Font.ttf(boldData);
      loadedHindiFonts = true;
      if (kDebugMode) debugPrint('HindiPdfHelper: Hindi fonts loaded successfully');
    } catch (e) {
      if (kDebugMode) debugPrint('HindiPdfHelper: Bundled Hindi font loading failed: $e');
    }

    // Fallback to Helvetica (always available in PDF package)
    if (!loadedHindiFonts) {
      _usingFallbackFonts = true;
      try {
        _baseFont ??= pw.Font.helvetica();
        _boldFont ??= pw.Font.helveticaBold();
        if (kDebugMode) debugPrint('HindiPdfHelper: Using Helvetica fonts');
      } catch (e) {
        // Last resort - use Times
        _baseFont ??= pw.Font.times();
        _boldFont ??= pw.Font.timesBold();
        if (kDebugMode) debugPrint('HindiPdfHelper: Using Times fonts');
      }
    } else {
      _usingFallbackFonts = false;
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

  /// Whether the helper had to fall back to non-Hindi fonts.
  static bool get usingFallbackFonts => _usingFallbackFonts;

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

  static String _rasterKey(
    String text,
    double fontSize,
    pw.FontWeight fontWeight,
    PdfColor? color,
  ) {
    final c = color ?? PdfColors.black;
    final weight = fontWeight == pw.FontWeight.bold ? 'bold' : 'normal';
    final rgb = '${(c.red * 255).round()}-${(c.green * 255).round()}-${(c.blue * 255).round()}';
    return '$weight|${fontSize.toStringAsFixed(2)}|$rgb|$text';
  }

  static double _devicePixelRatio() {
    final views = ui.PlatformDispatcher.instance.views;
    if (views.isEmpty) return 1.0;
    return views.first.devicePixelRatio;
  }

  static ui.Color _toFlutterColor(PdfColor? color) {
    final c = color ?? PdfColors.black;
    return ui.Color.fromARGB(
      255,
      (c.red * 255).round(),
      (c.green * 255).round(),
      (c.blue * 255).round(),
    );
  }

  static painting.FontWeight _toFlutterFontWeight(pw.FontWeight weight) {
    return weight == pw.FontWeight.bold
      ? painting.FontWeight.w800  // Bolder for sharper PDF rendering
      : painting.FontWeight.w600;
  }

  static Future<HindiRasterText> _rasterizeHindiText(
    String text, {
    required double fontSize,
    required pw.FontWeight fontWeight,
    PdfColor? color,
  }) async {
    final key = _rasterKey(text, fontSize, fontWeight, color);
    final cached = _rasterCache[key];
    if (cached != null) return cached;

    final dpr = _devicePixelRatio();
    final scale = math.max(dpr, _minRasterScale);
    final painter = painting.TextPainter(
      text: painting.TextSpan(
        text: text,
        style: painting.TextStyle(
          fontFamily: 'NotoSansDevanagari',
          fontSize: fontSize,
          fontWeight: _toFlutterFontWeight(fontWeight),
          color: _toFlutterColor(color),
        ),
      ),
      textDirection: painting.TextDirection.ltr,
    );

    painter.layout();
    final width = painter.width <= 0 ? 1.0 : painter.width;
    final height = painter.height <= 0 ? 1.0 : painter.height;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(scale, scale);
    painter.paint(canvas, ui.Offset.zero);
    final picture = recorder.endRecording();

    final image = await picture.toImage(
      (width * scale).ceil().clamp(1, 4096),
      (height * scale).ceil().clamp(1, 4096),
    );

    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      final fallback = HindiRasterText(
        image: pw.MemoryImage(_transparentPng),
        width: width,
        height: height,
      );
      _rasterCache[key] = fallback;
      return fallback;
    }

    final raster = HindiRasterText(
      image: pw.MemoryImage(bytes.buffer.asUint8List()),
      width: width,
      height: height,
    );
    _rasterCache[key] = raster;
    return raster;
  }

  /// Pre-render Hindi text into images for reliable PDF output.
  static Future<Map<String, HindiRasterText>> preRenderHindiTexts(
    Iterable<String> texts, {
    double fontSize = 10,
    pw.FontWeight fontWeight = pw.FontWeight.normal,
    PdfColor? color,
  }) async {
    final unique = <String>{};
    for (final text in texts) {
      final normalized = normalizeForPdf(text);
      if (normalized.isEmpty) continue;
      if (!containsDevanagari(normalized)) continue;
      unique.add(normalized);
    }

    final results = <String, HindiRasterText>{};
    for (final text in unique) {
      results[text] = await _rasterizeHindiText(
        text,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    }
    return results;
  }

  /// Adjust text style to avoid clipping Hindi diacritics in PDFs.
  static pw.TextStyle applyHindiMetrics(String text, pw.TextStyle style) {
    if (!containsDevanagari(text)) return style;

    final baseHeight = style.height ?? 1.0;
    final height = baseHeight < 1.15 ? 1.15 : baseHeight;
    return style.copyWith(height: height);
  }

  /// Create a pw.Text widget with Hindi support.
  static pw.Text text(
    String text, {
    pw.TextStyle? style,
    pw.TextAlign textAlign = pw.TextAlign.left,
  }) {
    final normalized = normalizeForPdf(text);
    final effectiveStyle = applyHindiMetrics(normalized, style ?? baseStyle());
    return pw.Text(
      normalized,
      style: effectiveStyle,
      textAlign: textAlign,
    );
  }

  /// Build a PDF widget using a pre-rendered Hindi cache if available.
  /// Uses higher contrast color for sharper appearance.
  static pw.Widget buildCachedText(
    String text, {
    required pw.TextStyle style,
    Map<String, HindiRasterText>? cache,
    pw.TextAlign textAlign = pw.TextAlign.left,
  }) {
    final normalized = normalizeForPdf(text);

    // Use cached rasterized image if available
    if (cache != null && cache.containsKey(normalized)) {
      final raster = cache[normalized]!;
      return pw.Image(
        raster.image,
        width: raster.width,
        height: raster.height,
      );
    }

    // Fallback to direct text rendering with high contrast
    final effectiveStyle = applyHindiMetrics(
      normalized,
      style.copyWith(
        color: _ensureHighContrastColor(style.color),
      ),
    );
    return pw.Text(
      normalized,
      style: effectiveStyle,
      textAlign: textAlign,
    );
  }

  /// Ensure color has high contrast for better visibility
  static PdfColor? _ensureHighContrastColor(PdfColor? color) {
    if (color == null) return PdfColors.grey900;
    // If color is very light, use darker version
    if (color.red > 0.7 && color.green > 0.7 && color.blue > 0.7) {
      return PdfColors.grey900;
    }
    return color;
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
    final normalized = normalizeForPdf(text);
    final baseStyle = pw.TextStyle(
      font: isBold ? boldFont : baseFont,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      fontFallback: isBold ? boldFontFallback : baseFontFallback,
    );
    final effectiveStyle = applyHindiMetrics(normalized, baseStyle);
    return pw.Text(
      normalized,
      style: effectiveStyle,
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

class HindiRasterText {
  const HindiRasterText({
    required this.image,
    required this.width,
    required this.height,
  });

  final pw.MemoryImage image;
  final double width;
  final double height;
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