import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/app_bottom_nav.dart';
import '../ai/ai_search_screen.dart';
import '../chat/chat_list_screen.dart';
import '../marketplace/browse_screen.dart';
import '../marketplace/create_listing_screen.dart';
import '../profile/profile_screen.dart';

/// Signed-in shell: Home / AI Search / Sell / Chat / Profile, with a bottom
/// nav bar on phones and a side rail on wide screens. Deals and My Listings
/// are no longer top-level tabs — they're reached from Profile.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;

  final _browseKey = GlobalKey<BrowseScreenState>();
  final _chatsKey = GlobalKey<ChatListScreenState>();

  static const _titles = {0: 'Home', 1: 'AI Search', 3: 'Chat', 4: 'Profile'};

  Future<void> _openCreateListing() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateListingScreen()),
    );
    if (created == true) {
      _browseKey.currentState?.reload();
    }
  }

  void _selectTab(int index) {
    if (index == 2) {
      _openCreateListing();
      return;
    }
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final unreadNotifications = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    final scheme = Theme.of(context).colorScheme;

    final body = switch (_tab) {
      0 => BrowseScreen(key: _browseKey),
      1 => const AiSearchScreen(),
      3 => ChatListScreen(key: _chatsKey),
      _ => const ProfileScreen(),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        return Scaffold(
          appBar: isWide ? AppBar(title: Text(_titles[_tab] ?? '')) : null,
          bottomNavigationBar: isWide
              ? null
              : AppBottomNav(
                  selectedIndex: _tab,
                  onSelect: _selectTab,
                  onSell: _openCreateListing,
                  chatUnreadCount: unread,
                  profileUnreadCount: unreadNotifications,
                ),
          body: isWide
              ? Row(
                  children: [
                    NavigationRail(
                      backgroundColor: scheme.surface,
                      selectedIndex: _tab,
                      onDestinationSelected: _selectTab,
                      labelType: NavigationRailLabelType.all,
                      selectedIconTheme: IconThemeData(color: scheme.primary),
                      destinations: [
                        const NavigationRailDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home),
                          label: Text('Home'),
                        ),
                        const NavigationRailDestination(
                          icon: Icon(Icons.auto_awesome_outlined),
                          selectedIcon: Icon(Icons.auto_awesome),
                          label: Text('AI Search'),
                        ),
                        const NavigationRailDestination(
                          icon: Icon(Icons.add_circle_outline),
                          selectedIcon: Icon(Icons.add_circle),
                          label: Text('Sell'),
                        ),
                        NavigationRailDestination(
                          icon: unread > 0
                              ? Badge(label: Text('$unread'), child: const Icon(Icons.forum_outlined))
                              : const Icon(Icons.forum_outlined),
                          selectedIcon: const Icon(Icons.forum),
                          label: const Text('Chat'),
                        ),
                        NavigationRailDestination(
                          icon: unreadNotifications > 0
                              ? Badge(
                                  label: Text('$unreadNotifications'),
                                  backgroundColor: Colors.red,
                                  child: const Icon(Icons.person_outline),
                                )
                              : const Icon(Icons.person_outline),
                          selectedIcon: const Icon(Icons.person),
                          label: const Text('Profile'),
                        ),
                      ],
                    ),
                    VerticalDivider(width: 1, color: scheme.outline),
                    Expanded(child: body),
                  ],
                )
              : body,
        );
      },
    );
  }
}
