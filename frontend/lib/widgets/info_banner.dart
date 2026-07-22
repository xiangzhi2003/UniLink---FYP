// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : info_banner.dart
// Description     : Tinted informational note box used on auth screens.
// First Written on: Friday,03-Jul-2026
// Edited on       : Tuesday,07-Jul-2026

import 'package:flutter/material.dart';

/// Tinted note box used on auth screens to reinforce the .edu.my-only
/// verification gate.
class InfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;

  const InfoBanner({super.key, required this.text, this.icon = Icons.verified_user_outlined});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.primary, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
