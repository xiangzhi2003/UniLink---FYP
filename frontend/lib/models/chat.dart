// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : chat.dart
// Description     : Data models for a chat Conversation and its Messages, including joined display fields like participant names and listing titles.
// First Written on: Monday,06-Jul-2026
// Edited on       : Tuesday,14-Jul-2026

class Conversation {
  final String id;
  final String? listingId;
  final String buyerId;
  final String sellerId;

  // Joined / derived display fields:
  final String? listingTitle;
  final String? buyerName;
  final String? sellerName;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  /// The most recently discussed listing's title (the newest product card,
  /// not necessarily [listingTitle] which is just the one that started the
  /// conversation) — shown as the "re: ..." subtitle in the chat list.
  final String? recentListingTitle;

  const Conversation({
    required this.id,
    this.listingId,
    required this.buyerId,
    required this.sellerId,
    this.listingTitle,
    this.buyerName,
    this.sellerName,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.recentListingTitle,
  });

  String otherPartyName(String myId) {
    final iAmBuyer = buyerId == myId;
    return (iAmBuyer ? sellerName : buyerName) ?? 'Student';
  }

  factory Conversation.fromJson(
    Map<String, dynamic> json, {
    String? lastMessage,
    DateTime? lastMessageAt,
    int unreadCount = 0,
    String? recentListingTitle,
  }) {
    final listing = json['listings'] as Map<String, dynamic>?;
    final buyer = json['buyer'] as Map<String, dynamic>?;
    final seller = json['seller'] as Map<String, dynamic>?;
    return Conversation(
      id: json['id'] as String,
      listingId: json['listing_id'] as String?,
      buyerId: json['buyer_id'] as String,
      sellerId: json['seller_id'] as String,
      listingTitle: listing?['title'] as String?,
      buyerName: buyer?['full_name'] as String?,
      sellerName: seller?['full_name'] as String?,
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      unreadCount: unreadCount,
      recentListingTitle: recentListingTitle,
    );
  }
}

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime createdAt;
  final bool isDeleted;
  final String? imageUrl;

  /// Set when this message is a "you're asking about this" product card
  /// (auto-sent when opening a chat from a listing) rather than an ordinary
  /// text/image message. The card's title/price/photo are fetched
  /// separately (`ChatService.fetchListingSummary`) when rendering it.
  final String? listingId;

  bool get isProductCard => listingId != null;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.isRead,
    required this.createdAt,
    this.isDeleted = false,
    this.imageUrl,
    this.listingId,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
      imageUrl: json['image_url'] as String?,
      listingId: json['listing_id'] as String?,
    );
  }
}
