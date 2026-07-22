// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : web_landing_page.dart
// Description     : Marketing landing page shown when the app is opened in a web browser.
// First Written on: Tuesday,07-Jul-2026
// Edited on       : Tuesday,07-Jul-2026

import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_button.dart';

/// Marketing landing page shown when the app runs in a browser (`kIsWeb`).
/// The real marketplace only exists on Android/iOS — this keeps a
/// professional web presence without letting students bypass the app.
class WebLandingPage extends StatelessWidget {
  const WebLandingPage({super.key});

  static const _wideBreakpoint = 800.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _wideBreakpoint;
            return Column(
              children: [
                _HeroSection(isWide: isWide),
                _FeaturesSection(isWide: isWide),
                _HowItWorksSection(isWide: isWide),
                const _Footer(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final bool isWide;
  const _HeroSection({required this.isWide});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.primary,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: isWide ? AppSpacing.xxxl * 2 : AppSpacing.xxxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Center(
                  child: Text(
                    'U',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: scheme.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'UniLink',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Colors.white,
                      fontSize: isWide ? 52 : 36,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'The Smart Campus Marketplace. Buy, Sell & Rent within your University.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              SizedBox(
                width: isWide ? 320 : double.infinity,
                child: PrimaryButton(
                  label: 'Get it on Google Play',
                  icon: Icons.shop,
                  onPressed: () {},
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Available for Android',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureData {
  final String emoji;
  final String title;
  final String description;
  const _FeatureData(this.emoji, this.title, this.description);
}

const _features = [
  _FeatureData('🏰', 'Campus Wall', 'Only verified university students. No scammers.'),
  _FeatureData(
      '🤖', 'AI Search', 'Find what you need in plain English, not just keywords.'),
  _FeatureData('🤝', 'QR Handshake', 'Scan to confirm pickup and return. Tamper-proof.'),
  _FeatureData('🔐', 'Escrow Vault',
      'Your money is protected until the item is safely returned.'),
];

class _FeaturesSection extends StatelessWidget {
  final bool isWide;
  const _FeaturesSection({required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xxxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            alignment: WrapAlignment.center,
            children: [
              for (final feature in _features)
                SizedBox(
                  width: isWide ? 220 : 320,
                  child: _FeatureCard(feature: feature),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final _FeatureData feature;
  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppElevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(feature.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: AppSpacing.md),
          Text(
            feature.title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            feature.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _StepData {
  final String number;
  final String title;
  final String description;
  const _StepData(this.number, this.title, this.description);
}

const _steps = [
  _StepData('1️⃣', 'Search', 'Find items using AI natural language'),
  _StepData('2️⃣', 'Book', 'Pay securely via escrow'),
  _StepData('3️⃣', 'Meet & Scan', 'Confirm handover with QR code'),
  _StepData('4️⃣', 'Done', 'Money releases automatically'),
];

class _HowItWorksSection extends StatelessWidget {
  final bool isWide;
  const _HowItWorksSection({required this.isWide});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xxxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Text(
                'How It Works',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                alignment: WrapAlignment.center,
                children: [
                  for (final step in _steps)
                    SizedBox(
                      width: isWide ? 220 : 320,
                      child: _StepCard(step: step),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final _StepData step;
  const _StepCard({required this.step});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(step.number, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          step.title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          step.description,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xxl,
      ),
      child: Center(
        child: Column(
          children: [
            Text(
              'UniLink © 2025 — Built for APU Students',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Supporting SDG 12: Responsible Consumption',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
