import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/chat.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
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

    return FutureBuilder<List<Conversation>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(friendlyErrorMessage(snapshot.error!), textAlign: TextAlign.center),
            ),
          );
        }

        final convos = snapshot.data ?? [];
        if (convos.isEmpty) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Icon(Icons.forum_outlined, size: 56, color: AppColors.slate),
                SizedBox(height: 12),
                Text(
                  'No messages yet.\nTap "Message Seller" on a listing to start.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.slate),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
            itemCount: convos.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
            itemBuilder: (context, index) {
              final c = convos[index];
              final other = c.otherPartyName(myId ?? '');
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.ink,
                  child: Text(
                    other.isNotEmpty ? other[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(other, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  c.lastMessage ?? (c.listingTitle != null ? 'About: ${c.listingTitle}' : 'New chat'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: c.unreadCount > 0
                    ? Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                        child: Text(
                          '${c.unreadCount}',
                          style: const TextStyle(
                            color: AppColors.inkDeep,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : null,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatDetailScreen(conversationId: c.id, title: other),
                    ),
                  );
                  reload();
                },
              );
            },
          ),
        );
      },
    );
  }
}
