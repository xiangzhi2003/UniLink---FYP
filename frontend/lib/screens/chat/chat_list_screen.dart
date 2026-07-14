import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/chat.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/colored_header.dart';
import '../../widgets/empty_state.dart';
import 'chat_detail_screen.dart';

/// "Chats" tab: all my conversations, most recent first, with unread badges.
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => ChatListScreenState();
}

class ChatListScreenState extends ConsumerState<ChatListScreen> {
  late Future<List<Conversation>> _future;

  /// Optimistically hidden right after a swipe-delete, before the server
  /// round-trip resolves — [Dismissible] removes its widget from view the
  /// instant it's dismissed, but `_future` only reflects that async, so
  /// without this a rebuild in between throws ("dismissed widget still in
  /// tree"). Reverted on failure so the item reappears with an error.
  final _hiddenIds = <String>{};

  @override
  void initState() {
    super.initState();
    _future = ref.read(chatServiceProvider).fetchConversations();
  }

  void reload() {
    // Guard against a stale async callback (e.g. a message-change event, or
    // a delete's own follow-up reload) landing after this screen — e.g. the
    // Chat tab was switched away from — has already been disposed.
    if (!mounted) return;
    setState(() {
      _hiddenIds.clear();
      _future = ref.read(chatServiceProvider).fetchConversations();
    });
  }

  Future<void> _deleteConversation(String conversationId) async {
    if (mounted) setState(() => _hiddenIds.add(conversationId));
    try {
      await ref.read(chatServiceProvider).deleteConversation(conversationId);
      reload();
    } catch (_) {
      if (mounted) {
        setState(() => _hiddenIds.remove(conversationId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete. Try again.')),
        );
      }
    }
  }

  Future<void> _onRefresh() async {
    final future = ref.read(chatServiceProvider).fetchConversations();
    if (mounted) {
      setState(() {
        _future = future;
      });
    }
    await future;
  }

  /// "10:32 AM" for today, "Yesterday", or "M/D/YYYY" for older.
  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    if (date == today) {
      final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final minute = local.minute.toString().padLeft(2, '0');
      final period = local.hour < 12 ? 'AM' : 'PM';
      return '$hour12:$minute $period';
    }
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${local.month}/${local.day}/${local.year}';
  }

  Future<bool> _confirmDelete(BuildContext context, String otherName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text('Your messages with $otherName will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Refresh the list whenever any message changes (live), so previews +
    // unread counts stay current.
    ref.listen(unreadCountProvider, (_, __) => reload());

    final myId = ref.read(authServiceProvider).currentUser?.id;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        ColoredHeader(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Messages',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4),
              FutureBuilder<List<Conversation>>(
                future: _future,
                builder: (context, snapshot) {
                  final count = snapshot.data?.length;
                  if (count == null) return const SizedBox.shrink();
                  return Text(
                    '$count conversation${count == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncStateView<List<Conversation>>(
            future: _future,
            onRetry: reload,
            isEmpty: (data) => data.where((c) => !_hiddenIds.contains(c.id)).isEmpty,
            emptyState: RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                  const EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'No messages yet',
                    message: 'Tap "Message Seller" on a listing to start.',
                  ),
                ],
              ),
            ),
            builder: (context, allConvos) {
              final convos = allConvos.where((c) => !_hiddenIds.contains(c.id)).toList();
              return RefreshIndicator(
                onRefresh: _onRefresh,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                  itemCount: convos.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: scheme.outlineVariant),
                  itemBuilder: (context, index) {
                    final c = convos[index];
                    final other = c.otherPartyName(myId ?? '');
                    return Dismissible(
                      key: ValueKey(c.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDelete(context, other),
                      onDismissed: (_) => _deleteConversation(c.id),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        color: scheme.error,
                        child: Icon(Icons.delete_outline, color: scheme.onError),
                      ),
                      child: InkWell(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatDetailScreen(
                              conversationId: c.id,
                              title: other,
                              otherUserId: c.buyerId == myId ? c.sellerId : c.buyerId,
                            ),
                          ),
                        );
                        reload();
                      },
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: scheme.primary,
                                  child: Text(
                                    other.isNotEmpty
                                        ? other[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(color: scheme.onPrimary),
                                  ),
                                ),
                                if (c.unreadCount > 0)
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      constraints: const BoxConstraints(
                                        minWidth: 20,
                                        minHeight: 20,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: scheme.secondary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: scheme.surface,
                                          width: 2,
                                        ),
                                      ),
                                      child: Text(
                                        '${c.unreadCount}',
                                        style: TextStyle(
                                          color: scheme.onSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          other,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      if (c.lastMessageAt != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatTime(c.lastMessageAt!),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: c.unreadCount > 0
                                                ? scheme.secondary
                                                : scheme.onSurfaceVariant,
                                            fontWeight: c.unreadCount > 0
                                                ? FontWeight.w700
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    c.lastMessage ??
                                        (c.listingTitle != null
                                            ? 'About: ${c.listingTitle}'
                                            : 'New chat'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: c.unreadCount > 0
                                          ? scheme.onSurface
                                          : scheme.onSurfaceVariant,
                                      fontWeight:
                                          c.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                  if (c.recentListingTitle != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      're: ${c.recentListingTitle}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
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
