import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/notification.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/empty_state.dart';
import '../transactions/transaction_detail_screen.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(notificationServiceProvider).fetchNotifications();
  }

  void _reload() {
    setState(() {
      _future = ref.read(notificationServiceProvider).fetchNotifications();
    });
  }

  Future<void> _onRefresh() async {
    final future = ref.read(notificationServiceProvider).fetchNotifications();
    setState(() => _future = future);
    await future;
  }

  Future<void> _markAllRead() async {
    await ref.read(notificationServiceProvider).markAllRead();
    _reload();
  }

  void _open(AppNotification n) {
    if (!n.isUnread) {
      if (n.transactionId != null) _goToDeal(n.transactionId!);
      return;
    }
    // Optimistic: flip it locally so the tap feels instant, fire the write
    // in the background.
    setState(() {
      _future = _future.then((list) => list
          .map((item) => item.id == n.id
              ? AppNotification(
                  id: item.id,
                  type: item.type,
                  title: item.title,
                  body: item.body,
                  transactionId: item.transactionId,
                  readAt: DateTime.now(),
                  createdAt: item.createdAt,
                )
              : item)
          .toList());
    });
    ref.read(notificationServiceProvider).markRead(n.id);
    if (n.transactionId != null) _goToDeal(n.transactionId!);
  }

  void _goToDeal(String transactionId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TransactionDetailScreen(dealId: transactionId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: AsyncStateView<List<AppNotification>>(
        future: _future,
        onRetry: _reload,
        isEmpty: (list) => list.isEmpty,
        emptyState: RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 120),
              EmptyState(
                icon: Icons.notifications_none_outlined,
                title: 'No notifications yet',
                message: "You'll see updates here when something happens with your deals.",
              ),
            ],
          ),
        ),
        builder: (context, notifications) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _NotificationRow(
                notification: notifications[index],
                onTap: () => _open(notifications[index]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationRow({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = notification.isUnread;
    final date = notification.createdAt;
    final formatted = '${date.day}/${date.month}/${date.year}';

    return AppCard(
      onTap: onTap,
      color: unread ? scheme.primary.withValues(alpha: 0.04) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unread) ...[
            Container(
              margin: const EdgeInsets.only(top: 6),
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notification.body,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  formatted,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
