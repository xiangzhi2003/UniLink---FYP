import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_button.dart';

/// First screen of the auth flow: the campus-wall pitch. Sets up the three
/// distinction features before funnelling students into register or login.
class WelcomeScreen extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onLogin;

  const WelcomeScreen({super.key, required this.onGetStarted, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        width: double.infinity,
        color: scheme.primary,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 24),
                    Text(
                      'UniLink',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 36,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Campus Marketplace & Rental',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                    ),
                    const SizedBox(height: 36),
                    const _FeatureRow(
                      icon: Icons.bolt_outlined,
                      label: 'AI-powered semantic search',
                    ),
                    const SizedBox(height: 12),
                    const _FeatureRow(
                      icon: Icons.shield_outlined,
                      label: 'Escrow-protected payments',
                    ),
                    const SizedBox(height: 12),
                    const _FeatureRow(
                      icon: Icons.qr_code_2,
                      label: 'QR digital handshake',
                    ),
                    const SizedBox(height: 48),
                    PrimaryButton(
                      label: 'Get Started',
                      onPressed: onGetStarted,
                      icon: Icons.arrow_forward,
                    ),
                    const SizedBox(height: 12),
                    // A plain `SecondaryButton` would render violet-on-violet
                    // here (it always tints from `scheme.primary`/`scheme.error`),
                    // so this flat-primary background keeps a bespoke
                    // white-on-violet outline instead.
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onLogin,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg)),
                        ),
                        child: const Text('I already have an account'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Only for verified .edu.my students',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: scheme.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
