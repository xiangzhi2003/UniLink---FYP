// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : notification_provider.dart
// Description     : Riverpod providers exposing NotificationService and the live unread-notification count.
// First Written on: Tuesday,14-Jul-2026
// Edited on       : Wednesday,15-Jul-2026

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());

/// Total unread notifications for the Profile/My Deals nav badges.
/// Recomputed whenever any notification row changes (Supabase Realtime), same
/// pattern as chat's unreadCountProvider.
///
/// Also watches [authStateProvider] so this rebuilds — with a fresh stream
/// scoped to the *current* signed-in user — whenever who's signed in changes
/// (sign out, sign in as someone else). Without this, the underlying
/// Supabase stream's `.eq('user_id', ...)` filter is captured once at
/// subscription time and keeps pointing at whichever user was signed in when
/// the provider first ran, so switching accounts within the same app session
/// (no full restart) would keep showing the previous user's unread state.
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  ref.watch(authStateProvider);
  final svc = ref.watch(notificationServiceProvider);
  return svc.myNotificationsStream().asyncMap((_) => svc.unreadCount());
});
