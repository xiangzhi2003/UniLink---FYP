// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : profile_screen.dart
// Description     : The signed-in user's own profile hub -- deals, reviews, settings, and navigation to My Deals/notifications.
// First Written on: Tuesday,07-Jul-2026
// Edited on       : Thursday,16-Jul-2026

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/review.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/review_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/error_messages.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/colored_header.dart';
import '../../widgets/stamp_mark.dart';
import '../../widgets/star_rating.dart';
import '../marketplace/favorites_screen.dart';
import '../notifications/notifications_screen.dart';
import '../transactions/transactions_list_screen.dart';
import '../wallet/wallet_screen.dart';
import 'edit_profile_screen.dart';
import 'seller_profile_screen.dart';

/// The signed-in user's profile tab: identity, quick access to My Deals/
/// Favorites/Wallet (My Listings has its own top-level shell tab now), a
/// System/Light/Dark theme control, and sign-out.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _signingOut = false;
  String? _error;
  late final Future<List<Review>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    final myId = ref.read(authServiceProvider).currentUser?.id;
    _reviewsFuture = myId == null
        ? Future.value(const [])
        : ref.read(reviewServiceProvider).fetchReviewsForSeller(myId);
  }

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
    final heldDeals = ref.watch(heldDealsCountProvider).valueOrNull ?? 0;
    final unreviewed = ref.watch(unreviewedCompletedCountProvider).valueOrNull ?? 0;

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
                    const SizedBox(height: AppSpacing.sm),
                    InkWell(
                      onTap: () {
                        final myId = ref.read(authServiceProvider).currentUser?.id;
                        if (myId == null) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SellerProfileScreen(sellerId: myId),
                          ),
                        );
                      },
                      child: FutureBuilder<List<Review>>(
                        future: _reviewsFuture,
                        builder: (context, snapshot) {
                          final reviews = snapshot.data;
                          if (reviews == null) return const SizedBox.shrink();
                          if (reviews.isEmpty) {
                            return const Text(
                              'No reviews yet',
                              style: TextStyle(color: Colors.white70),
                            );
                          }
                          final average = reviews.map((r) => r.rating).reduce((a, b) => a + b) /
                              reviews.length;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StarRating(rating: average.round(), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '${average.toStringAsFixed(1)} (${reviews.length} review${reviews.length == 1 ? '' : 's'})',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
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
                        icon: Icons.handshake_outlined,
                        label: 'My Deals',
                        badgeCount: heldDeals + unreviewed,
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
  final int badgeCount;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: AppSpacing.md),
      child: Column(
        children: [
          Badge(
            label: Text('$badgeCount'),
            backgroundColor: Colors.red,
            isLabelVisible: badgeCount > 0,
            child: Icon(icon, color: scheme.primary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 9.5, height: 1.15),
          ),
        ],
      ),
    );
  }
}
