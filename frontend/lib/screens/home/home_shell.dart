import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../widgets/stamp_mark.dart';
import '../chat/chat_list_screen.dart';
import '../marketplace/browse_screen.dart';
import '../marketplace/create_listing_screen.dart';
import '../marketplace/my_listings_screen.dart';
import '../transactions/transactions_list_screen.dart';

/// Signed-in shell: Marketplace / Deals / Chats / My Listings / Profile tabs,
/// with a bottom nav bar on phones and a side rail on wide screens, plus the
/// global "Sell an item" action.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;

  final _browseKey = GlobalKey<BrowseScreenState>();
  final _dealsKey = GlobalKey<TransactionsListScreenState>();
  final _chatsKey = GlobalKey<ChatListScreenState>();
  final _myListingsKey = GlobalKey<MyListingsScreenState>();

  bool _signingOut = false;
  String? _error;

  static const _chatsTabIndex = 2;
  static const _profileTabIndex = 4;

  static const _destinations = [
    (icon: Icons.storefront_outlined, selectedIcon: Icons.storefront, label: 'Marketplace'),
    (icon: Icons.handshake_outlined, selectedIcon: Icons.handshake, label: 'Deals'),
    (icon: Icons.forum_outlined, selectedIcon: Icons.forum, label: 'Chats'),
    (icon: Icons.sell_outlined, selectedIcon: Icons.sell, label: 'My Listings'),
    (icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
  ];

  /// Wrap an icon in a small unread badge (used for the Chats destination).
  Widget _badged(IconData icon, int unread) {
    if (unread <= 0) return Icon(icon);
    return Badge(
      label: Text('$unread'),
      backgroundColor: AppColors.gold,
      textColor: AppColors.inkDeep,
      child: Icon(icon),
    );
  }

  Future<void> _openCreateListing() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateListingScreen()),
    );
    if (created == true) {
      _browseKey.currentState?.reload();
      _myListingsKey.currentState?.reload();
    }
  }

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

  Widget _buildProfileTab(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StampMark(sealed: true, size: 72),
            const SizedBox(height: 20),
            Text(
              profile?.fullName ?? 'Student',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              profile?.email ?? '',
              style: const TextStyle(color: AppColors.slate),
            ),
            const SizedBox(height: 4),
            Text(
              profile?.university ?? '',
              style: const TextStyle(color: AppColors.slate),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: 240,
              child: ElevatedButton(
                onPressed: _signingOut ? null : _signOut,
                child: _signingOut
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Sign out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    final body = switch (_tab) {
      0 => BrowseScreen(key: _browseKey),
      1 => TransactionsListScreen(key: _dealsKey),
      2 => ChatListScreen(key: _chatsKey),
      3 => MyListingsScreen(key: _myListingsKey),
      _ => _buildProfileTab(context),
    };

    // Chats icon carries the unread badge; others are plain.
    Widget iconFor(int index, bool selected) {
      final d = _destinations[index];
      final icon = selected ? d.selectedIcon : d.icon;
      return index == _chatsTabIndex ? _badged(icon, unread) : Icon(icon);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        return Scaffold(
          appBar: AppBar(title: const Text('UniLink')),
          floatingActionButton: _tab == _profileTabIndex
              ? null
              : FloatingActionButton.extended(
                  onPressed: _openCreateListing,
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.inkDeep,
                  icon: const Icon(Icons.add),
                  label: const Text('Sell an item'),
                ),
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: _tab,
                  onDestinationSelected: (index) => setState(() => _tab = index),
                  backgroundColor: Colors.white,
                  indicatorColor: AppColors.gold.withValues(alpha: 0.25),
                  destinations: [
                    for (var i = 0; i < _destinations.length; i++)
                      NavigationDestination(
                        icon: iconFor(i, false),
                        selectedIcon: iconFor(i, true),
                        label: _destinations[i].label,
                      ),
                  ],
                ),
          body: isWide
              ? Row(
                  children: [
                    NavigationRail(
                      backgroundColor: AppColors.paper,
                      selectedIndex: _tab,
                      onDestinationSelected: (index) => setState(() => _tab = index),
                      labelType: NavigationRailLabelType.all,
                      selectedIconTheme: const IconThemeData(color: AppColors.ink),
                      destinations: [
                        for (var i = 0; i < _destinations.length; i++)
                          NavigationRailDestination(
                            icon: iconFor(i, false),
                            selectedIcon: iconFor(i, true),
                            label: Text(_destinations[i].label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1, color: AppColors.line),
                    Expanded(child: body),
                  ],
                )
              : body,
        );
      },
    );
  }
}
