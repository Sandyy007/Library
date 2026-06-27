import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double pagePadding = 20;
}

class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;
}

class AppDurations {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
}

class AppPalette {
  static const Color primaryLight = Color(0xFF0059D6);
  static const Color secondaryLight = Color(0xFF0A6A5E);
  static const Color tertiaryLight = Color(0xFF8D4E00);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF5F8FC);
  static const Color errorLight = Color(0xFFB3261E);

  // Premium Dark Mode Palette — warm slate with refined accents
  static const Color primaryDark = Color(0xFF7C9BFF);
  static const Color secondaryDark = Color(0xFF34D399);
  static const Color tertiaryDark = Color(0xFFFBBF24);
  static const Color surfaceDark = Color(0xFF171923);
  static const Color backgroundDark = Color(0xFF0A0C12);
  static const Color cardDark = Color(0xFF1E202B);
  static const Color elevatedDark = Color(0xFF262836);
  static const Color borderDark = Color(0xFF2D2F3D);
  static const Color errorDark = Color(0xFFFC8181);
}

/// Semantic status colors used across the app (success / warning / danger /
/// info) plus their low-alpha container tints. These were previously
/// hardcoded as raw `Color(0xFF...)` literals scattered through the widget
/// files, which meant they couldn't adapt to light/dark and had no single
/// source of truth. Access via `Theme.of(context).extension<AppSemanticColors>()!`
/// or the `context.semantic` getter below.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.danger,
    required this.dangerContainer,
    required this.info,
    required this.infoContainer,
  });

  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color danger;
  final Color dangerContainer;
  final Color info;
  final Color infoContainer;

  static const AppSemanticColors light = AppSemanticColors(
    success: Color(0xFF0F9D58),
    successContainer: Color(0xFFE3F6EC),
    warning: Color(0xFFB7791F),
    warningContainer: Color(0xFFFBF0D9),
    danger: Color(0xFFD92D20),
    dangerContainer: Color(0xFFFCE8E6),
    info: Color(0xFF2563EB),
    infoContainer: Color(0xFFE4ECFD),
  );

  static const AppSemanticColors dark = AppSemanticColors(
    success: Color(0xFF34D399),
    successContainer: Color(0xFF12372C),
    warning: Color(0xFFFBBF24),
    warningContainer: Color(0xFF3A300F),
    danger: Color(0xFFFC8181),
    dangerContainer: Color(0xFF3A1D1D),
    info: Color(0xFF7C9BFF),
    infoContainer: Color(0xFF1B2540),
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? danger,
    Color? dangerContainer,
    Color? info,
    Color? infoContainer,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
    );
  }
}

/// Ergonomic access to [AppSemanticColors] from any BuildContext.
extension AppSemanticColorsX on BuildContext {
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;
}

class AppTypography {
  static TextTheme buildTextTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primaryText = isDark ? const Color(0xFFEDEEF4) : const Color(0xFF122033);
    final secondaryText = isDark ? const Color(0xFF9B9DAB) : const Color(0xFF445A78);

    final base = GoogleFonts.plusJakartaSansTextTheme();

    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: primaryText,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: primaryText,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primaryText,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: primaryText,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.35,
        color: primaryText,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.4,
        color: primaryText,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.4,
        color: secondaryText,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: secondaryText,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: secondaryText,
      ),
    );
  }
}

class AppTheme {
  static ThemeData lightTheme = _buildTheme(Brightness.light);
  static ThemeData darkTheme = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: isDark ? AppPalette.primaryDark : AppPalette.primaryLight,
      brightness: brightness,
      primary: isDark ? AppPalette.primaryDark : AppPalette.primaryLight,
      secondary: isDark ? AppPalette.secondaryDark : AppPalette.secondaryLight,
      tertiary: isDark ? AppPalette.tertiaryDark : AppPalette.tertiaryLight,
      surface: isDark ? AppPalette.surfaceDark : AppPalette.surfaceLight,
      error: isDark ? AppPalette.errorDark : AppPalette.errorLight,
    ).copyWith(
      surface: isDark ? AppPalette.surfaceDark : AppPalette.surfaceLight,
      surfaceContainerLowest: isDark ? const Color(0xFF12141C) : const Color(0xFFFFFFFF),
      surfaceContainerLow: isDark ? const Color(0xFF171A23) : const Color(0xFFF8FBFF),
      surfaceContainer: isDark ? const Color(0xFF1D212C) : const Color(0xFFF0F4FA),
      surfaceContainerHigh: isDark ? const Color(0xFF252A37) : const Color(0xFFE8EEF8),
      surfaceContainerHighest: isDark ? const Color(0xFF2F3543) : const Color(0xFFE0E8F0),
      outline: isDark ? const Color(0xFF3A3D4F) : const Color(0xFF8B9CB7),
      outlineVariant: isDark ? const Color(0xFF2D2F3D) : const Color(0xFFC5D1E3),
      shadow: isDark ? Colors.black : const Color(0xFF22324D),
    );

    final textTheme = AppTypography.buildTextTheme(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AppPalette.backgroundDark : AppPalette.backgroundLight,
      primaryColor: colorScheme.primary,
      canvasColor: colorScheme.surface,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkRipple.splashFactory,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      fontFamilyFallback: const [
        'Segoe UI',
        'Roboto',
        'NotoSansDevanagari',
        'Nirmala UI',
        'Mangal',
        'Noto Sans Devanagari',
        'sans-serif',
      ],
      textTheme: textTheme,
      // Smooth color/typography transitions when the user toggles dark mode
      // (animation duration matches the page transition; see AppDurations).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeThroughPageTransitionsBuilder(),
          TargetPlatform.iOS: _FadeThroughPageTransitionsBuilder(),
          TargetPlatform.macOS: _FadeThroughPageTransitionsBuilder(),
          TargetPlatform.windows: _FadeThroughPageTransitionsBuilder(),
          TargetPlatform.linux: _FadeThroughPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _FadeThroughPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 6 : 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: isDark ? AppPalette.cardDark : colorScheme.surface,
        shadowColor: isDark ? Colors.black87 : colorScheme.shadow.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(
            color: isDark ? AppPalette.borderDark : colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      iconTheme: IconThemeData(
        color: colorScheme.onSurface,
        size: 20,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.all(10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ).copyWith(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onSurface.withValues(alpha: 0.4);
            }
            return colorScheme.onSurface;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return colorScheme.primary.withValues(alpha: 0.14);
            }
            if (states.contains(WidgetState.hovered)) {
              return colorScheme.primary.withValues(alpha: 0.08);
            }
            return null;
          }),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(120, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(120, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          side: BorderSide(color: colorScheme.outline),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(96, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1E28) : const Color(0xFFF8FBFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.65),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.9),
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: textTheme.labelLarge,
        dataTextStyle: textTheme.bodyMedium,
        headingRowColor: WidgetStateProperty.all(
          colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.07),
        ),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: isDark ? 0.24 : 0.12);
          }
          if (states.contains(WidgetState.hovered)) {
            return colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.05);
          }
          return null;
        }),
        dividerThickness: 0.8,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: isDark ? 6 : 0,
        backgroundColor: isDark ? const Color(0xFF323446) : const Color(0xFF173A73),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white : Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: isDark ? BorderSide(color: AppPalette.borderDark) : BorderSide.none,
        ),
        width: 600,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: isDark ? BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)) : BorderSide.none,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 350),
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
        decoration: BoxDecoration(
          color: AppPalette.elevatedDark.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        isDark ? AppSemanticColors.dark : AppSemanticColors.light,
      ],
    );
  }
}

/// Page transition that fades the outgoing screen out and the incoming
/// screen in with a tiny scale-up on the new page. This is the same
/// "FadeThrough" pattern Material 3 uses for container transforms, but
/// applied to full-screen routes so navigating between screens feels
/// premium rather than a horizontal slide.
class _FadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeThroughPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOut,
      ),
    );
    final fadeIn = CurvedAnimation(parent: animation, curve: Curves.easeIn);
    final scaleIn = Tween<double>(begin: 0.98, end: 1.0).animate(fadeIn);
    return FadeTransition(
      opacity: fadeOut,
      child: FadeTransition(
        opacity: fadeIn,
        child: ScaleTransition(scale: scaleIn, child: child),
      ),
    );
  }
}

/// Convenience: push a route with a fade-through transition instead of
/// the default horizontal slide. Use this in place of Navigator.push
/// for in-app navigations; full-screen dialogs / modals can keep their
/// own transition.
Future<T?> pushFade<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: AppDurations.normal,
      reverseTransitionDuration: AppDurations.fast,
      transitionsBuilder: (context, animation, secondary, child) {
        final fadeIn = CurvedAnimation(parent: animation, curve: Curves.easeIn);
        final scaleIn = Tween<double>(begin: 0.98, end: 1.0).animate(fadeIn);
        return FadeTransition(
          opacity: fadeIn,
          child: ScaleTransition(scale: scaleIn, child: child),
        );
      },
    ),
  );
}
