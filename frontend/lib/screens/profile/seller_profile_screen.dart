import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/listing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/colored_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/stamp_mark.dart';
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

  @override
  void initState() {
    super.initState();
    _listingsFuture = ref.read(listingServiceProvider).fetchListingsBySeller(widget.sellerId);
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
          ],
        ),
      ),
    );
  }
}
