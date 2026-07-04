import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../widgets/stamp_mark.dart';

/// Placeholder post-login home. Real marketplace content arrives in Sprint 2;
/// this just proves the responsive layout pattern and the sign-out flow.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  bool _signingOut = false;
  String? _error;

  Future<void> _signOut() async {
    setState(() {
      _signingOut = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).signOut();
    } catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('UniLink')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;
          final content = Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const StampMark(sealed: true, size: 72),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome, ${profile?.fullName ?? 'student'}',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile?.university ?? '',
                    style: TextStyle(color: AppColors.slate),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _signingOut ? null : _signOut,
                    child: _signingOut
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Sign out'),
                  ),
                ],
              ),
            ),
          );

          if (isWide) {
            return Row(
              children: [
                SizedBox(
                  width: 220,
                  child: NavigationRail(
                    backgroundColor: AppColors.paper,
                    selectedIndex: 0,
                    selectedIconTheme: const IconThemeData(color: AppColors.ink),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: Text('Home'),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, color: AppColors.line),
                Expanded(child: content),
              ],
            );
          }

          return content;
        },
      ),
    );
  }
}
