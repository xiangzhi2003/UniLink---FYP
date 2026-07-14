import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/chat.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/listing_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/error_messages.dart';
import '../../widgets/colored_header.dart';
import '../marketplace/fullscreen_image_viewer.dart';
import '../marketplace/listing_detail_screen.dart';
import '../profile/seller_profile_screen.dart';

/// A single conversation with a seller (Carousell/Shopee-style: one thread
/// per seller, covering every listing of theirs — never per listing), updating
/// live via Supabase Realtime.
///
/// Pass either [conversationId] (an existing thread) or [listingId] +
/// [sellerId] (opened from "Message Seller" before it's known whether a
/// conversation exists). In the latter case, nothing is written to the
/// database until the first message is actually sent — opening the screen
/// and backing out without typing anything leaves no trace, and tapping
/// "Message Seller" twice in a row can't create two conversations for the
/// same pair.
class ChatDetailScreen extends ConsumerStatefulWidget {
  final String? conversationId;
  final String? listingId;
  final String? sellerId;
  final String title;

  /// The other party's user id — tapping their name/avatar in the header
  /// opens their (read-only) profile.
  final String otherUserId;

  const ChatDetailScreen({
    super.key,
    this.conversationId,
    this.listingId,
    this.sellerId,
    required this.title,
    required this.otherUserId,
  }) : assert(conversationId != null || (listingId != null && sellerId != null));

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  // A ValueNotifier instead of setState()-driven state: sending/receiving a
  // message shouldn't rebuild the entire screen (including the whole message
  // list re-laying-out) just to grey out the send button for a moment — that
  // full-screen rebuild was the cause of a visible flicker on every send.
  // Only the input row listens to this now.
  final _sendingNotifier = ValueNotifier<bool>(false);
  int _lastMessageCount = 0;
  String? _conversationId;

  /// Caches each product card's summary `Future` per listing id. Without
  /// this, `_buildProductCard` would call `fetchListingSummary()` fresh on
  /// every `build()` — even though the service itself caches the result and
  /// returns instantly, handing `FutureBuilder` a brand-new `Future` object
  /// resets it to its loading state for a frame regardless, which is what
  /// caused product cards to visibly flash back to their spinner on every
  /// rebuild (e.g. the keyboard opening/closing changes `MediaQuery`, which
  /// this screen depends on, and rebuilds the whole message list).
  final Map<String, Future<({String title, double price, String? imageUrl})?>>
      _listingSummaryFutures = {};

  Future<({String title, double price, String? imageUrl})?> _listingSummaryFuture(
    String listingId,
  ) {
    return _listingSummaryFutures.putIfAbsent(
      listingId,
      () => ref.read(chatServiceProvider).fetchListingSummary(listingId),
    );
  }

  /// Created once (not fresh every `build()`, which reopened a new Realtime
  /// subscription each time and could double-render a just-sent row) and
  /// reused across rebuilds until the conversation is actually created, at
  /// which point it's set for the first time.
  Stream<List<Message>>? _messagesStream;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    if (_conversationId != null) {
      _messagesStream = ref.read(chatServiceProvider).messagesStream(_conversationId!);
      // Mark the other person's messages as read when I open the thread.
      ref.read(chatServiceProvider).markRead(_conversationId!);
    }
  }

  /// Finds/creates the conversation the moment it's actually needed (i.e.
  /// the user is sending something), not before.
  Future<String> _ensureConversation() async {
    if (_conversationId != null) return _conversationId!;

    final id = await ref.read(chatServiceProvider).getOrCreateConversation(
          sellerId: widget.sellerId!,
          listingId: widget.listingId,
        );
    if (mounted) {
      setState(() {
        _conversationId = id;
        _messagesStream = ref.read(chatServiceProvider).messagesStream(id);
      });
    }
    return id;
  }

  Future<void> _send() async {
    if (_sendingNotifier.value) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _sendingNotifier.value = true;
    _controller.clear();
    try {
      final conversationId = await _ensureConversation();
      await ref.read(chatServiceProvider).sendMessage(conversationId, text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send. Try again.')),
        );
        _controller.text = text;
      }
    } finally {
      _sendingNotifier.value = false;
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_sendingNotifier.value) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (file == null) return;

    final caption = _controller.text.trim();
    _sendingNotifier.value = true;
    _controller.clear();
    try {
      final conversationId = await _ensureConversation();
      final imageUrl = await ref.read(chatServiceProvider).uploadChatImage(conversationId, file);
      await ref
          .read(chatServiceProvider)
          .sendMessage(conversationId, caption, imageUrl: imageUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
    } finally {
      _sendingNotifier.value = false;
    }
  }

  Future<void> _openListing(String listingId) async {
    try {
      final listings = await ref.read(listingServiceProvider).fetchListingsByIds([listingId]);
      if (!mounted) return;
      if (listings.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This listing is no longer available.')),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: listings.first)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This message will be removed for everyone.'),
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
    if (confirmed != true) return;

    try {
      await ref.read(chatServiceProvider).deleteMessage(messageId);
      // Force a fresh fetch instead of waiting on the realtime DELETE event —
      // Supabase can only re-check a DELETE-targeting RLS policy over
      // realtime if the table's replica identity includes the columns that
      // policy needs, so this doesn't only rely on that being configured.
      if (mounted) {
        setState(() {
          _messagesStream = ref.read(chatServiceProvider).messagesStream(_conversationId!);
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete. Try again.')),
        );
      }
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

  /// 12-hour clock, e.g. "9:14 AM" — the date itself is shown by the day
  /// divider above, not repeated on every bubble.
  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "Today" / "Yesterday" / "Mar 5, 2026" for a day divider between groups
  /// of messages.
  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return 'Today';
    if (day == yesterday) return 'Yesterday';
    return '${_months[day.month - 1]} ${day.day}, ${day.year}';
  }

  /// "You're asking about this" product card (Shopee-style): a real message
  /// bubble showing the listing's photo/title/price, aligned like whichever
  /// side sent it — not a floating system element, so it reads as a natural
  /// part of the conversation instead of an unrelated overlay.
  Widget _buildProductCard(BuildContext context, ColorScheme scheme, Message m, bool mine) {
    return FutureBuilder<({String title, double price, String? imageUrl})?>(
      future: _listingSummaryFuture(m.listingId!),
      builder: (context, snapshot) {
        final summary = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 76,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (summary == null) {
          return Text(
            'Listing no longer available',
            style: TextStyle(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic),
          );
        }

        return InkWell(
          onTap: () => _openListing(m.listingId!),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: summary.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: summary.imageUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        color: mine
                            ? scheme.onPrimary.withValues(alpha: 0.15)
                            : scheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.image_outlined,
                          color: mine ? scheme.onPrimary : scheme.onSurfaceVariant,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Asking about',
                      style: TextStyle(
                        fontSize: 11,
                        color: mine ? scheme.onPrimary.withValues(alpha: 0.75) : scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      summary.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: mine ? scheme.onPrimary : scheme.onSurface,
                      ),
                    ),
                    Text(
                      'RM ${summary.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: mine ? scheme.onPrimary : scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _sendingNotifier.dispose();
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
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SellerProfileScreen(sellerId: widget.otherUserId),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
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
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _messagesStream == null
                ? Center(
                    child: Text('Say hello 👋', style: TextStyle(color: scheme.onSurfaceVariant)),
                  )
                : StreamBuilder<List<Message>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Defensive de-dupe by id, in case a stream re-subscription
                // window ever delivers the same row twice — keeps the list
                // correct regardless of the underlying cause.
                final seen = <String>{};
                final messages = [
                  for (final m in snapshot.data!)
                    if (seen.add(m.id)) m,
                ];
                // New message arrived / opened → mark read + scroll to bottom.
                // Gated on the count actually growing — `build()` (and this
                // StreamBuilder along with it) also reruns for unrelated
                // reasons (e.g. `_sending` toggling around a send), and
                // firing a markRead network call on every one of those was
                // adding visible jank right when a message was sent.
                final hasNewMessages = messages.length > _lastMessageCount;
                if (hasNewMessages) {
                  ref.read(chatServiceProvider).markRead(_conversationId!);
                }
                _scrollToBottomIfNewMessage(messages.length);

                if (messages.isEmpty) {
                  return Center(
                    child: Text('Say hello 👋', style: TextStyle(color: scheme.onSurfaceVariant)),
                  );
                }

                // Flatten into a single list of day-divider + message items
                // so the ListView can render both in one pass.
                final items = <_ChatRow>[];
                DateTime? lastDay;
                for (final m in messages) {
                  final local = m.createdAt.toLocal();
                  final day = DateTime(local.year, local.month, local.day);
                  if (lastDay == null || day != lastDay) {
                    items.add(_ChatRow.divider(day));
                    lastDay = day;
                  }
                  items.add(_ChatRow.message(m));
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final row = items[index];
                    if (row.day != null) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              _dayLabel(row.day!),
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                      );
                    }

                    final m = row.message!;
                    final mine = m.senderId == myId;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onLongPress: mine ? () => _deleteMessage(m.id) : null,
                            child: Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: m.imageUrl != null
                                  ? const EdgeInsets.all(4)
                                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                                border: !mine ? Border.all(color: scheme.outline) : null,
                              ),
                              child: m.isProductCard
                                  ? _buildProductCard(context, scheme, m, mine)
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (m.imageUrl != null)
                                          GestureDetector(
                                            onTap: () => Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => FullscreenImageViewer(
                                                  imageUrls: [m.imageUrl!],
                                                ),
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(AppRadius.md),
                                              child: CachedNetworkImage(
                                                imageUrl: m.imageUrl!,
                                                fit: BoxFit.cover,
                                                width: 220,
                                                height: 220,
                                                placeholder: (_, __) => const SizedBox(
                                                  width: 220,
                                                  height: 220,
                                                  child: Center(child: CircularProgressIndicator()),
                                                ),
                                                errorWidget: (_, __, ___) => const SizedBox(
                                                  width: 220,
                                                  height: 220,
                                                  child: Icon(Icons.broken_image_outlined),
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (m.content.isNotEmpty)
                                          Padding(
                                            padding: m.imageUrl != null
                                                ? const EdgeInsets.fromLTRB(8, 6, 8, 2)
                                                : EdgeInsets.zero,
                                            child: Text(
                                              m.content,
                                              style: TextStyle(
                                                color: mine ? scheme.onPrimary : scheme.onSurface,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
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
              child: ValueListenableBuilder<bool>(
                valueListenable: _sendingNotifier,
                builder: (context, sending, _) => Row(
                  children: [
                    IconButton(
                      tooltip: 'Send a photo',
                      onPressed: sending ? null : _pickAndSendImage,
                      icon: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
                    ),
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
                      onPressed: sending ? null : _send,
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
          ),
        ],
      ),
    );
  }
}

/// One row in the message list: either a day divider or a message bubble.
class _ChatRow {
  final DateTime? day;
  final Message? message;

  const _ChatRow._({this.day, this.message});

  factory _ChatRow.divider(DateTime day) => _ChatRow._(day: day);
  factory _ChatRow.message(Message message) => _ChatRow._(message: message);
}
