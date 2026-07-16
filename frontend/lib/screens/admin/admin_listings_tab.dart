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

/// Moderation view: every listing on the marketplace, any status, tappable
/// through to the real ListingDetailScreen for the full picture (photos,
/// description, tags, everything) plus a remove action. Removal deletes
/// the row AND its Pinecone vector server-side in one call.
class AdminListingsTab extends ConsumerStatefulWidget {
  const AdminListingsTab({super.key});

  @override
  ConsumerState<AdminListingsTab> createState() => _AdminListingsTabState();
}

class _AdminListingsTabState extends ConsumerState<AdminListingsTab> {
  late Future<List<Listing>> _future;
  bool _busy = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = ref.read(backendServiceProvider).fetchAdminListings();
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

  List<Listing> _filter(List<Listing> listings) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return listings;
    return listings.where((l) {
      return l.title.toLowerCase().contains(q) ||
          (l.sellerName ?? '').toLowerCase().contains(q) ||
          l.category.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0,
          ),
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
                  message: 'Try a different search term.',
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
                            builder: (_) => ListingDetailScreen(listing: listing),
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
