// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : suspended_screen.dart
// Description     : Screen shown instead of the app to a suspended account, with sign-out as the only action.
// First Written on: Friday,17-Jul-2026
// Edited on       : Friday,17-Jul-2026

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_button.dart';

/// Shown by AuthGate instead of the app when the signed-in account has
/// been suspended by an admin. The only action is signing out.
class SuspendedScreen extends ConsumerStatefulWidget {
  const SuspendedScreen({super.key});

  @override
  ConsumerState<SuspendedScreen> createState() => _SuspendedScreenState();
}

class _SuspendedScreenState extends ConsumerState<SuspendedScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await ref.read(authServiceProvider).signOut();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.block, size: 56, color: scheme.error),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Account suspended',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your account has been suspended by an administrator. '
                  'Contact campus support if you believe this is a mistake.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xxl),
                SecondaryButton(
                  label: 'Sign out',
                  isLoading: _signingOut,
                  onPressed: _signOut,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
