import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/listing.dart';
import '../../models/review.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../providers/review_provider.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/colored_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/stamp_mark.dart';
import '../../widgets/star_rating.dart';
import '../marketplace/listing_detail_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileByIdProvider(widget.sellerId));
    final profile = profileAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Seller Profile')),
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
        ],
      ),
    );
  }
}
