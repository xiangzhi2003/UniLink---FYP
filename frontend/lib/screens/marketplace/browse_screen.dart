// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : browse_screen.dart
// Description     : Marketplace browse grid with category filters and semantic + keyword search.
// First Written on: Sunday,05-Jul-2026
// Edited on       : Thursday,16-Jul-2026

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

/// Marketplace home: category tabs + a blended search (AI semantic search
/// via Pinecone, merged with a plain Supabase ilike keyword search) over a
/// responsive grid of active listings. Blending covers both directions: a
/// meaning-based query keyword search would miss, and a keyword match
/// semantic search's relevance threshold might filter out on a small
/// catalog. If semantic search fails outright, keyword results alone still
/// carry the screen.
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

  /// Home is a discovery feed of *other* students' listings — the signed-in
  /// user's own listings live in their dedicated "My Listings" tab instead,
  /// so they're filtered out here rather than shown in a separate section.
  Future<List<Listing>> _fetch() async {
    final listingService = ref.read(listingServiceProvider);
    final category = _selectedTab == 'All' ? null : _selectedTab;
    final listingType = _typeTabs[_selectedTypeTab];
    final myId = ref.read(authServiceProvider).currentUser?.id;
    final query = _query.trim();

    final keywordFuture = listingService.fetchActiveListings(
      category: category,
      query: _query,
      listingType: listingType,
    );

    if (query.isEmpty) {
      final results = await keywordFuture;
      return results.where((l) => l.sellerId != myId).toList();
    }

    // Blend both sources instead of an all-or-nothing fallback: semantic
    // search catches meaning-based matches keyword search would miss (and
    // vice versa on a small catalog where the relevance threshold can leave
    // it with nothing), so run them in parallel and merge, semantic first
    // since it's ranked by relevance.
    final semanticFuture = _semanticSearch(query, category, listingType);
    final combined = await Future.wait([semanticFuture, keywordFuture]);
    final semanticResults = combined[0];
    final keywordResults = combined[1];

    final seenIds = <String>{};
    final merged = <Listing>[];
    for (final listing in [...semanticResults, ...keywordResults]) {
      if (listing.sellerId == myId) continue;
      final id = listing.id;
      if (id != null && !seenIds.add(id)) continue;
      merged.add(listing);
    }
    return merged;
  }

  Future<List<Listing>> _semanticSearch(
    String query,
    String? category,
    String? listingType,
  ) async {
    try {
      final ids = await ref.read(backendServiceProvider).semanticSearchListings(query);
      if (ids.isEmpty) return [];
      final results = await ref.read(listingServiceProvider).fetchListingsByIds(ids);
      return results.where((l) {
        if (category != null && l.category != category) return false;
        if (listingType != null && l.listingType != listingType) return false;
        return true;
      }).toList();
    } catch (_) {
      // Semantic search unavailable — keyword results alone still work.
      return [];
    }
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
                          tooltip:
                              'This search understands natural language, powered by AI',
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
          height: 30,
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
        Expanded(
          child: Transform.translate(
            offset: const Offset(0, -15),
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

                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 1, 16, 96),
                        children: [_buildGrid(listings, columns)],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ],
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
