import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import 'transaction_detail_screen.dart';

/// "Deals" tab: every transaction where I'm the buyer or the seller.
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

    return FutureBuilder<List<TransactionDeal>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(friendlyErrorMessage(snapshot.error!), textAlign: TextAlign.center),
            ),
          );
        }

        final deals = snapshot.data ?? [];
        if (deals.isEmpty) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Icon(Icons.handshake_outlined, size: 56, color: AppColors.slate),
                SizedBox(height: 12),
                Text(
                  'No deals yet.\nBuy or rent something to start one!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.slate),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: deals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final deal = deals[index];
              final iAmBuyer = deal.buyerId == myId;
              final other = iAmBuyer ? (deal.sellerName ?? 'Seller') : (deal.buyerName ?? 'Buyer');

              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TransactionDetailScreen(dealId: deal.id),
                      ),
                    );
                    reload();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: deal.listingImages.isEmpty
                                ? const ColoredBox(
                                    color: AppColors.line,
                                    child: Icon(Icons.image_outlined, color: AppColors.slate),
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
                                style: const TextStyle(color: AppColors.slate, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        _statusChip(deal.status),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _statusChip(String status) {
    final (label, color) = switch (status) {
      'pending' => ('Pending', AppColors.goldDeep),
      'active' => ('In progress', AppColors.ink),
      'completed' => ('Completed', AppColors.verified),
      _ => ('Cancelled', AppColors.slate),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
