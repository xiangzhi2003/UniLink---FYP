// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : status_banner.dart
// Description     : Icon+title+detail status banner widget, tinted by semantic variant.
// First Written on: Tuesday,07-Jul-2026
// Edited on       : Tuesday,07-Jul-2026

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'status_chip.dart';

/// Icon + title + detail (+ optional action) banner, tinted by [variant].
/// Consolidates the near-identical status `Container`s repeated across
/// transaction_detail_screen.dart into one parameterized widget.
class StatusBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? detail;
  final StatusVariant variant;
  final Widget? action;

  const StatusBanner({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
    this.variant = StatusVariant.info,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(context, variant);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.fg),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: colors.fg, fontWeight: FontWeight.w700, fontSize: 15),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

_VariantColors _colorsFor(BuildContext context, StatusVariant variant) {
  final scheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final infoBlue = isDark ? AppColorsDark.infoBlue : AppColors.infoBlue;
  return switch (variant) {
    StatusVariant.success => _VariantColors(scheme.tertiary, scheme.tertiary.withValues(alpha: 0.10)),
    StatusVariant.warning => _VariantColors(scheme.secondary, scheme.secondary.withValues(alpha: 0.14)),
    StatusVariant.info => _VariantColors(infoBlue, infoBlue.withValues(alpha: 0.10)),
    StatusVariant.neutral => _VariantColors(scheme.onSurfaceVariant, scheme.surfaceContainerHighest),
    StatusVariant.danger => _VariantColors(scheme.error, scheme.error.withValues(alpha: 0.10)),
  };
}

class _VariantColors {
  final Color fg;
  final Color bg;
  const _VariantColors(this.fg, this.bg);
}
