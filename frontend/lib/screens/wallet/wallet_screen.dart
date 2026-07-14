import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/wallet.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/error_messages.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/colored_header.dart';
import '../../widgets/empty_state.dart';

/// Simulated seller wallet: captured escrow payments credit this balance.
/// No real bank transfer happens (test-mode FYP scope) — this is an in-app
/// ledger showing what the seller has earned. Withdraw is a simulated
/// cash-out (debit entry only); Deposit tops the balance up via a real
/// Stripe test payment the user makes to themselves.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  late Future<WalletSummary> _future;
  String? _pendingDepositSessionId;
  bool _busy = false;

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

  Future<void> _withdraw() async {
    final summary = await _future;
    if (!mounted) return;
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => _AmountDialog(
        title: 'Withdraw funds',
        hint: 'Up to RM ${summary.balance.toStringAsFixed(2)} available',
        confirmLabel: 'Withdraw',
      ),
    );
    if (amount == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(backendServiceProvider).withdrawFromWallet(amount);
      if (mounted) _snack('RM ${amount.toStringAsFixed(2)} withdrawn.');
    } catch (e) {
      if (mounted) _snack(friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _reload();
  }

  Future<void> _startDeposit() async {
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => const _AmountDialog(
        title: 'Add funds',
        hint: 'Opens Stripe test checkout',
        confirmLabel: 'Continue',
      ),
    );
    if (amount == null) return;

    setState(() => _busy = true);
    try {
      final result = await ref.read(backendServiceProvider).startWalletDeposit(amount);
      final ok = await launchUrl(
        Uri.parse(result.checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
      if (ok) {
        setState(() => _pendingDepositSessionId = result.sessionId);
      } else if (mounted) {
        _snack('Could not open the payment page.');
      }
    } catch (e) {
      if (mounted) _snack(friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDeposit() async {
    final sessionId = _pendingDepositSessionId;
    if (sessionId == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(backendServiceProvider).confirmWalletDeposit(sessionId);
      if (mounted) {
        setState(() => _pendingDepositSessionId = null);
        _snack('Funds added.');
      }
    } catch (e) {
      if (mounted) _snack(friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _reload();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
                    const SizedBox(height: AppSpacing.lg),
                    if (_pendingDepositSessionId != null)
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: "I've paid — check for funds",
                          icon: Icons.refresh,
                          isLoading: _busy,
                          onPressed: _busy ? null : _confirmDeposit,
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              label: 'Add funds',
                              icon: Icons.add,
                              isLoading: _busy,
                              onPressed: _busy ? null : _startDeposit,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: SecondaryButton(
                              label: 'Withdraw',
                              icon: Icons.arrow_downward,
                              isLoading: _busy,
                              onPressed: _busy || summary.balance <= 0 ? null : _withdraw,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Expanded(
                child: summary.history.isEmpty
                    ? const EmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'No activity yet',
                        message: 'Sell or rent out an item, or add funds, to get started.',
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
    final isDebit = entry.amount < 0;
    final (title, subtitle) = switch (entry.type) {
      'withdrawal' => ('Withdrawal', 'Cashed out'),
      'deposit' => ('Added funds', 'Wallet top-up'),
      _ => (
          entry.listingTitle ?? 'Listing',
          entry.dealType == 'rent' ? 'Rental' : 'Sale',
        ),
    };
    final date = '${entry.createdAt.day}/${entry.createdAt.month}/${entry.createdAt.year}';

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '$subtitle · $date',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${isDebit ? '-' : '+'}RM ${entry.amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: isDebit ? scheme.error : scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Amount-entry dialog shared by Withdraw and Add funds.
class _AmountDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String confirmLabel;

  const _AmountDialog({required this.title, required this.hint, required this.confirmLabel});

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _controller = TextEditingController();

  double? get _amount => double.tryParse(_controller.text.trim());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(prefixText: 'RM ', hintText: widget.hint),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: (_amount != null && _amount! > 0)
              ? () => Navigator.pop(context, _amount)
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
