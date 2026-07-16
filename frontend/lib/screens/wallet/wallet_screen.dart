import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/wallet.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/error_messages.dart';
import '../../widgets/app_card.dart';
import '../../widgets/colored_header.dart';
import '../../widgets/empty_state.dart';

/// Simulated seller wallet: captured escrow payments credit this balance.
/// No real bank transfer happens (test-mode FYP scope) — this is an in-app
/// ledger showing what the seller has earned. Both Withdraw and Deposit open
/// a real Stripe Checkout page for the "leave the app" rhythm; Deposit
/// actually charges a test card, Withdraw uses a $0 setup session (no charge
/// possible — Stripe Checkout can't pay money out without Stripe Connect).
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> with WidgetsBindingObserver {
  // Retained in state (not driven by a `Future` swap) so a refresh updates
  // these numbers in place — same as Browse's header never disappearing on
  // pull-to-refresh — instead of the whole screen flashing to a loading
  // skeleton and back.
  WalletSummary? _summary;
  bool _initialLoading = true;
  String? _loadError;
  String? _pendingDepositSessionId;
  String? _pendingWithdrawSessionId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from Stripe's browser tab — silently check whether the
    // deposit/withdrawal actually went through, with no button for the user
    // to tap.
    if (state != AppLifecycleState.resumed) return;
    if (_pendingDepositSessionId != null) _checkPendingDeposit();
    if (_pendingWithdrawSessionId != null) _checkPendingWithdraw();
  }

  Future<void> _checkPendingDeposit() async {
    final sessionId = _pendingDepositSessionId;
    if (sessionId == null) return;
    try {
      final result = await ref.read(backendServiceProvider).confirmWalletDeposit(sessionId);
      if (!mounted) return;
      if (result.credited) {
        setState(() => _pendingDepositSessionId = null);
        _snack('Funds added.');
        _reload();
      }
      // Not credited yet (buyer backed out, or Checkout hasn't settled) —
      // stay silent, same as if no deposit had been started at all.
    } catch (_) {
      // A background check failing shouldn't interrupt the user.
    }
  }

  Future<void> _checkPendingWithdraw() async {
    final sessionId = _pendingWithdrawSessionId;
    if (sessionId == null) return;
    try {
      final result = await ref.read(backendServiceProvider).confirmWalletWithdrawal(sessionId);
      if (!mounted) return;
      if (result.credited) {
        setState(() => _pendingWithdrawSessionId = null);
        _snack('Withdrawal complete.');
        _reload();
      }
      // Not completed yet — stay silent, same as if nothing had been started.
    } catch (_) {
      // A background check failing shouldn't interrupt the user.
    }
  }

  /// Loads wallet data. On first load, shows a full loading state. On any
  /// later call (pull-to-refresh, or after withdraw/deposit), the existing
  /// balance/history stay on screen until the new data is ready — no flash.
  Future<void> _load() async {
    if (_summary == null) setState(() => _initialLoading = true);
    try {
      final summary = await ref.read(backendServiceProvider).fetchWalletSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _initialLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_summary == null) {
        setState(() {
          _initialLoading = false;
          _loadError = friendlyErrorMessage(e);
        });
      } else {
        // Already have data on screen — don't rip it out over a refresh
        // hiccup, just let the user know.
        _snack(friendlyErrorMessage(e));
      }
    }
  }

  void _reload() => _load();

  Future<void> _onRefresh() => _load();

  Future<void> _withdraw() async {
    final summary = _summary;
    if (summary == null) return;
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => _AmountDialog(
        title: 'Withdraw funds',
        icon: Icons.arrow_downward_rounded,
        hint: 'Up to RM ${summary.balance.toStringAsFixed(2)} available',
        helperText: 'Opens a Stripe test checkout, same as adding funds — no charge is made.',
        confirmLabel: 'Continue',
        maxAmount: summary.balance,
      ),
    );
    if (amount == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await ref.read(backendServiceProvider).startWalletWithdrawal(amount);
      final ok = await launchUrl(
        Uri.parse(result.checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
      if (ok) {
        setState(() => _pendingWithdrawSessionId = result.sessionId);
      } else if (mounted) {
        _snack('Could not open the payment page.');
      }
    } catch (e) {
      if (mounted) _snack(friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startDeposit() async {
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => const _AmountDialog(
        title: 'Add funds',
        icon: Icons.add_rounded,
        hint: 'e.g. 50.00',
        helperText: 'Opens a Stripe test checkout — use a test card to top up.',
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

  Future<void> _settleDebt() async {
    setState(() => _busy = true);
    try {
      final summary = await ref.read(backendServiceProvider).settleDebt();
      if (!mounted) return;
      setState(() => _summary = summary);
      _snack(
        summary.outstandingDebt > 0
            ? 'Partial payment applied — RM${summary.outstandingDebt.toStringAsFixed(2)} still owed.'
            : 'Debt settled — you can rent again.',
      );
    } catch (e) {
      if (mounted) _snack(friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final summary = _summary;
    if (summary == null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: _loadError,
        actionLabel: 'Retry',
        onAction: _reload,
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: Column(
        children: [
          ColoredHeader(
            child: Column(
              children: [
                Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white.withValues(alpha: 0.85), size: 28),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'AVAILABLE BALANCE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'RM ${summary.balance.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -AppSpacing.xl),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                boxShadow: AppElevation.card,
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.add_rounded,
                        label: 'Add funds',
                        color: Theme.of(context).colorScheme.primary,
                        onTap: _busy ? null : _startDeposit,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.arrow_downward_rounded,
                        label: 'Withdraw',
                        color: Theme.of(context).colorScheme.onSurface,
                        onTap: _busy || summary.balance <= 0 ? null : _withdraw,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg,
              ),
              children: [
                if (summary.outstandingDebt > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'You owe RM${summary.outstandingDebt.toStringAsFixed(2)} in late '
                            'fees — settle this to rent again.',
                            style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        FilledButton(
                          onPressed: _busy || summary.balance <= 0 ? null : _settleDebt,
                          child: const Text('Settle Now'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (summary.history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xxxl),
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No activity yet',
                      message: 'Sell or rent out an item, or add funds, to get started.',
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      'RECENT ACTIVITY',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  ...summary.history.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _EntryRow(entry: entry),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon-over-label quick action, used inside the balance card's action bar.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: disabled ? Theme.of(context).disabledColor : color),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: disabled ? Theme.of(context).disabledColor : color,
              ),
            ),
          ],
        ),
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
    final (title, subtitle, icon) = switch (entry.type) {
      'withdrawal' => ('Withdrawal', 'Cashed out', Icons.arrow_downward_rounded),
      'deposit' => ('Added funds', 'Wallet top-up', Icons.add_rounded),
      'late_fee_charge' => (
          'Late fee',
          entry.listingTitle != null ? 'Late return of ${entry.listingTitle}' : 'Late return fee',
          Icons.schedule_outlined,
        ),
      'late_fee_credit' => (
          'Late fee received',
          entry.listingTitle != null ? 'From late return of ${entry.listingTitle}' : 'Late fee received',
          Icons.schedule_outlined,
        ),
      'debt_settlement_charge' => ('Debt settled', 'Outstanding late fee paid off', Icons.check_circle_outline),
      'debt_settlement_credit' => ('Late fee debt received', 'Buyer settled an overdue late fee', Icons.check_circle_outline),
      _ => (
          entry.listingTitle ?? 'Listing',
          entry.dealType == 'rent' ? 'Rental earning' : 'Sale earning',
          Icons.arrow_upward_rounded,
        ),
    };
    final date = '${entry.createdAt.day}/${entry.createdAt.month}/${entry.createdAt.year}';
    final tint = isDebit ? scheme.error : scheme.primary;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: tint),
          ),
          const SizedBox(width: AppSpacing.md),
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
            style: TextStyle(color: tint, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Amount-entry dialog shared by Withdraw and Add funds.
class _AmountDialog extends StatefulWidget {
  final String title;
  final IconData icon;
  final String hint;
  final String helperText;
  final String confirmLabel;
  final double? maxAmount;

  const _AmountDialog({
    required this.title,
    required this.icon,
    required this.hint,
    required this.helperText,
    required this.confirmLabel,
    this.maxAmount,
  });

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _controller = TextEditingController();

  double? get _amount => double.tryParse(_controller.text.trim());

  bool get _isValid {
    final a = _amount;
    if (a == null || a <= 0) return false;
    if (widget.maxAmount != null && a > widget.maxAmount!) return false;
    return true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          Icon(widget.icon, color: scheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(widget.title),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(prefixText: 'RM ', hintText: widget.hint),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.helperText,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _isValid ? () => Navigator.pop(context, _amount) : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

