// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : colored_header.dart
// Description     : Shared full-bleed colored header block used atop Browse/Profile/Chat/etc. screens.
// First Written on: Tuesday,07-Jul-2026
// Edited on       : Tuesday,07-Jul-2026

import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Full-bleed colored header block (title/search/stats) sitting directly
/// above plain page content — the reference's signature layout motif,
/// replacing a plain white AppBar on Browse/Profile/Chat/AI Search/QR.
class ColoredHeader extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  const ColoredHeader({super.key, required this.child, this.padding, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: color ?? scheme.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: padding ??
              const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.headerTop,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
          child: child,
        ),
      ),
    );
  }
}
