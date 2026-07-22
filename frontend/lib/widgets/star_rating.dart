// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : star_rating.dart
// Description     : Row-of-5-stars widget, read-only or interactive depending on context.
// First Written on: Thursday,16-Jul-2026
// Edited on       : Thursday,16-Jul-2026

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A row of 5 stars. Read-only display when [onChanged] is null (seller
/// profile summary, review list rows); interactive tap-to-select when it's
/// provided (leave-review form). One widget instead of duplicating
/// star-icon-row logic in three places.
class StarRating extends StatelessWidget {
  final int rating; // 0-5
  final ValueChanged<int>? onChanged;
  final double size;

  const StarRating({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = isDark ? AppColorsDark.gold : AppColors.gold;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(i),
            child: Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(
                i <= rating ? Icons.star : Icons.star_border,
                color: i <= rating ? gold : scheme.onSurfaceVariant,
                size: size,
              ),
            ),
          ),
      ],
    );
  }
}
