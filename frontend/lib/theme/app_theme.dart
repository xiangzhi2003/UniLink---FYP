import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Academic Navy" palette — a collegiate navy-and-gold identity (the kind
/// university letterheads and campus-card systems use) built around
/// UniLink's distinguishing mechanic: verification.
class AppColors {
  static const ink = Color(0xFF0F2A4A);
  static const inkDeep = Color(0xFF081A30);
  static const paper = Color(0xFFF4F6F9);
  static const gold = Color(0xFFC2932E);
  static const goldDeep = Color(0xFFA5791E);
  static const verified = Color(0xFF2E7D5B);
  static const slate = Color(0xFF5B6472);
  static const line = Color(0xFFDCE1E8);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);

    // Every override below sets `color:` explicitly — relying on the
    // ambient DefaultTextStyle fallback for a null color made some labels
    // unreadable in practice, so nothing here is left to inherit.
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink)
        .copyWith(
          displayLarge: GoogleFonts.ibmPlexMono(
              fontWeight: FontWeight.w600, fontSize: 40, color: AppColors.ink),
          displayMedium: GoogleFonts.ibmPlexMono(
              fontWeight: FontWeight.w600, fontSize: 32, color: AppColors.ink),
          headlineLarge: GoogleFonts.ibmPlexMono(
              fontWeight: FontWeight.w600, fontSize: 28, color: AppColors.ink),
          headlineMedium: GoogleFonts.ibmPlexMono(
              fontWeight: FontWeight.w600, fontSize: 24, color: AppColors.ink),
          headlineSmall: GoogleFonts.ibmPlexMono(
              fontWeight: FontWeight.w600, fontSize: 20, color: AppColors.ink),
          titleLarge: GoogleFonts.ibmPlexMono(
              fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.ink),
          labelLarge: GoogleFonts.ibmPlexMono(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            letterSpacing: 0.6,
            color: AppColors.ink,
          ),
          bodyMedium: GoogleFonts.manrope(fontSize: 14, color: AppColors.ink),
          bodySmall: GoogleFonts.manrope(fontSize: 12, color: AppColors.slate),
        );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.ink,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.ink,
      onPrimary: AppColors.paper,
      secondary: AppColors.gold,
      onSecondary: AppColors.inkDeep,
      tertiary: AppColors.verified,
      onTertiary: AppColors.paper,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.slate,
      outline: AppColors.line,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.paper,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: AppColors.slate),
        hintStyle: TextStyle(color: AppColors.slate.withValues(alpha: 0.7)),
        helperStyle: const TextStyle(color: AppColors.slate),
        errorStyle: const TextStyle(color: Color(0xFFB3261E)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.ink, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.inkDeep,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: textTheme.labelLarge?.copyWith(color: AppColors.inkDeep),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.ink),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    );
  }
}
