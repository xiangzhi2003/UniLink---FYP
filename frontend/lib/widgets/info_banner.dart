import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Tinted note box used on auth screens to reinforce the .edu.my-only
/// verification gate.
class InfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;

  const InfoBanner({super.key, required this.text, this.icon = Icons.verified_user_outlined});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.ink, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
