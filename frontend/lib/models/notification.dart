// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : notification.dart
// Description     : Data model for an in-app AppNotification shown to a user.
// First Written on: Tuesday,14-Jul-2026
// Edited on       : Tuesday,14-Jul-2026

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? transactionId;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.transactionId,
    this.readAt,
    required this.createdAt,
  });

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      transactionId: json['transaction_id'] as String?,
      readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
