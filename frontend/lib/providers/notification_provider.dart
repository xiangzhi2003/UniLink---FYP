import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());

/// Total unread notifications for the Profile nav badge. Recomputed whenever
/// any notification row changes (Supabase Realtime), same pattern as chat's
/// unreadCountProvider.
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final svc = ref.watch(notificationServiceProvider);
  return svc.myNotificationsStream().asyncMap((_) => svc.unreadCount());
});
