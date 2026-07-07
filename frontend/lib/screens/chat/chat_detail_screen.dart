import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/chat.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/colored_header.dart';

/// A single conversation, updating live via Supabase Realtime.
class ChatDetailScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String title;

  const ChatDetailScreen({super.key, required this.conversationId, required this.title});

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    // Mark the other person's messages as read when I open the thread.
    ref.read(chatServiceProvider).markRead(widget.conversationId);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await ref.read(chatServiceProvider).sendMessage(widget.conversationId, text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send. Try again.')),
        );
        _controller.text = text;
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottomIfNewMessage(int newCount) {
    if (newCount <= _lastMessageCount) return;
    _lastMessageCount = newCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.read(authServiceProvider).currentUser?.id;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          ColoredHeader(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: Colors.white,
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    widget.title.isNotEmpty ? widget.title[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: ref.read(chatServiceProvider).messagesStream(widget.conversationId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                // New message arrived / opened → mark read + scroll to bottom
                // (only when the message count genuinely increased, so we
                // don't jar the user on every unrelated rebuild).
                ref.read(chatServiceProvider).markRead(widget.conversationId);
                _scrollToBottomIfNewMessage(messages.length);

                if (messages.isEmpty) {
                  return Center(
                    child: Text('Say hello 👋', style: TextStyle(color: scheme.onSurfaceVariant)),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final mine = m.senderId == myId;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.72,
                            ),
                            decoration: BoxDecoration(
                              color: mine ? scheme.primary : scheme.surface,
                              borderRadius: mine
                                  ? const BorderRadius.only(
                                      topLeft: Radius.circular(AppRadius.lg),
                                      topRight: Radius.circular(AppRadius.lg),
                                      bottomLeft: Radius.circular(AppRadius.lg),
                                      bottomRight: Radius.circular(AppRadius.sm),
                                    )
                                  : const BorderRadius.only(
                                      topLeft: Radius.circular(AppRadius.lg),
                                      topRight: Radius.circular(AppRadius.lg),
                                      bottomLeft: Radius.circular(AppRadius.sm),
                                      bottomRight: Radius.circular(AppRadius.lg),
                                    ),
                              border: mine ? null : Border.all(color: scheme.outline),
                            ),
                            child: Text(
                              m.content,
                              style: TextStyle(color: mine ? scheme.onPrimary : scheme.onSurface),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                            child: Text(
                              _formatTimestamp(m.createdAt),
                              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: 'Message...'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.secondary,
                      foregroundColor: scheme.onSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
