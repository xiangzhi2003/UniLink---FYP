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

  @override
  void initState() {
    super.initState();
    _future = ref.read(chatServiceProvider).fetchConversations();
  }

  void reload() {
    setState(() {
      _future = ref.read(chatServiceProvider).fetchConversations();
    });
  }

  Future<void> _onRefresh() async {
    final future = ref.read(chatServiceProvider).fetchConversations();
    setState(() {
      _future = future;
    });
    await future;
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Messages',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: Colors.white),
              ),
              const SizedBox(width: 10),
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
            isEmpty: (data) => data.isEmpty,
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
            builder: (context, convos) {
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
                    return InkWell(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatDetailScreen(
                              conversationId: c.id,
                              title: other,
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
                                  Text(
                                    other,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
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
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
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
