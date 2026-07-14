import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/error_messages.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/colored_header.dart';
import '../../widgets/stamp_mark.dart';
import '../marketplace/favorites_screen.dart';
import '../marketplace/my_listings_screen.dart';
import '../notifications/notifications_screen.dart';
import '../transactions/transactions_list_screen.dart';
import '../wallet/wallet_screen.dart';
import 'edit_profile_screen.dart';

/// The signed-in user's profile tab: identity, quick access to My Listings/My
/// Deals (folded in here since they're no longer top-level shell tabs), a
/// System/Light/Dark theme control, and sign-out.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _signingOut = false;
  String? _error;

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text("You'll need to log in again to continue."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed != true) return;

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
    final themeMode = ref.watch(themeModeProvider);
    final scheme = Theme.of(context).colorScheme;
    final unreadNotifications = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ColoredHeader(
                child: Column(
                  children: [
                    const StampMark(sealed: true, size: 72),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      profile?.fullName ?? 'Student',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      profile?.email ?? '',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (profile?.university != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        profile!.university!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                top: AppSpacing.headerTop,
                right: AppSpacing.md,
                child: SafeArea(
                  bottom: false,
                  child: IconButton(
                    icon: Badge(
                      label: Text('$unreadNotifications'),
                      backgroundColor: Colors.red,
                      isLabelVisible: unreadNotifications > 0,
                      child: const Icon(Icons.notifications_outlined, color: Colors.white),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.sell_outlined,
                        label: 'My Listings',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MyListingsScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.handshake_outlined,
                        label: 'My Deals',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const TransactionsListScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.favorite_border,
                        label: 'Favorites',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Wallet',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const WalletScreen()),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, color: scheme.onSurfaceVariant),
                      const SizedBox(width: AppSpacing.md),
                      const Expanded(child: Text('Edit profile')),
                      Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.dark_mode_outlined, color: scheme.onSurfaceVariant),
                          const SizedBox(width: AppSpacing.sm),
                          const Text('Appearance'),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                            ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                          ],
                          selected: {
                            themeMode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light,
                          },
                          onSelectionChanged: (selection) => ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(selection.first),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(_error!, style: TextStyle(color: scheme.error)),
                ],
                const SizedBox(height: AppSpacing.xxl),
                SecondaryButton(
                  label: 'Sign out',
                  isLoading: _signingOut,
                  danger: true,
                  onPressed: _confirmSignOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: AppSpacing.md),
      child: Column(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
