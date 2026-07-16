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

/// Moderation view: every listing on the marketplace, any status, with a
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AsyncStateView<List<Listing>>(
      future: _future,
      onRetry: _reload,
      loadingSkeleton: const Center(child: CircularProgressIndicator()),
      isEmpty: (listings) => listings.isEmpty,
      emptyState: const EmptyState(
        icon: Icons.storefront_outlined,
        title: 'No listings yet',
      ),
      builder: (context, listings) {
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
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: SizedBox(
                          width: 48,
                          height: 48,
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
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      StatusChip(
                        label: listing.status,
                        variant: listing.status == 'active'
                            ? StatusVariant.success
                            : StatusVariant.neutral,
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
    );
  }
}
