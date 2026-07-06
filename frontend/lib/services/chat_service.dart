import '../config/supabase_config.dart';
import '../models/chat.dart';

class ChatService {
  static const _convoSelect =
      '*, listings(title), buyer:profiles!buyer_id(full_name), seller:profiles!seller_id(full_name)';

  String get _myId => supabase.auth.currentSession!.user.id;

  /// Find the existing conversation for this listing between me (buyer) and
  /// the seller, or create one. Returns the conversation id.
  Future<String> getOrCreateConversation({
    required String listingId,
    required String sellerId,
  }) async {
    final existing = await supabase
        .from('conversations')
        .select('id')
        .eq('listing_id', listingId)
        .eq('buyer_id', _myId)
        .eq('seller_id', sellerId)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final row = await supabase
        .from('conversations')
        .insert({'listing_id': listingId, 'buyer_id': _myId, 'seller_id': sellerId})
        .select('id')
        .single();
    return row['id'] as String;
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
          .select('content, created_at, sender_id, is_read')
          .eq('conversation_id', convoId)
          .order('created_at', ascending: false);

      final msgList = msgs as List<dynamic>;
      final last = msgList.isEmpty ? null : msgList.first as Map<String, dynamic>;
      final unread = msgList
          .where((m) => (m as Map)['sender_id'] != myId && m['is_read'] == false)
          .length;

      conversations.add(Conversation.fromJson(
        map,
        lastMessage: last?['content'] as String?,
        lastMessageAt:
            last == null ? null : DateTime.parse(last['created_at'] as String),
        unreadCount: unread,
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
  Stream<List<Message>> messagesStream(String conversationId) {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) => rows.map(Message.fromJson).toList());
  }

  Future<void> sendMessage(String conversationId, String content) async {
    await supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': _myId,
      'content': content.trim(),
    });
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
  /// the nav badge.
  Future<int> unreadCount() async {
    final myId = _myId;
    final rows = await supabase
        .from('messages')
        .select('id, sender_id, is_read, conversations!inner(buyer_id, seller_id)')
        .eq('is_read', false)
        .neq('sender_id', myId);
    // RLS already limits this to my conversations, so every row here is one I
    // can see and didn't send.
    return (rows as List<dynamic>).length;
  }

  /// Fires whenever any message row changes — used to refresh the unread badge
  /// live without polling.
  Stream<List<Map<String, dynamic>>> myMessagesStream() {
    return supabase.from('messages').stream(primaryKey: ['id']);
  }
}
