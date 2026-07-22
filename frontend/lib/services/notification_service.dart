// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : notification_service.dart
// Description     : Wraps Supabase queries for fetching and marking read the signed-in user's notifications.
// First Written on: Tuesday,14-Jul-2026
// Edited on       : Tuesday,14-Jul-2026

import '../config/supabase_config.dart';
import '../models/notification.dart';

class NotificationService {
  String get _myId => supabase.auth.currentSession!.user.id;

  /// My notifications, newest first.
  Future<List<AppNotification>> fetchNotifications() async {
    final rows = await supabase
        .from('notifications')
        .select()
        .eq('user_id', _myId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => AppNotification.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String id) async {
    await supabase.from('notifications').update({
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> markAllRead() async {
    await supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', _myId)
        .filter('read_at', 'is', null);
  }

  /// Total unread notifications — powers the Profile nav badge.
  Future<int> unreadCount() async {
    final rows = await supabase
        .from('notifications')
        .select('id')
        .eq('user_id', _myId)
        .filter('read_at', 'is', null);
    return (rows as List<dynamic>).length;
  }

  /// Fires whenever any of my notification rows change — used to refresh the
  /// unread badge live without polling.
  Stream<List<Map<String, dynamic>>> myNotificationsStream() {
    return supabase.from('notifications').stream(primaryKey: ['id']).eq('user_id', _myId);
  }
}
