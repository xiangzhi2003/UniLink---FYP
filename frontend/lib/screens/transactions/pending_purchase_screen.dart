import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/listing.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/error_messages.dart';
import '../../widgets/app_button.dart';
import '../../widgets/status_banner.dart';
import '../../widgets/status_chip.dart';
import 'transaction_detail_screen.dart';

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
              builder: (_) => TransactionDetailScreen(dealId: result.transactionId!),
            ),
          );
        }
        return;
      }
      if (mounted) {
        setState(() => _error = "Payment not detected yet — finish paying, then check again.");
      }
    } catch (e) {
      // TODO(debug): temporary — shows the raw error so we can see exactly
      // why confirm-and-create failed, instead of the generic friendly
      // message hiding it. Remove once the real cause is fixed.
      debugPrint('confirmAndCreateEscrow failed: $e');
      if (mounted) setState(() => _error = '${friendlyErrorMessage(e)}\n\n[debug] $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final isRent = listing.listingType == 'rent';
    final scheme = Theme.of(context).colorScheme;

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
              const SizedBox(height: AppSpacing.xl),
              StatusBanner(
                icon: Icons.lock_clock_outlined,
                title: 'Nothing is created until you pay',
                detail: _sessionId == null
                    ? 'Tap Pay to open secure Stripe checkout. Your payment is held '
                        'in escrow and only released to the seller once you confirm '
                        'the handover — nothing is booked here unless you complete payment.'
                    : "Finished paying in the browser? Tap \"I've paid\" to continue. "
                        'If you back out now without paying, nothing will be created.',
                variant: StatusVariant.warning,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: AppSpacing.xxl),
              if (_sessionId == null)
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: 'Pay RM ${listing.price.toStringAsFixed(2)}',
                    icon: Icons.credit_card,
                    isLoading: _busy,
                    onPressed: _busy ? null : _pay,
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
