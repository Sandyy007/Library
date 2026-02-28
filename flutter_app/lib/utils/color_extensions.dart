import 'package:flutter/material.dart';

/// Theme-aware semantic color extensions.
/// Usage: Theme.of(context).colorScheme.success
extension AppSemanticColors on ColorScheme {
  Color get success =>
      brightness == Brightness.dark ? const Color(0xFF4ADE80) : Colors.green;
  Color get successContainer => brightness == Brightness.dark
      ? const Color(0xFF4ADE80).withValues(alpha: 0.15)
      : Colors.green.withValues(alpha: 0.08);

  Color get warning =>
      brightness == Brightness.dark ? const Color(0xFFFBBF24) : Colors.orange;
  Color get warningContainer => brightness == Brightness.dark
      ? const Color(0xFFFBBF24).withValues(alpha: 0.15)
      : Colors.orange.withValues(alpha: 0.08);

  Color get info =>
      brightness == Brightness.dark ? const Color(0xFF60A5FA) : Colors.blue;
  Color get infoContainer => brightness == Brightness.dark
      ? const Color(0xFF60A5FA).withValues(alpha: 0.15)
      : Colors.blue.withValues(alpha: 0.08);

  Color get danger =>
      brightness == Brightness.dark ? const Color(0xFFF87171) : Colors.red;
  Color get dangerContainer => brightness == Brightness.dark
      ? const Color(0xFFF87171).withValues(alpha: 0.15)
      : Colors.red.withValues(alpha: 0.08);

  Color get faculty =>
      brightness == Brightness.dark ? const Color(0xFFC084FC) : Colors.purple;
  Color get staff =>
      brightness == Brightness.dark ? const Color(0xFF2DD4BF) : Colors.teal;
  Color get guest =>
      brightness == Brightness.dark ? const Color(0xFFFBBF24) : Colors.orange;
  Color get student =>
      brightness == Brightness.dark ? const Color(0xFF60A5FA) : Colors.blue;

  /// Subtle row hover tint
  Color get hoverTint =>
      brightness == Brightness.dark
          ? const Color(0xFF2D3348)
          : primary.withValues(alpha: 0.04);

  /// Zebra-stripe alternate row background
  Color get zebraStripe =>
      brightness == Brightness.dark
          ? const Color(0xFF1E2235)
          : const Color(0xFFF8FAFC);

  /// Table header background
  Color get tableHeader =>
      brightness == Brightness.dark
          ? const Color(0xFF2D3348)
          : primary.withValues(alpha: 0.06);
}
