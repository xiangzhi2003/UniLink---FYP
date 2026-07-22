// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : status_chip.dart
// Description     : Small colored status chip widget and its semantic color-variant mapping.
// First Written on: Tuesday,07-Jul-2026
// Edited on       : Tuesday,07-Jul-2026

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// Semantic color intent for [StatusChip]/[StatusBanner] — maps to theme
/// colors rather than each call site picking its own literal color.
enum StatusVariant { success, warning, info, neutral, danger }

class _VariantColors {
  final Color fg;
  final Color bg;
  const _VariantColors(this.fg, this.bg);
}

_VariantColors _colorsFor(BuildContext context, StatusVariant variant) {
  final scheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final infoBlue = isDark ? AppColorsDark.infoBlue : AppColors.infoBlue;
  return switch (variant) {
    StatusVariant.success => _VariantColors(scheme.tertiary, scheme.tertiary.withValues(alpha: 0.12)),
    StatusVariant.warning => _VariantColors(scheme.secondary, scheme.secondary.withValues(alpha: 0.16)),
    // In-progress/held/rent states read as blue, distinct from primary violet
    // (which is reserved for primary actions), matching the reference.
    StatusVariant.info => _VariantColors(infoBlue, infoBlue.withValues(alpha: 0.12)),
    StatusVariant.neutral => _VariantColors(scheme.onSurfaceVariant, scheme.surfaceContainerHighest),
    StatusVariant.danger => _VariantColors(scheme.error, scheme.error.withValues(alpha: 0.12)),
  };
}

/// Small pill badge for a status word (e.g. "Active", "Sold", "Pending").
class StatusChip extends StatelessWidget {
  final String label;
  final StatusVariant variant;
  final IconData? icon;

  const StatusChip({super.key, required this.label, this.variant = StatusVariant.neutral, this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(context, variant);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: colors.fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: colors.fg, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
