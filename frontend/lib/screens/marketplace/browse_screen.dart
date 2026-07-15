import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/listing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/listing_provider.dart';
import '../../providers/transaction_provider.dart' show backendServiceProvider;
import '../../theme/app_tokens.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/colored_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/listing_card.dart';
import 'listing_detail_screen.dart';

/// Marketplace home: category tabs + AI-powered semantic search (Pinecone,
/// via the backend's /search/query) over a responsive grid of active
/// listings. Falls back to a plain Supabase ilike keyword search if the
/// semantic search request fails or returns nothing, so the search bar
/// never visibly breaks.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => BrowseScreenState();
}

class BrowseScreenState extends ConsumerState<BrowseScreen> {
  static const _tabs = ['All', ...Listing.categories];
  static const _debounceDuration = Duration(milliseconds: 350);

  static const _typeTabs = {
    'All': null,
    'For Sale': 'sale',
    'For Rent': 'rent',
  };

  final _searchController = TextEditingController();
  String _selectedTab = 'All';
  String _selectedTypeTab = 'All';
  String _query = '';
  Timer? _debounce;

  late Future<List<Listing>> _listingsFuture;

  @override
  void initState() {
    super.initState();
    _listingsFuture = _fetch();
  }

  Future<List<Listing>> _fetch() async {
    final listingService = ref.read(listingServiceProvider);
    final category = _selectedTab == 'All' ? null : _selectedTab;
    final listingType = _typeTabs[_selectedTypeTab];

    if (_query.trim().isNotEmpty) {
      try {
        final ids = await ref.read(backendServiceProvider).semanticSearchListings(_query);
        if (ids.isNotEmpty) {
          final results = await listingService.fetchListingsByIds(ids);
          return results.where((l) {
            if (category != null && l.category != category) return false;
            if (listingType != null && l.listingType != listingType) return false;
            return true;
          }).toList();
        }
      } catch (_) {
        // Semantic search unavailable — fall through to the keyword search
        // below so the search bar never visibly breaks.
      }
    }

    return listingService.fetchActiveListings(
      category: category,
      query: _query,
      listingType: listingType,
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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      setState(() {
        _query = value;
        _listingsFuture = _fetch();
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        ColoredHeader(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.headerTop,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What are you looking for?',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: Color(0xFF1E1245)),
                  decoration: InputDecoration(
                    hintText: 'Search textbooks, calculators...',
                    hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF6B7280),
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_query.isNotEmpty)
                          IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(
                              Icons.close,
                              color: Color(0xFF6B7280),
                            ),
                            onPressed: () {
                              _debounce?.cancel();
                              _searchController.clear();
                              setState(() {
                                _query = '';
                                _listingsFuture = _fetch();
                              });
                            },
                          ),
                        IconButton(
                          tooltip: 'This search understands natural language, powered by AI',
                          icon: Icon(Icons.auto_awesome, color: scheme.primary),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Try describing what you need in your own words — search understands meaning, not just keywords',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: (value) {
                    _debounce?.cancel();
                    setState(() {
                      _query = value;
                      _listingsFuture = _fetch();
                    });
                  },
                ),
              ),
            ],
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
                    selectedColor: scheme.primary,
                    labelStyle: TextStyle(
                      color:
                          _selectedTab == tab
                              ? scheme.onPrimary
                              : scheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
        SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                for (final tab in _typeTabs.keys)
                  Padding(
                    padding: const EdgeInsets.only(right: 25),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedTypeTab = tab;
                          _listingsFuture = _fetch();
                        });
                      },
                      child: Text(
                        tab,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              _selectedTypeTab == tab
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                          fontWeight:
                              _selectedTypeTab == tab
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: AsyncStateView<List<Listing>>(
              future: _listingsFuture,
              loadingSkeleton: const GridSkeleton(
                crossAxisCount: 2,
                itemCount: 6,
              ),
              isEmpty: (listings) => listings.isEmpty,
              emptyState: EmptyState(
                icon: Icons.storefront_outlined,
                title: _query.isEmpty ? 'No listings yet' : 'No results',
                message:
                    _query.isEmpty
                        ? 'Be the first to sell something!'
                        : 'No results for "$_query"',
              ),
              builder: (context, listings) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        constraints.maxWidth >= 900
                            ? 4
                            : constraints.maxWidth >= 600
                            ? 3
                            : 2;
                    final myId = ref.read(authServiceProvider).currentUser?.id;
                    final mine =
                        listings.where((l) => l.sellerId == myId).toList();
                    final others =
                        listings.where((l) => l.sellerId != myId).toList();

                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      children: [
                        if (mine.isNotEmpty) ...[
                          _sectionHeader(context, 'Your Listings', mine.length),
                          Transform.translate(
                            offset: const Offset(0, -20),
                            child: _buildGrid(mine, columns),
                          ),
                        ],
                        if (others.isNotEmpty) ...[
                          _sectionHeader(
                            context,
                            'Other Listings',
                            others.length,
                          ),
                          Transform.translate(
                            offset: const Offset(0, -20),
                            child: _buildGrid(others, columns),
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String label, int count) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 5, 4, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1,
              leadingDistribution: TextLeadingDistribution.even,
            ),
          ),
          Text(
            '$count item${count == 1 ? '' : 's'}',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
              height: 1,
              leadingDistribution: TextLeadingDistribution.even,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<Listing> listings, int columns) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.72,
      ),
      itemCount: listings.length,
      itemBuilder: (context, index) {
        final listing = listings[index];
        return ListingCard(
          listing: listing,
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ListingDetailScreen(listing: listing),
                ),
              ),
        );
      },
    );
  }
}
