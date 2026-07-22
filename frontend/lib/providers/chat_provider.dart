// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : chat_provider.dart
// Description     : Riverpod providers exposing ChatService and the live unread-message count.
// First Written on: Monday,06-Jul-2026
// Edited on       : Wednesday,15-Jul-2026

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
