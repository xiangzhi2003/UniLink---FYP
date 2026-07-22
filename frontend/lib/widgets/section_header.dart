// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : section_header.dart
// Description     : Labeled section-divider widget used to group long forms/detail screens.
// First Written on: Tuesday,07-Jul-2026
// Edited on       : Tuesday,07-Jul-2026

import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Labeled section divider (e.g. "PHOTOS", "PRICING & TYPE") with an
/// optional trailing action — used to group long forms and detail screens
/// instead of one-off `Text(style: labelLarge)` calls.
class SectionHeader extends StatelessWidget {
  final String label;
  final Widget? trailing;

  const SectionHeader({super.key, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelLarge),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
