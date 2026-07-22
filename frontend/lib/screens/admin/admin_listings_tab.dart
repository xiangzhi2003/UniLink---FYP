// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : admin_listings_tab.dart
// Description     : Admin tab for moderating all marketplace listings (view/filter/remove).
// First Written on: Friday,17-Jul-2026
// Edited on       : Friday,17-Jul-2026

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/listing.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/error_messages.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';
import '../marketplace/listing_detail_screen.dart';

const _statusFilters = ['All', 'active', 'sold', 'rented', 'unavailable'];

/// Moderation view: every listing on the marketplace, any status, tappable
/// through to the real ListingDetailScreen (opened read-only -- adminView:
/// true hides Buy/Message/Ask AI/Report, admins only moderate) plus a
/// remove action. Removal deletes the row AND its Pinecone vector
/// server-side in one call.
class AdminListingsTab extends ConsumerStatefulWidget {
  const AdminListingsTab({super.key});

  @override
  ConsumerState<AdminListingsTab> createState() => _AdminListingsTabState();
}

class _AdminListingsTabState extends ConsumerState<AdminListingsTab> {
  late Future<List<Listing>> _future;
  bool _busy = false;
  bool _showFilters = false;
  String _query = '';
  String _statusFilter = 'All';
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = ref.read(backendServiceProvider).fetchAdminListings();
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = ref.read(backendServiceProvider).fetchAdminListings();
    });
  }

  Future<void> _remove(Listing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove listing?'),
        content: Text(
          '"${listing.title}" will be permanently removed from the '
          'marketplace. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(backendServiceProvider).adminRemoveListing(listing.id!);
      if (mounted) _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _hasActiveFilters =>
      _statusFilter != 'All' ||
      _minPriceController.text.isNotEmpty ||
      _maxPriceController.text.isNotEmpty;

  void _clearFilters() {
    setState(() {
      _statusFilter = 'All';
      _minPriceController.clear();
      _maxPriceController.clear();
    });
  }

  List<Listing> _filter(List<Listing> listings) {
    final q = _query.trim().toLowerCase();
    final min = double.tryParse(_minPriceController.text.trim());
    final max = double.tryParse(_maxPriceController.text.trim());

    return listings.where((l) {
      if (q.isNotEmpty) {
        final matches = l.title.toLowerCase().contains(q) ||
            (l.sellerName ?? '').toLowerCase().contains(q) ||
            l.category.toLowerCase().contains(q);
        if (!matches) return false;
      }
      if (_statusFilter != 'All' && l.status != _statusFilter) return false;
      if (min != null && l.price < min) return false;
      if (max != null && l.price > max) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search by title, seller, or category...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filledTonal(
                tooltip: 'Filters',
                isSelected: _showFilters || _hasActiveFilters,
                icon: Badge(
                  isLabelVisible: _hasActiveFilters,
                  smallSize: 8,
                  child: const Icon(Icons.filter_list),
                ),
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),
            ],
          ),
        ),
        if (_showFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STATUS', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final status in _statusFilters)
                      ChoiceChip(
                        label: Text(status == 'All' ? 'All' : status),
                        selected: _statusFilter == status,
                        onSelected: (_) => setState(() => _statusFilter = status),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('PRICE RANGE (RM)', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minPriceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          hintText: 'Min',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _maxPriceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          hintText: 'Max',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_hasActiveFilters) ...[
                      const SizedBox(width: AppSpacing.sm),
                      TextButton(onPressed: _clearFilters, child: const Text('Clear')),
                    ],
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: AsyncStateView<List<Listing>>(
            future: _future,
            onRetry: _reload,
            loadingSkeleton: const Center(child: CircularProgressIndicator()),
            isEmpty: (listings) => listings.isEmpty,
            emptyState: const EmptyState(
              icon: Icons.storefront_outlined,
              title: 'No listings yet',
            ),
            builder: (context, allListings) {
              final listings = _filter(allListings);
              if (listings.isEmpty) {
                return const EmptyState(
                  icon: Icons.search_off,
                  title: 'No matches',
                  message: 'Try different search or filter criteria.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: listings.length,
                  itemBuilder: (context, index) {
                    final listing = listings[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ListingDetailScreen(listing: listing, adminView: true),
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: SizedBox(
                                width: 52,
                                height: 52,
                                child: listing.imageUrls.isEmpty
                                    ? ColoredBox(
                                        color: scheme.surfaceContainerHighest,
                                        child: Icon(Icons.image_not_supported_outlined,
                                            size: 20, color: scheme.onSurfaceVariant),
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: listing.imageUrls.first,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    listing.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${listing.sellerName ?? 'Unknown seller'} · '
                                    'RM ${listing.price.toStringAsFixed(2)}'
                                    '${listing.listingType == 'rent' ? '/day' : ''}',
                                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 4,
                                    children: [
                                      StatusChip(
                                        label: listing.status,
                                        variant: listing.status == 'active'
                                            ? StatusVariant.success
                                            : StatusVariant.neutral,
                                      ),
                                      StatusChip(
                                        label: listing.category,
                                        variant: StatusVariant.info,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove listing',
                              icon: Icon(Icons.delete_outline, color: scheme.error),
                              onPressed: _busy ? null : () => _remove(listing),
                            ),
                          ],
                        ),
                      ),
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
