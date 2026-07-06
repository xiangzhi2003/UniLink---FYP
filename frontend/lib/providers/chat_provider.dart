import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chat_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

/// Total unread messages for the nav badge. Recomputed whenever any message
/// row changes (Supabase Realtime), so the badge stays live without polling.
final unreadCountProvider = StreamProvider<int>((ref) {
  final chat = ref.watch(chatServiceProvider);
  return chat.myMessagesStream().asyncMap((_) => chat.unreadCount());
});
