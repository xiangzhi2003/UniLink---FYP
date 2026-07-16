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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AsyncStateView<List<_AdminUser>>(
      future: _future,
      onRetry: _reload,
      loadingSkeleton: const Center(child: CircularProgressIndicator()),
      isEmpty: (users) => users.isEmpty,
      emptyState: const EmptyState(icon: Icons.people_outline, title: 'No users yet'),
      builder: (context, users) {
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
    );
  }
}
