// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : pending_purchase_screen.dart
// Description     : Payment-method selection and checkout screen (Stripe card or wallet) for buying/renting a listing.
// First Written on: Monday,13-Jul-2026
// Edited on       : Tuesday,14-Jul-2026

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/listing.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/error_messages.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_banner.dart';
import '../../widgets/status_chip.dart';
import 'payment_success_screen.dart';

enum _PaymentMethod { stripe, wallet }

/// Shown after tapping Buy/Book, before any deal exists — no transaction row
/// is written until payment is actually confirmed held. If the buyer pays,
/// this screen creates the deal for the first time and hands off to
/// [TransactionDetailScreen]; if they back out, nothing was ever created.
class PendingPurchaseScreen extends ConsumerStatefulWidget {
  final Listing listing;

  const PendingPurchaseScreen({super.key, required this.listing});

  @override
  ConsumerState<PendingPurchaseScreen> createState() => _PendingPurchaseScreenState();
}

class _PendingPurchaseScreenState extends ConsumerState<PendingPurchaseScreen> {
  String? _sessionId;
  bool _busy = false;
  String? _error;
  int _rentalDays = 1;
  _PaymentMethod _method = _PaymentMethod.stripe;
  double? _walletBalance;

  bool get _isRent => widget.listing.listingType == 'rent';
  double get _total => widget.listing.price * (_isRent ? _rentalDays : 1);
  bool get _walletInsufficient => _walletBalance != null && _walletBalance! < _total;

  @override
  void initState() {
    super.initState();
    ref.read(backendServiceProvider).fetchWalletSummary().then((s) {
      if (mounted) setState(() => _walletBalance = s.balance);
    }).catchError((_) {
      // Balance just won't be shown/selectable — Stripe remains available.
    });
  }

  Future<void> _pay() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(backendServiceProvider).startEscrowCheckout(
            listingId: widget.listing.id!,
            sellerId: widget.listing.sellerId,
            type: widget.listing.listingType,
            rentalDays: _isRent ? _rentalDays : null,
          );
      _sessionId = result.sessionId;
      final ok = await launchUrl(
        Uri.parse(result.checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) setState(() => _error = 'Could not open the payment page.');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkStatus() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(backendServiceProvider).confirmAndCreateEscrow(
            sessionId: sessionId,
            listingId: widget.listing.id!,
            sellerId: widget.listing.sellerId,
            type: widget.listing.listingType,
          );
      if (result.transactionId != null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => PaymentSuccessScreen(
                transactionId: result.transactionId!,
                amount: _total,
                listingTitle: widget.listing.title,
              ),
            ),
          );
        }
        return;
      }
      if (mounted) {
        setState(() => _error = "Payment not detected yet — finish paying, then check again.");
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payWithWallet() async {
    if (_walletInsufficient) {
      setState(() => _error = 'Insufficient wallet balance.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final transactionId = await ref.read(backendServiceProvider).payWithWallet(
            listingId: widget.listing.id!,
            sellerId: widget.listing.sellerId,
            type: widget.listing.listingType,
            rentalDays: _isRent ? _rentalDays : null,
          );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PaymentSuccessScreen(
              transactionId: transactionId,
              amount: _total,
              listingTitle: widget.listing.title,
            ),
          ),
        );
      }
    } catch (e) {
      final message = friendlyErrorMessage(e);
      if (mounted) {
        setState(() {
          _error = message.toLowerCase().contains('insufficient')
              ? 'Insufficient wallet balance.'
              : message;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final isRent = listing.listingType == 'rent';
    final scheme = Theme.of(context).colorScheme;
    final choosingPaymentMethod = _sessionId == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Purchase')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            children: [
              Text(listing.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'RM ${listing.price.toStringAsFixed(2)}${isRent ? ' / day' : ''}',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: scheme.secondary),
              ),
              if (isRent) ...[
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Number of days'),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _sessionId != null || _rentalDays <= 1
                              ? null
                              : () => setState(() => _rentalDays--),
                        ),
                        Text('$_rentalDays', style: Theme.of(context).textTheme.titleMedium),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: _sessionId != null || _rentalDays >= 30
                              ? null
                              : () => setState(() => _rentalDays++),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'RM ${listing.price.toStringAsFixed(2)} × $_rentalDays days = '
                  'RM ${_total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (choosingPaymentMethod) ...[
                const SizedBox(height: AppSpacing.xl),
                Text('Pay with', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _PaymentMethodTile(
                        icon: Icons.credit_card,
                        label: 'Card',
                        subtitle: 'via Stripe',
                        selected: _method == _PaymentMethod.stripe,
                        onTap: () => setState(() => _method = _PaymentMethod.stripe),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _PaymentMethodTile(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Wallet',
                        subtitle: _walletBalance == null
                            ? 'Loading...'
                            : 'RM ${_walletBalance!.toStringAsFixed(2)}',
                        selected: _method == _PaymentMethod.wallet,
                        onTap: () => setState(() => _method = _PaymentMethod.wallet),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              StatusBanner(
                icon: Icons.lock_clock_outlined,
                title: 'Nothing is created until you pay',
                detail: !choosingPaymentMethod
                    ? "Finished paying in the browser? Tap \"I've paid\" to continue. "
                        'If you back out now without paying, nothing will be created.'
                    : _method == _PaymentMethod.wallet
                        ? 'Your wallet balance is debited immediately and the deal is held in '
                            'escrow, released to the seller once you confirm the handover.'
                        : 'Tap Pay to open secure Stripe checkout. Your payment is held '
                            'in escrow and only released to the seller once you confirm '
                            'the handover — nothing is booked here unless you complete payment.',
                variant: StatusVariant.warning,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: AppSpacing.xxl),
              if (choosingPaymentMethod)
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: _method == _PaymentMethod.wallet
                        ? 'Pay RM ${_total.toStringAsFixed(2)} with Wallet'
                        : 'Pay RM ${_total.toStringAsFixed(2)}',
                    icon: _method == _PaymentMethod.wallet
                        ? Icons.account_balance_wallet_outlined
                        : Icons.credit_card,
                    isLoading: _busy,
                    onPressed: _busy || (_method == _PaymentMethod.wallet && _walletInsufficient)
                        ? null
                        : (_method == _PaymentMethod.wallet ? _payWithWallet : _pay),
                  ),
                )
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: "I've paid — check status",
                    icon: Icons.refresh,
                    isLoading: _busy,
                    onPressed: _busy ? null : _checkStatus,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: SecondaryButton(
                    label: 'Open payment page again',
                    icon: Icons.open_in_new,
                    onPressed: _busy ? null : _pay,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      color: selected ? scheme.primary.withValues(alpha: 0.08) : null,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Column(
        children: [
          Icon(icon, color: selected ? scheme.primary : scheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? scheme.primary : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
