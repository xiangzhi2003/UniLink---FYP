import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';
import 'transaction_detail_screen.dart';

/// "My Deals" — every transaction where I'm the buyer or the seller. Reached
/// from Profile (not a top-level shell tab), so it owns its own Scaffold/AppBar.
class TransactionsListScreen extends ConsumerStatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  ConsumerState<TransactionsListScreen> createState() => TransactionsListScreenState();
}

class TransactionsListScreenState extends ConsumerState<TransactionsListScreen> {
  late Future<List<TransactionDeal>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(transactionServiceProvider).fetchMyDeals();
  }

  void reload() {
    setState(() {
      _future = ref.read(transactionServiceProvider).fetchMyDeals();
    });
  }

  Future<void> _onRefresh() async {
    final future = ref.read(transactionServiceProvider).fetchMyDeals();
    setState(() {
      _future = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.read(authServiceProvider).currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('My Deals')),
      body: AsyncStateView<List<TransactionDeal>>(
        future: _future,
        onRetry: reload,
        isEmpty: (deals) => deals.isEmpty,
        emptyState: RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 120),
              EmptyState(
                icon: Icons.handshake_outlined,
                title: 'No deals yet',
                message: 'Buy or rent something to start one!',
              ),
            ],
          ),
        ),
        builder: (context, deals) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: deals.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final deal = deals[index];
                final iAmBuyer = deal.buyerId == myId;
                final other = iAmBuyer ? (deal.sellerName ?? 'Seller') : (deal.buyerName ?? 'Buyer');
                final scheme = Theme.of(context).colorScheme;

                return AppCard(
                  padding: const EdgeInsets.all(10),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TransactionDetailScreen(dealId: deal.id),
                      ),
                    );
                    reload();
                  },
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: deal.listingImages.isEmpty
                              ? ColoredBox(
                                  color: scheme.outline,
                                  child: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
                                )
                              : CachedNetworkImage(
                                  imageUrl: deal.listingImages.first,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deal.listingTitle ?? 'Listing',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${iAmBuyer ? 'Buying' : 'Selling'} · with $other',
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      _statusChip(deal.status),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _statusChip(String status) {
    final (label, variant) = switch (status) {
      'pending' => ('Pending', StatusVariant.warning),
      'active' => ('In progress', StatusVariant.info),
      'completed' => ('Completed', StatusVariant.success),
      _ => ('Cancelled', StatusVariant.neutral),
    };
    return StatusChip(label: label, variant: variant);
  }
}
