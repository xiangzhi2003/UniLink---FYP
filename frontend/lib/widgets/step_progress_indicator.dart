// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : step_progress_indicator.dart
// Description     : Horizontal step-progress bar widget used by the registration wizard.
// First Written on: Tuesday,07-Jul-2026
// Edited on       : Tuesday,07-Jul-2026

import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Horizontal bar stepper (e.g. register_screen's 2-step wizard) — a row of
/// pill segments, filled up to and including [currentStep].
class StepProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StepProgressIndicator({super.key, required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < totalSteps; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: AppDurations.normal,
              height: 4,
              decoration: BoxDecoration(
                color: i <= currentStep ? scheme.primary : scheme.outline,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          if (i != totalSteps - 1) const SizedBox(width: AppSpacing.xs),
        ],
      ],
    );
  }
}
