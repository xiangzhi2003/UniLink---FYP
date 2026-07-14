import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/chat.dart';

class ChatService {
  // `listings!listing_id(...)` disambiguates which FK to follow — conversations
  // now has two (listing_id, current_listing_id), so a bare `listings(...)`
  // embed is ambiguous to PostgREST and errors on every fetch.
  static const _convoSelect =
      '*, listings!listing_id(title), buyer:profiles!buyer_id(full_name), seller:profiles!seller_id(full_name)';
  // Its own bucket, not `listing-images` — that bucket's storage policies
  // are scoped to listing owners uploading under a `listingId/...` path, so
  // a chat upload path (`conversationId/...`) fails the ownership check and
  // errors out. Chat images need their own bucket/policies instead.
  static const _imageBucket = 'chat-images';

  String get _myId => supabase.auth.currentSession!.user.id;

  /// The existing conversation between me and this other person, if one
  /// already exists — one thread per **pair of people**, covering every
  /// listing either of them has asked the other about (Shopee/Carousell-
  /// style), not one per listing. Symmetric: it doesn't matter which of us
  /// is stored as `buyer_id` vs `seller_id` on the row, or who started it —
  /// if user A messages B about B's listing, and separately B messages A
  /// about A's own listing, both resolve to the *same* conversation instead
  /// of splitting into two. Null if this would be a brand new thread.
  Future<String?> findConversationId({required String sellerId}) async {
    final otherId = sellerId;
    final existing = await supabase
        .from('conversations')
        .select('id')
        .or('and(buyer_id.eq.$_myId,seller_id.eq.$otherId),'
            'and(buyer_id.eq.$otherId,seller_id.eq.$_myId)')
        .maybeSingle();
    return existing?['id'] as String?;
  }

  /// Find the existing conversation with this seller, or create one.
  /// [listingId], if given, is only recorded as the conversation's starting
  /// context (legacy display) — it does not affect which conversation this
  /// resolves to.
  Future<String> getOrCreateConversation({
    required String sellerId,
    String? listingId,
  }) async {
    final existingId = await findConversationId(sellerId: sellerId);
    if (existingId != null) return existingId;

    final row = await supabase
        .from('conversations')
        .insert({
          'buyer_id': _myId,
          'seller_id': sellerId,
          if (listingId != null) 'listing_id': listingId,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Sends a "you're asking about this" product card into the conversation
  /// (Shopee-style: a real message with the listing's photo/title/price,
  /// not just a pinned banner) — skipped if the most recent message is
  /// already a card for the same listing, so re-opening the same product's
  /// chat repeatedly doesn't spam duplicate cards. Switching to a different
  /// listing always sends a new one.
  Future<void> sendProductCard(String conversationId, String listingId) async {
    final last = await supabase
        .from('messages')
        .select('listing_id')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (last != null && last['listing_id'] == listingId) return;

    await supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': _myId,
      'content': '',
      'listing_id': listingId,
    });
  }

  /// My conversations, each enriched with its last message and how many
  /// messages I haven't read yet, newest activity first.
  Future<List<Conversation>> fetchConversations() async {
    final myId = _myId;
    final convoRows = await supabase
        .from('conversations')
        .select(_convoSelect)
        .or('buyer_id.eq.$myId,seller_id.eq.$myId');

    final conversations = <Conversation>[];
    for (final row in convoRows as List<dynamic>) {
      final map = row as Map<String, dynamic>;
      final convoId = map['id'] as String;

      final msgs = await supabase
          .from('messages')
          .select('content, created_at, sender_id, is_read, is_deleted, image_url, listing_id')
          .eq('conversation_id', convoId)
          .order('created_at', ascending: false);

      final msgList = msgs as List<dynamic>;
      final last = msgList.isEmpty ? null : msgList.first as Map<String, dynamic>;
      final unread = msgList
          .where((m) => (m as Map)['sender_id'] != myId && m['is_read'] == false)
          .length;

      final lastPreview = last == null
          ? null
          : (last['is_deleted'] as bool? ?? false)
              ? 'Message deleted'
              : last['listing_id'] != null
                  ? '📦 Asked about a product'
                  : last['image_url'] != null
                      ? '📷 Photo'
                      : last['content'] as String?;

      // Whichever listing was most recently discussed (the newest product
      // card, not necessarily the very last message if you've since typed a
      // plain reply) — shown as the "re:" subtitle so old threads still
      // read as "about" something even after the conversation has moved on.
      final recentListingId = msgList
          .map((m) => (m as Map)['listing_id'] as String?)
          .firstWhere((id) => id != null, orElse: () => null);
      final recentListingTitle = recentListingId == null
          ? null
          : (await fetchListingSummary(recentListingId))?.title;

      conversations.add(Conversation.fromJson(
        map,
        lastMessage: lastPreview,
        lastMessageAt:
            last == null ? null : DateTime.parse(last['created_at'] as String),
        unreadCount: unread,
        recentListingTitle: recentListingTitle,
      ));
    }

    conversations.sort((a, b) {
      final at = a.lastMessageAt;
      final bt = b.lastMessageAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return conversations;
  }

  /// Live stream of a conversation's messages, oldest first — updates in real
  /// time as either side sends (Supabase Realtime).
  ///
  /// `ascending: true` is required explicitly here: unlike the regular query
  /// builder (`.select().order(...)`, which defaults to ascending), the
  /// realtime stream builder's `.order()` defaults to **descending** — left
  /// implicit, this silently rendered the whole thread upside down.
  Stream<List<Message>> messagesStream(String conversationId) {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map(Message.fromJson).toList());
  }

  /// `.stream()` can't express a join, so a product card's listing details
  /// (title/price/photo) are fetched separately when rendering it — cached
  /// here per listing id so re-rendering the same card doesn't re-query.
  final Map<String, ({String title, double price, String? imageUrl})?> _listingSummaryCache = {};

  Future<({String title, double price, String? imageUrl})?> fetchListingSummary(
    String listingId,
  ) async {
    if (_listingSummaryCache.containsKey(listingId)) {
      return _listingSummaryCache[listingId];
    }
    final row = await supabase
        .from('listings')
        .select('title, price, image_urls')
        .eq('id', listingId)
        .maybeSingle();
    if (row == null) {
      _listingSummaryCache[listingId] = null;
      return null;
    }
    final imageUrls = row['image_urls'] as List<dynamic>?;
    final summary = (
      title: row['title'] as String,
      price: (row['price'] as num).toDouble(),
      imageUrl: (imageUrls != null && imageUrls.isNotEmpty) ? imageUrls.first as String : null,
    );
    _listingSummaryCache[listingId] = summary;
    return summary;
  }

  Future<void> sendMessage(String conversationId, String content, {String? imageUrl}) async {
    await supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': _myId,
      'content': content.trim(),
      if (imageUrl != null) 'image_url': imageUrl,
    });
  }

  /// Uploads a chat image to `<conversationId>/<name>` and returns its
  /// public URL — same bucket/pattern as listing photo uploads.
  Future<String> uploadChatImage(String conversationId, XFile image) async {
    final ext = image.name.contains('.') ? image.name.split('.').last : 'jpg';
    final path = '$conversationId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final bytes = await image.readAsBytes();

    await supabase.storage.from(_imageBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: image.mimeType ?? 'image/jpeg'),
        );
    return supabase.storage.from(_imageBucket).getPublicUrl(path);
  }

  /// Deletes the conversation and every message in it. Messages are removed
  /// first in case the DB doesn't cascade-delete on `conversation_id`.
  Future<void> deleteConversation(String conversationId) async {
    await supabase.from('messages').delete().eq('conversation_id', conversationId);
    await supabase.from('conversations').delete().eq('id', conversationId);
  }

  /// Deletes a single message outright (only the sender may delete their
  /// own) — it disappears from both sides' threads via Realtime.
  Future<void> deleteMessage(String messageId) async {
    await supabase.from('messages').delete().eq('id', messageId).eq('sender_id', _myId);
  }

  /// Mark every message the *other* person sent in this conversation as read.
  Future<void> markRead(String conversationId) async {
    await supabase
        .from('messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', _myId)
        .eq('is_read', false);
  }

  /// Total unread messages addressed to me across all conversations — powers
  /// the nav badge. Explicitly scoped to my own conversations (same
  /// `.or(buyer_id.eq...,seller_id.eq...)` pattern as [fetchConversations])
  /// rather than trusting an embed + RLS alone, since that combination was
  /// silently returning nothing (embed relationship not resolving as
  /// expected) despite unread messages genuinely existing.
  Future<int> unreadCount() async {
    final myId = _myId;
    final convoRows = await supabase
        .from('conversations')
        .select('id')
        .or('buyer_id.eq.$myId,seller_id.eq.$myId');
    final convoIds = (convoRows as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)['id'] as String)
        .toList();
    if (convoIds.isEmpty) return 0;

    final rows = await supabase
        .from('messages')
        .select('id')
        .inFilter('conversation_id', convoIds)
        .eq('is_read', false)
        .neq('sender_id', myId);
    return (rows as List<dynamic>).length;
  }

  /// Fires whenever any message row changes — used to refresh the unread badge
  /// live without polling.
  Stream<List<Map<String, dynamic>>> myMessagesStream() {
    return supabase.from('messages').stream(primaryKey: ['id']);
  }
}
