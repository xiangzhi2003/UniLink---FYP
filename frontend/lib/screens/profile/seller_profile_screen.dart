import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/listing.dart';
import '../../models/review.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/review_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/error_messages.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/colored_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/report_reason_dialog.dart';
import '../../widgets/stamp_mark.dart';
import '../../widgets/star_rating.dart';
import '../marketplace/listing_detail_screen.dart';
import 'reply_to_review_screen.dart';

/// Read-only view of another student's profile: name, university, and their
/// other active listings. No edit/appearance/sign-out actions — those only
/// ever apply to the signed-in user's own [ProfileScreen].
class SellerProfileScreen extends ConsumerStatefulWidget {
  final String sellerId;

  const SellerProfileScreen({super.key, required this.sellerId});

  @override
  ConsumerState<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends ConsumerState<SellerProfileScreen> {
  late Future<List<Listing>> _listingsFuture;
  late Future<List<Review>> _reviewsFuture;
  String? _replyingId; // id of the review currently being replied to, if any

  @override
  void initState() {
    super.initState();
    _listingsFuture = ref.read(listingServiceProvider).fetchListingsBySeller(widget.sellerId);
    _reviewsFuture = ref.read(reviewServiceProvider).fetchReviewsForSeller(widget.sellerId);
  }

  /// "today" / "N days ago" / "N weeks ago" / "N months ago" -- same coarse
  /// granularity as listing_detail_screen.dart's _postedAgo.
  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays <= 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    return '${(diff.inDays / 30).floor()} months ago';
  }

  Future<void> _reply(Review review) async {
    // Pushed as a full screen, not a modal dialog -- an AlertDialog+TextField
    // combo triggered a real freeze/ANR on tapping "Post" here (see
    // reply_to_review_screen.dart's doc comment for details).
    final reply = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ReplyToReviewScreen(initialText: review.sellerReply),
      ),
    );
    if (reply == null || reply.isEmpty || !mounted) return;

    // Disable this review's button instead of stacking a second dialog on
    // top of the first -- rapid nested showDialog/Navigator.pop pairs are a
    // known trigger for a Flutter framework assertion
    // ('_dependents.isEmpty') seen while testing this.
    setState(() => _replyingId = review.id);
    try {
      await ref.read(reviewServiceProvider).replyToReview(reviewId: review.id, reply: reply);
      if (!mounted) return;
      setState(() {
        _replyingId = null;
        _reviewsFuture = ref.read(reviewServiceProvider).fetchReviewsForSeller(widget.sellerId);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _replyingId = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not post reply: $e')));
      }
    }
  }

  Future<void> _reportUser() async {
    final reason = await showReportReasonDialog(context, what: 'user');
    if (reason == null || !mounted) return;
    try {
      await ref
          .read(reportServiceProvider)
          .submitReport(reportedUserId: widget.sellerId, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted — an admin will review it.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileByIdProvider(widget.sellerId));
    final profile = profileAsync.valueOrNull;
    final isOwnProfile =
        ref.read(authServiceProvider).currentUser?.id == widget.sellerId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Profile'),
        actions: [
          if (!isOwnProfile)
            IconButton(
              tooltip: 'Report user',
              icon: const Icon(Icons.flag_outlined),
              onPressed: _reportUser,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredHeader(
              child: Column(
                children: [
                  const StampMark(sealed: true, size: 72),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    profile?.fullName ?? 'Student',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  if (profile?.university != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      profile!.university!,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  FutureBuilder<List<Review>>(
                    future: _reviewsFuture,
                    builder: (context, snapshot) {
                      final reviews = snapshot.data;
                      if (reviews == null) return const SizedBox.shrink();
                      if (reviews.isEmpty) {
                        return const Text(
                          'No reviews yet',
                          style: TextStyle(color: Colors.white70),
                        );
                      }
                      final average =
                          reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StarRating(rating: average.round(), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${average.toStringAsFixed(1)} (${reviews.length} review${reviews.length == 1 ? '' : 's'})',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('ACTIVE LISTINGS', style: Theme.of(context).textTheme.labelLarge),
              ),
            ),
            AsyncStateView<List<Listing>>(
              future: _listingsFuture,
              loadingSkeleton:
                  const GridSkeleton(crossAxisCount: 2, itemCount: 4, shrinkWrap: true),
              isEmpty: (listings) => listings.isEmpty,
              emptyState: const EmptyState(
                icon: Icons.sell_outlined,
                title: 'No active listings',
              ),
              builder: (context, listings) {
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: listings.length,
                  itemBuilder: (context, index) {
                    final listing = listings[index];
                    return ListingCard(
                      listing: listing,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ListingDetailScreen(listing: listing),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('REVIEWS', style: Theme.of(context).textTheme.labelLarge),
              ),
            ),
            AsyncStateView<List<Review>>(
              future: _reviewsFuture,
              // Without this, the default skeleton renders an unbounded
              // ListView inside this screen's SingleChildScrollView and
              // crashes on the very first frame -- same failure mode the
              // GridSkeleton above already guards against with shrinkWrap.
              loadingSkeleton: const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
              isEmpty: (reviews) => reviews.isEmpty,
              emptyState: const EmptyState(
                icon: Icons.star_border,
                title: 'No reviews yet',
              ),
              builder: (context, reviews) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    children: [
                      for (final review in reviews) _reviewTile(context, review),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewTile(BuildContext context, Review review) {
    final scheme = Theme.of(context).colorScheme;
    final myId = ref.read(authServiceProvider).currentUser?.id;
    final isMe = myId != null && myId == review.sellerId;
    final hasReply = review.sellerReply != null && review.sellerReply!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StarRating(rating: review.rating, size: 16),
              const SizedBox(width: 8),
              Text(
                review.reviewerName ?? 'Student',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                _relativeDate(review.createdAt),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(review.comment!),
          ],
          if (hasReply) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              margin: const EdgeInsets.only(left: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.subdirectory_arrow_right, size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        "Seller's reply",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (review.sellerReplyAt != null) ...[
                        const Spacer(),
                        Text(
                          _relativeDate(review.sellerReplyAt!),
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(review.sellerReply!, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
          if (isMe) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: _replyingId == review.id
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton(
                      onPressed: () => _reply(review),
                      child: Text(hasReply ? 'Edit reply' : 'Reply'),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
