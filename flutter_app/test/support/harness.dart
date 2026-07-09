import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:library_management_app/utils/theme.dart';

/// Wraps [child] in a MaterialApp using the real app themes so widgets that
/// read `Theme.of(context)`, `context.semantic`, and the app design tokens
/// behave exactly as they do in production.
Widget wrapApp(
  Widget child, {
  Brightness brightness = Brightness.light,
  bool center = true,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(
      body: center ? Center(child: child) : child,
    ),
  );
}

/// Call once from `setUpAll` so Google Fonts never tries to hit the network
/// during tests (which would log noisy errors and slow the suite). The bundled
/// fallback font is used instead, which is fine for behavioural assertions.
void disableGoogleFontsFetching() {
  GoogleFonts.config.allowRuntimeFetching = false;
}
