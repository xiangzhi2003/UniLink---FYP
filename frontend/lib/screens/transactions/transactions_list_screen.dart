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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Deals'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'In Progress'),
              Tab(text: 'History'),
            ],
          ),
        ),
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
            final inProgress =
                deals.where((d) => d.status == 'pending' || d.status == 'active').toList();
            final history =
                deals.where((d) => d.status == 'completed' || d.status == 'cancelled').toList();

            return TabBarView(
              children: [
                _DealsTab(deals: inProgress, myId: myId, onRefresh: _onRefresh, onReturn: reload,
                    emptyTitle: 'Nothing in progress',
                    emptyMessage: 'Deals you buy, sell, or rent show up here while active.'),
                _DealsTab(deals: history, myId: myId, onRefresh: _onRefresh, onReturn: reload,
                    emptyTitle: 'No history yet',
                    emptyMessage: 'Completed and cancelled deals will show up here.'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DealsTab extends StatelessWidget {
  final List<TransactionDeal> deals;
  final String? myId;
  final Future<void> Function() onRefresh;
  final VoidCallback onReturn;
  final String emptyTitle;
  final String emptyMessage;

  const _DealsTab({
    required this.deals,
    required this.myId,
    required this.onRefresh,
    required this.onReturn,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (deals.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            EmptyState(icon: Icons.inbox_outlined, title: emptyTitle, message: emptyMessage),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: deals.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) => _DealRow(
          deal: deals[index],
          myId: myId,
          onReturn: onReturn,
        ),
      ),
    );
  }
}

class _DealRow extends StatelessWidget {
  final TransactionDeal deal;
  final String? myId;
  final VoidCallback onReturn;

  const _DealRow({required this.deal, required this.myId, required this.onReturn});

  String _formatDate(DateTime? date) {
    if (date == null) return '?';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final iAmBuyer = deal.buyerId == myId;
    final other = iAmBuyer ? (deal.sellerName ?? 'Seller') : (deal.buyerName ?? 'Buyer');
    final scheme = Theme.of(context).colorScheme;
    final amount = deal.amount ?? deal.listingPrice;
    final isRent = deal.type == 'rent';

    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransactionDetailScreen(dealId: deal.id),
          ),
        );
        onReturn();
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              width: 64,
              height: 64,
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
                Row(
                  children: [
                    Icon(
                      isRent ? Icons.event_repeat : Icons.sell_outlined,
                      size: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${iAmBuyer ? 'Buying' : 'Selling'} · with $other',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                if (amount != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'RM ${amount.toStringAsFixed(2)}',
                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ],
                if (isRent && deal.rentalDueDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Due back ${_formatDate(deal.rentalDueDate)}',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _statusChip(deal.status),
        ],
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
