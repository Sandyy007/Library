import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF6366F1); // Modern indigo
  static const Color secondaryColor = Color(0xFFEC4899); // Pink accent
  static const Color backgroundColor =
      Color(0xFFF8FAFC); // Light gray background
  static const Color surfaceColor = Colors.white;
  static const Color errorColor = Color(0xFFEF4444);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    fontFamily: 'Roboto', // Modern font
    fontFamilyFallback: const [
      // Bundled fonts
      'KrutiDev',
      'NotoSansDevanagari',
      // Windows Devanagari fonts
      'Nirmala UI',
      'Mangal',
      'Kruti Dev 010',
      // Cross-platform common
      'Noto Sans Devanagari',
      'Segoe UI',
    ],
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: secondaryColor,
      surface: surfaceColor,
      error: errorColor,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 4,
        shadowColor: primaryColor.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      filled: true,
      fillColor: surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
          fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
      headlineMedium: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w600, color: Colors.black87),
      headlineSmall: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w600, color: Colors.black87),
      titleLarge: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
      titleMedium: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
      titleSmall: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
      bodyLarge: TextStyle(
          fontSize: 16, fontWeight: FontWeight.normal, color: Colors.black87),
      bodyMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.normal, color: Colors.black87),
      labelLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: surfaceColor,
      foregroundColor: Colors.black87,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    dataTableTheme: const DataTableThemeData(
      headingTextStyle: TextStyle(
        inherit: false,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      dataTextStyle: TextStyle(
        inherit: false,
        color: Colors.black87,
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: const Color(0xFF1A1D2E), // Lighter dark background
    fontFamily: 'Roboto', // Modern font
    fontFamilyFallback: const [
      // Bundled fonts
      'KrutiDev',
      'NotoSansDevanagari',
      // Windows Devanagari fonts
      'Nirmala UI',
      'Mangal',
      'Kruti Dev 010',
      // Cross-platform common
      'Noto Sans Devanagari',
      'Segoe UI',
    ],
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: const Color(0xFF818CF8), // Lighter indigo for dark mode
      secondary: const Color(0xFFF472B6), // Lighter pink for dark mode
      surface: const Color(0xFF252A3C), // Lighter surface
      onSurface: const Color(0xFFE2E8F0), // Light text on surface
      surfaceContainerHighest: const Color(0xFF2D3348), // Card backgrounds
      outline: const Color(0xFF3F4562), // Subtle borders
      error: const Color(0xFFF87171), // Lighter error color
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF252A3C),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 4,
        backgroundColor: const Color(0xFF818CF8),
        foregroundColor: Colors.white,
        shadowColor: const Color(0xFF818CF8).withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF818CF8),
        side: const BorderSide(color: Color(0xFF818CF8), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3F4562)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3F4562)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF818CF8), width: 2),
      ),
      filled: true,
      fillColor: const Color(0xFF252A3C),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      labelStyle: const TextStyle(color: Color(0xFFCBD5E1)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF3F4562),
      thickness: 1,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFFCBD5E1),
      textColor: Color(0xFFE2E8F0),
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFFCBD5E1),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
          fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFF1F5F9)),
      headlineMedium: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w600, color: Color(0xFFF1F5F9)),
      headlineSmall: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFFF1F5F9)),
      titleLarge: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFFF1F5F9)),
      titleMedium: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w500, color: Color(0xFFE2E8F0)),
      titleSmall: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFFE2E8F0)),
      bodyLarge: TextStyle(
          fontSize: 16, fontWeight: FontWeight.normal, color: Color(0xFFCBD5E1)),
      bodyMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.normal, color: Color(0xFFCBD5E1)),
      bodySmall: TextStyle(
          fontSize: 12, fontWeight: FontWeight.normal, color: Color(0xFF94A3B8)),
      labelLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFE2E8F0)),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Color(0xFF1A1D2E),
      foregroundColor: Color(0xFFF1F5F9),
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Color(0xFF818CF8),
      unselectedLabelColor: Color(0xFF94A3B8),
      indicatorColor: Color(0xFF818CF8),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF252A3C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Color(0xFFF1F5F9),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF2D3348),
      contentTextStyle: const TextStyle(color: Color(0xFFE2E8F0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    dataTableTheme: DataTableThemeData(
      headingTextStyle: const TextStyle(
        inherit: false,
        fontWeight: FontWeight.w600,
        color: Color(0xFFF1F5F9),
      ),
      dataTextStyle: const TextStyle(
        inherit: false,
        color: Color(0xFFCBD5E1),
      ),
      headingRowColor: WidgetStateProperty.all(const Color(0xFF2D3348)),
      dataRowColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFF2D3348);
        }
        return const Color(0xFF252A3C);
      }),
      dividerThickness: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF2D3348),
      labelStyle: const TextStyle(color: Color(0xFFE2E8F0)),
      side: const BorderSide(color: Color(0xFF3F4562)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF818CF8);
        }
        return const Color(0xFF94A3B8);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF818CF8).withValues(alpha: 0.4);
        }
        return const Color(0xFF3F4562);
      }),
    ),
  );
}
