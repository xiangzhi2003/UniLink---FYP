// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : favorites_screen.dart
// Description     : Grid of the signed-in student's favorited listings.
// First Written on: Monday,13-Jul-2026
// Edited on       : Monday,13-Jul-2026

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/listing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorite_provider.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/listing_card.dart';
import 'listing_detail_screen.dart';

/// The signed-in student's favorited listings.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  late Future<List<Listing>> _listingsFuture;

  @override
  void initState() {
    super.initState();
    _listingsFuture = _fetch();
  }

  Future<List<Listing>> _fetch() {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return Future.value([]);
    return ref.read(favoriteServiceProvider).fetchFavoriteListings(user.id);
  }

  Future<void> _onRefresh() async {
    final future = _fetch();
    setState(() => _listingsFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    // Live-favorited ids, so unfavoriting a card here removes it immediately
    // instead of waiting for a pull-to-refresh.
    final favoriteIds = ref.watch(favoriteIdsProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: AsyncStateView<List<Listing>>(
          future: _listingsFuture,
          loadingSkeleton: const GridSkeleton(crossAxisCount: 2, itemCount: 6),
          isEmpty: (listings) =>
              (favoriteIds == null
                      ? listings
                      : listings.where((l) => favoriteIds.contains(l.id)).toList())
                  .isEmpty,
          emptyState: const EmptyState(
            icon: Icons.favorite_border,
            title: 'No favorites yet',
            message: 'Tap the heart on a listing to save it here.',
          ),
          builder: (context, fetched) {
            final listings = favoriteIds == null
                ? fetched
                : fetched.where((l) => favoriteIds.contains(l.id)).toList();
            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 4
                    : constraints.maxWidth >= 600
                        ? 3
                        : 2;
                return GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
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
            );
          },
        ),
      ),
    );
  }
}
