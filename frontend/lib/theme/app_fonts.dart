import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Numeric/tabular data (prices, ratings, timestamps, QR codes, transaction
/// ids) gets its own monospace treatment distinct from the rest of the UI —
/// call this at each such call site rather than baking it into [TextTheme].
class AppFonts {
  static TextStyle mono(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.dmMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}
