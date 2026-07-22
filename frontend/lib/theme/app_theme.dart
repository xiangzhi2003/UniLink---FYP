// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : app_theme.dart
// Description     : App-wide color palette and ThemeData ('Campus Violet') definitions.
// First Written on: Friday,03-Jul-2026
// Edited on       : Tuesday,07-Jul-2026

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_tokens.dart';

/// "Campus Violet" palette, aligned to the University Student Marketplace
/// Figma reference. Field names (`ink`, `gold`, `slate`, etc.) are kept from
/// the app's original theme so every existing screen recolors automatically;
/// new code should prefer `Theme.of(context).colorScheme` over these directly.
class AppColors {
  static const ink = Color(0xFF5B21B6);
  static const inkDeep = Color(0xFF4C1D95);
  static const paper = Color(0xFFF5F3FF);
  static const gold = Color(0xFFF59E0B);
  static const goldDeep = Color(0xFFD97706);
  static const verified = Color(0xFF10B981);
  static const slate = Color(0xFF6B7280);
  static const line = Color(0x265B21B6);
  static const infoBlue = Color(0xFF3B82F6);
  static const card = Color(0xFFFFFFFF);
  static const inputBg = Color(0xFFEDE9FE);
}

/// Dark-mode counterparts of [AppColors].
class AppColorsDark {
  static const ink = Color(0xFF7C3AED);
  static const inkDeep = Color(0xFF5B21B6);
  static const paper = Color(0xFF0F0A1E);
  static const gold = Color(0xFFF59E0B);
  static const goldDeep = Color(0xFFD97706);
  static const verified = Color(0xFF34D399);
  static const slate = Color(0xFFA78BFA);
  static const line = Color(0x33A78BFA);
  static const infoBlue = Color(0xFF60A5FA);
  static const card = Color(0xFF1A1035);
  static const inputBg = Color(0xFF2D1B69);
}

class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    final ink = isDark ? AppColorsDark.ink : AppColors.ink;
    final paper = isDark ? AppColorsDark.paper : AppColors.paper;
    final gold = isDark ? AppColorsDark.gold : AppColors.gold;
    final verified = isDark ? AppColorsDark.verified : AppColors.verified;
    final slate = isDark ? AppColorsDark.slate : AppColors.slate;
    final line = isDark ? AppColorsDark.line : AppColors.line;
    final surface = isDark ? AppColorsDark.card : AppColors.card;
    final surfaceHigh = isDark ? AppColorsDark.inputBg : AppColors.inputBg;
    final onSurface = isDark ? const Color(0xFFF5F3FF) : const Color(0xFF1E1245);
    final onInk = Colors.white;
    final onGold = isDark ? const Color(0xFF3A2200) : const Color(0xFF3A2200);
    final error = const Color(0xFFEF4444);
    final onError = Colors.white;

    // Every override below sets `color:` explicitly — relying on the
    // ambient DefaultTextStyle fallback for a null color made some labels
    // unreadable in practice, so nothing here is left to inherit.
    final textTheme = GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: onSurface, displayColor: onSurface)
        .copyWith(
          displayLarge: GoogleFonts.fraunces(
              fontWeight: FontWeight.w700, fontSize: 40, color: onSurface),
          displayMedium: GoogleFonts.fraunces(
              fontWeight: FontWeight.w700, fontSize: 32, color: onSurface),
          headlineLarge: GoogleFonts.fraunces(
              fontWeight: FontWeight.w600, fontSize: 28, color: onSurface),
          headlineMedium: GoogleFonts.fraunces(
              fontWeight: FontWeight.w600, fontSize: 24, color: onSurface),
          headlineSmall: GoogleFonts.fraunces(
              fontWeight: FontWeight.w600, fontSize: 20, color: onSurface),
          titleLarge: GoogleFonts.fraunces(
              fontWeight: FontWeight.w600, fontSize: 18, color: onSurface),
          labelLarge: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            letterSpacing: 0.4,
            color: onSurface,
          ),
          bodyMedium: GoogleFonts.inter(fontSize: 14, color: onSurface),
          bodySmall: GoogleFonts.inter(fontSize: 12, color: slate),
        );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: ink,
      brightness: brightness,
    ).copyWith(
      primary: ink,
      onPrimary: onInk,
      primaryContainer: isDark ? const Color(0xFF3D2E80) : const Color(0xFFEDE9FE),
      onPrimaryContainer: isDark ? const Color(0xFFE5DCFF) : const Color(0xFF3D2A99),
      // Kept mapped to the accent gold (not the reference's pale-violet
      // --secondary) so existing "secondary = accent" call sites don't churn.
      secondary: gold,
      onSecondary: onGold,
      tertiary: verified,
      onTertiary: isDark ? const Color(0xFF04241A) : Colors.white,
      surface: surface,
      surfaceContainerHighest: surfaceHigh,
      onSurface: onSurface,
      onSurfaceVariant: slate,
      outline: line,
      error: error,
      onError: onError,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: paper,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: onSurface,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: line),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: TextStyle(color: onSurface),
        secondaryLabelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
        side: BorderSide(color: line),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: colorScheme.primaryContainer,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: gold,
        foregroundColor: onGold,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: onSurface,
        contentTextStyle: TextStyle(color: paper),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: TextStyle(color: slate),
        hintStyle: TextStyle(color: slate.withValues(alpha: 0.7)),
        helperStyle: TextStyle(color: slate),
        errorStyle: TextStyle(color: error),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: ink, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: onGold,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          textStyle: textTheme.labelLarge?.copyWith(color: onGold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: ink),
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1),
    );
  }
}
