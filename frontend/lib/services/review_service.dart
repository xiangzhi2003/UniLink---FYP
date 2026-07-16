import '../config/supabase_config.dart';
import '../models/review.dart';

/// Plain CRUD over the `reviews` table -- no backend involvement needed
/// (no AI, no money, no QR security), same as listings/chat/profiles.
/// Postgres RLS enforces that only the buyer on a completed transaction can
/// insert, once per transaction (see the `reviews` table policies).
class ReviewService {
  static const _select = '*, reviewer:profiles!reviewer_id(full_name)';

  Future<void> submitReview({
    required String transactionId,
    required String listingId,
    required String sellerId,
    required int rating,
    String? comment,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('reviews').insert({
      'transaction_id': transactionId,
      'listing_id': listingId,
      'reviewer_id': userId,
      'seller_id': sellerId,
      'rating': rating,
      'comment': comment != null && comment.trim().isNotEmpty ? comment.trim() : null,
    });
  }

  /// A seller's reviews, most recent first. Average rating and count are
  /// derived from this list client-side rather than a separate query.
  Future<List<Review>> fetchReviewsForSeller(String sellerId) async {
    final rows = await supabase
        .from('reviews')
        .select(_select)
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => Review.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Whether the current user has already reviewed this transaction --
  /// gates the "Leave a Review" CTA.
  Future<bool> hasReviewed(String transactionId) async {
    final rows = await supabase
        .from('reviews')
        .select('id')
        .eq('transaction_id', transactionId)
        .limit(1);
    return (rows as List<dynamic>).isNotEmpty;
  }
}
