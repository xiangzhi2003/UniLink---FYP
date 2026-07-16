class Review {
  final String id;
  final String transactionId;
  final String listingId;
  final String reviewerId;
  final String sellerId;
  final int rating; // 1-5
  final String? comment;
  final DateTime createdAt;

  // Joined display field (not a column on reviews):
  final String? reviewerName;

  const Review({
    required this.id,
    required this.transactionId,
    required this.listingId,
    required this.reviewerId,
    required this.sellerId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.reviewerName,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    final reviewer = json['reviewer'] as Map<String, dynamic>?;
    return Review(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String,
      listingId: json['listing_id'] as String,
      reviewerId: json['reviewer_id'] as String,
      sellerId: json['seller_id'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      reviewerName: reviewer?['full_name'] as String?,
    );
  }
}
