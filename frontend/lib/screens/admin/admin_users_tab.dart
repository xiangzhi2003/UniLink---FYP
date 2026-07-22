// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : admin_users_tab.dart
// Description     : Admin tab for managing user accounts (suspend/unsuspend, search/sort).
// First Written on: Friday,17-Jul-2026
// Edited on       : Friday,17-Jul-2026

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/error_messages.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';

typedef _AdminUser = ({
  String id,
  String? email,
  String? fullName,
  String? university,
  String role,
  bool suspended,
});

/// User management: every account, with suspend/unsuspend moderation.
/// Admin accounts can't be suspended (enforced server-side too).
class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> {
  late Future<List<_AdminUser>> _future;
  bool _busy = false;
  String _query = '';
  bool _sortAZ = true;

  @override
  void initState() {
    super.initState();
    _future = ref.read(backendServiceProvider).fetchAdminUsers();
  }

  void _reload() {
    setState(() {
      _future = ref.read(backendServiceProvider).fetchAdminUsers();
    });
  }

  Future<void> _setSuspended(_AdminUser user, bool suspended) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(suspended ? 'Suspend user?' : 'Unsuspend user?'),
        content: Text(
          suspended
              ? '${user.fullName ?? user.email ?? 'This user'} will be locked '
                  'out of the app until unsuspended.'
              : '${user.fullName ?? user.email ?? 'This user'} will regain '
                  'full access to the app.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: suspended
                ? TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error)
                : null,
            child: Text(suspended ? 'Suspend' : 'Unsuspend'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(backendServiceProvider).adminSetSuspended(user.id, suspended);
      if (mounted) _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showDetails(_AdminUser user) {
    final name = user.fullName ?? 'Unnamed';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(icon: Icons.email_outlined, label: user.email ?? '—'),
            _DetailRow(icon: Icons.school_outlined, label: user.university ?? 'No university set'),
            _DetailRow(
              icon: Icons.badge_outlined,
              label: user.role == 'admin' ? 'Administrator' : 'Student',
            ),
            _DetailRow(
              icon: user.suspended ? Icons.block : Icons.check_circle_outline,
              label: user.suspended ? 'Suspended' : 'Active',
            ),
          ],
        ),
        actions: [
          if (user.role != 'admin')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _setSuspended(user, !user.suspended);
              },
              style: !user.suspended
                  ? TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error)
                  : null,
              child: Text(user.suspended ? 'Unsuspend' : 'Suspend'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  List<_AdminUser> _filter(List<_AdminUser> users) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? users.toList()
        : users.where((u) {
            return (u.fullName ?? '').toLowerCase().contains(q) ||
                (u.email ?? '').toLowerCase().contains(q) ||
                (u.university ?? '').toLowerCase().contains(q);
          }).toList();

    filtered.sort((a, b) {
      final cmp = (a.fullName ?? '').toLowerCase().compareTo((b.fullName ?? '').toLowerCase());
      return _sortAZ ? cmp : -cmp;
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search by name, email, or university...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filledTonal(
                tooltip: _sortAZ ? 'Sorted A → Z' : 'Sorted Z → A',
                icon: Icon(_sortAZ ? Icons.arrow_downward : Icons.arrow_upward),
                onPressed: () => setState(() => _sortAZ = !_sortAZ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncStateView<List<_AdminUser>>(
            future: _future,
            onRetry: _reload,
            loadingSkeleton: const Center(child: CircularProgressIndicator()),
            isEmpty: (users) => users.isEmpty,
            emptyState: const EmptyState(icon: Icons.people_outline, title: 'No users yet'),
            builder: (context, allUsers) {
              final users = _filter(allUsers);
              if (users.isEmpty) {
                return const EmptyState(
                  icon: Icons.search_off,
                  title: 'No matches',
                  message: 'Try a different search term.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final name = user.fullName ?? 'Unnamed';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        onTap: () => _showDetails(user),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: scheme.primary,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(color: scheme.onPrimary),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user.email ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                                  ),
                                  if (user.university != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      user.university!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            if (user.role == 'admin')
                              const StatusChip(label: 'Admin', variant: StatusVariant.info)
                            else if (user.suspended) ...[
                              const StatusChip(label: 'Suspended', variant: StatusVariant.warning),
                              IconButton(
                                tooltip: 'Unsuspend',
                                icon: Icon(Icons.lock_open, color: scheme.primary),
                                onPressed: _busy ? null : () => _setSuspended(user, false),
                              ),
                            ] else
                              IconButton(
                                tooltip: 'Suspend',
                                icon: Icon(Icons.block, color: scheme.error),
                                onPressed: _busy ? null : () => _setSuspended(user, true),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
