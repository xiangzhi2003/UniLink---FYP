// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : app_tokens.dart
// Description     : Shared design tokens -- spacing scale and corner-radius constants.
// First Written on: Tuesday,07-Jul-2026
// Edited on       : Tuesday,07-Jul-2026

import 'package:flutter/material.dart';

/// Shared spacing scale — use instead of inline `EdgeInsets`/`SizedBox` literals.
class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Top inset for [ColoredHeader] blocks — sits inside a `SafeArea`, so this
  /// only needs to clear the header's own breathing room, not the status bar.
  static const headerTop = 20.0;
}

/// Shared corner-radius scale (reference: rounded-2xl/3xl "soft app" look).
class AppRadius {
  static const sm = 12.0;
  static const md = 14.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const pill = 999.0;
}

/// Shared elevation/shadow presets (the app is otherwise a flat/bordered
/// design, so these are used sparingly — e.g. floating cards, dialogs).
class AppElevation {
  static const List<BoxShadow> flat = [];

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 8)),
  ];
}

/// Shared animation durations.
class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
}
