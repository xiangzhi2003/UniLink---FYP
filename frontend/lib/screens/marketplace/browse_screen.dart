import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/listing.dart';
import '../../providers/listing_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../widgets/listing_card.dart';
import 'listing_detail_screen.dart';

/// Marketplace home: category tabs + keyword search over a responsive grid
/// of active listings. The keyword search is the temporary fallback until
/// Sprint 3C's RAG search replaces it.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => BrowseScreenState();
}

class BrowseScreenState extends ConsumerState<BrowseScreen> {
  static const _tabs = ['All', ...Listing.categories];

  final _searchController = TextEditingController();
  String _selectedTab = 'All';
  String _query = '';

  late Future<List<Listing>> _listingsFuture;

  @override
  void initState() {
    super.initState();
    _listingsFuture = _fetch();
  }

  Future<List<Listing>> _fetch() {
    return ref.read(listingServiceProvider).fetchActiveListings(
          category: _selectedTab == 'All' ? null : _selectedTab,
          query: _query,
        );
  }

  /// Also called by HomeShell after a new listing is published so the grid
  /// shows it without a manual pull-to-refresh.
  void reload() {
    setState(() {
      _listingsFuture = _fetch();
    });
  }

  Future<void> _onRefresh() async {
    final future = _fetch();
    setState(() {
      _listingsFuture = future;
    });
    await future;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search textbooks, calculators...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                          _listingsFuture = _fetch();
                        });
                      },
                    ),
            ),
            onSubmitted: (value) {
              setState(() {
                _query = value;
                _listingsFuture = _fetch();
              });
            },
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              for (final tab in _tabs)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tab),
                    selected: _selectedTab == tab,
                    selectedColor: AppColors.ink,
                    labelStyle: TextStyle(
                      color: _selectedTab == tab ? Colors.white : AppColors.ink,
                      fontSize: 13,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedTab = tab;
                        _listingsFuture = _fetch();
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Listing>>(
            future: _listingsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      friendlyErrorMessage(snapshot.error!),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final listings = snapshot.data ?? [];
              if (listings.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 120),
                      const Icon(Icons.storefront_outlined, size: 56, color: AppColors.slate),
                      const SizedBox(height: 12),
                      Text(
                        _query.isEmpty
                            ? 'No listings yet — be the first to sell something!'
                            : 'No results for "$_query"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.slate),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _onRefresh,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900
                        ? 4
                        : constraints.maxWidth >= 600
                            ? 3
                            : 2;
                    return GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.72,
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
              );
            },
          ),
        ),
      ],
    );
  }
}
