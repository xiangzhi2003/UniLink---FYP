import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/wallet.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/colored_header.dart';
import '../../widgets/empty_state.dart';

/// Simulated seller wallet: captured escrow payments credit this balance.
/// No real bank transfer happens (test-mode FYP scope) — this is an in-app
/// ledger showing what the seller has earned.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  late Future<WalletSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(backendServiceProvider).fetchWalletSummary();
  }

  void _reload() {
    setState(() {
      _future = ref.read(backendServiceProvider).fetchWalletSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: AsyncStateView<WalletSummary>(
        future: _future,
        onRetry: _reload,
        builder: (context, summary) {
          return Column(
            children: [
              ColoredHeader(
                child: Column(
                  children: [
                    const Text('Available balance', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'RM ${summary.balance.toStringAsFixed(2)}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: summary.history.isEmpty
                    ? const EmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'No earnings yet',
                        message: 'Sell or rent out an item to get started.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: summary.history.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) => _EntryRow(entry: summary.history[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final WalletEntry entry;

  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.listingTitle ?? 'Listing',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.dealType == 'rent' ? 'Rental' : 'Sale'} · '
                  '${entry.createdAt.day}/${entry.createdAt.month}/${entry.createdAt.year}',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '+RM ${entry.amount.toStringAsFixed(2)}',
            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
