// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : admin_shell.dart
// Description     : Root shell for the admin app -- bottom navigation across the dashboard, listings, users, reports and knowledge tabs.
// First Written on: Friday,17-Jul-2026
// Edited on       : Friday,17-Jul-2026

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import 'admin_dashboard_tab.dart';
import 'admin_knowledge_tab.dart';
import 'admin_listings_tab.dart';
import 'admin_reports_tab.dart';
import 'admin_users_tab.dart';

/// The admin's whole app: AuthGate lands here instead of HomeShell when the
/// signed-in profile has role == 'admin' (granted manually in the database).
/// Bottom nav mirrors the student shell's look (icon + label row) instead
/// of top tabs, for a consistent feel across both.
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _tab = 0;

  static const _titles = ['Dashboard', 'Listings', 'Users', 'Reports', 'Knowledge'];

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
    if (confirmed == true) {
      await ref.read(authServiceProvider).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_tab) {
      0 => AdminDashboardTab(onNavigateToTab: (index) => setState(() => _tab = index)),
      1 => const AdminListingsTab(),
      2 => const AdminUsersTab(),
      3 => const AdminReportsTab(),
      _ => const AdminKnowledgeTab(),
    };

    return Scaffold(
      // The Listings/Users search+filter fields sit near the top of a
      // Column that isn't independently scrollable -- letting the body
      // resize for the keyboard could squeeze it into a RenderFlex
      // overflow. The keyboard just overlays the bottom instead, which is
      // fine since nothing critical needs to stay visible while typing.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text('UniLink Admin · ${_titles[_tab]}'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _confirmSignOut,
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: _AdminBottomNav(
        selectedIndex: _tab,
        onSelect: (index) => setState(() => _tab = index),
      ),
    );
  }
}

class _AdminBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _AdminBottomNav({required this.selectedIndex, required this.onSelect});

  static const _items = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    (Icons.storefront_outlined, Icons.storefront, 'Listings'),
    (Icons.people_outline, Icons.people, 'Users'),
    (Icons.flag_outlined, Icons.flag, 'Reports'),
    (Icons.menu_book_outlined, Icons.menu_book, 'Knowledge'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                _NavItem(
                  icon: _items[i].$1,
                  selectedIcon: _items[i].$2,
                  label: _items[i].$3,
                  selected: selectedIndex == i,
                  onTap: () => onSelect(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
