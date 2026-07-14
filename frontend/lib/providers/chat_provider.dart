import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chat_service.dart';
import 'auth_provider.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

/// Total unread messages for the nav badge. Recomputed whenever any message
/// row changes (Supabase Realtime), so the badge stays live without polling.
///
/// Also watches [authStateProvider] so this rebuilds on sign-out/sign-in —
/// same reasoning as unreadNotificationCountProvider.
final unreadCountProvider = StreamProvider<int>((ref) {
  ref.watch(authStateProvider);
  final chat = ref.watch(chatServiceProvider);
  return chat.myMessagesStream().asyncMap((_) => chat.unreadCount());
});
