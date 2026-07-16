import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import 'admin_dashboard_tab.dart';
import 'admin_listings_tab.dart';
import 'admin_reports_tab.dart';
import 'admin_users_tab.dart';

/// The admin's whole app: AuthGate lands here instead of HomeShell when the
/// signed-in profile has role == 'admin' (granted manually in the database).
/// Admins moderate; they don't buy/sell, so none of the student shell
/// appears — which also means sign-out has to live here.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('UniLink Admin'),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => _confirmSignOut(context, ref),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Dashboard'),
              Tab(text: 'Listings'),
              Tab(text: 'Users'),
              Tab(text: 'Reports'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AdminDashboardTab(),
            AdminListingsTab(),
            AdminUsersTab(),
            AdminReportsTab(),
          ],
        ),
      ),
    );
  }
}
