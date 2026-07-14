import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_fonts.dart';
import '../../theme/app_tokens.dart';
import '../../utils/error_messages.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/status_banner.dart';
import '../../widgets/status_chip.dart';
import 'qr_scan_screen.dart';

/// One deal: shows the QR-handshake control appropriate to (my role, current
/// phase). Whoever is *giving* the item this phase shows a live QR; whoever is
/// *receiving* scans it (or types the code) to confirm.
class TransactionDetailScreen extends ConsumerStatefulWidget {
  final String dealId;

  const TransactionDetailScreen({super.key, required this.dealId});

  @override
  ConsumerState<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends ConsumerState<TransactionDetailScreen> {
  late Future<TransactionDeal> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _loadAndSync();
  }

  /// Fetch the deal; if a Checkout was started but escrow still reads
  /// 'pending', ask the backend to sync (the buyer may have just paid in the
  /// browser) and fetch once more.
  Future<TransactionDeal> _loadAndSync() async {
    var deal = await ref.read(transactionServiceProvider).fetchDeal(widget.dealId);
    if (deal.escrowStatus == 'pending' && deal.checkoutSessionId != null) {
      try {
        await ref.read(backendServiceProvider).confirmEscrow(widget.dealId);
        deal = await ref.read(transactionServiceProvider).fetchDeal(widget.dealId);
      } catch (_) {
        // Non-fatal — show whatever we have.
      }
    }
    return deal;
  }

  void _reload() {
    setState(() {
      _future = _loadAndSync();
    });
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.read(authServiceProvider).currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<TransactionDeal>(
          future: _future,
          builder: (context, snapshot) {
            return Text(
              snapshot.data?.listingTitle ?? 'Deal',
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _reload,
          ),
        ],
      ),
      body: AsyncStateView<TransactionDeal>(
        future: _future,
        onRetry: _reload,
        builder: (context, deal) {
          final iAmSeller = deal.sellerId == myId;
          final iAmBuyer = deal.buyerId == myId;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                children: [
                  Text(
                    deal.listingTitle ?? 'Listing',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${deal.type == 'rent' ? 'Rental' : 'Purchase'} · '
                    '${iAmSeller ? 'you are selling' : 'you are buying'}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  if (deal.type == 'rent' && deal.rentalDays != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Rented from ${_formatDate(deal.rentalStartDate)} · '
                      'due back ${_formatDate(deal.rentalDueDate)} '
                      '(${deal.rentalDays} day${deal.rentalDays == 1 ? '' : 's'})',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  _statusBanner(deal),
                  const SizedBox(height: AppSpacing.lg),
                  _escrowSection(context, deal, iAmBuyer),
                  const SizedBox(height: AppSpacing.sm),
                  // The handover handshake only unlocks once the payment is
                  // safely held in escrow.
                  if (deal.escrowStatus == 'held')
                    _handshakeSection(context, deal, iAmSeller, iAmBuyer),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _escrowSection(BuildContext context, TransactionDeal deal, bool iAmBuyer) {
    final chargedAmount = deal.amount ?? deal.listingPrice;
    final amount = chargedAmount == null ? '' : 'RM ${chargedAmount.toStringAsFixed(2)}';

    final (label, detail, variant, icon) = switch (deal.escrowStatus) {
      'pending' => (
          'Payment required',
          iAmBuyer
              ? 'Pay $amount to hold safely in escrow. The seller only gets '
                  'paid once you confirm the handover.'
              : 'Waiting for the buyer to pay into escrow.',
          StatusVariant.warning,
          Icons.lock_clock_outlined,
        ),
      'held' => (
          'Payment held in escrow',
          '$amount is held safely. It\'s released to the seller once the '
              '${deal.type == 'rent' ? 'return' : 'pickup'} is confirmed.',
          StatusVariant.info,
          Icons.shield_outlined,
        ),
      'captured' => (
          'Payment released',
          '$amount has been released to the seller. Deal complete.',
          StatusVariant.success,
          Icons.verified_outlined,
        ),
      _ => (
          'Payment refunded',
          'The hold was released — the buyer was not charged.',
          StatusVariant.neutral,
          Icons.undo_outlined,
        ),
    };

    final showPayButton = iAmBuyer && deal.escrowStatus == 'pending';
    final showRefundButton = deal.escrowStatus == 'held' && deal.pickupScannedAt == null;

    return StatusBanner(
      icon: icon,
      title: label,
      detail: detail,
      variant: variant,
      action: !showPayButton && !showRefundButton
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showPayButton) ...[
                  ElevatedButton.icon(
                    onPressed: _busy ? null : () => _pay(deal),
                    icon: const Icon(Icons.credit_card, size: 18),
                    label: Text('Pay $amount'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _cancelUnpaid(deal),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(color: Theme.of(context).colorScheme.error),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: const Text('Cancel this deal'),
                  ),
                ],
                if (showRefundButton) ...[
                  if (showPayButton) const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _refund(deal),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(color: Theme.of(context).colorScheme.error),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: const Text('Cancel deal & refund'),
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _pay(TransactionDeal deal) async {
    setState(() => _busy = true);
    try {
      final url = await ref.read(backendServiceProvider).createEscrowCheckout(deal.id);
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) _snack('Could not open the payment page.');
    } catch (e) {
      if (mounted) _snack(friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // When they come back, refresh to pick up the held status.
    if (mounted) _reload();
  }

  /// Cleans up a legacy deal that was created (before this screen required
  /// payment up front) but never actually paid for.
  Future<void> _cancelUnpaid(TransactionDeal deal) async {
    setState(() => _busy = true);
    try {
      await ref.read(transactionServiceProvider).cancel(deal.id);
      if (mounted) {
        _snack('Deal cancelled.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) _snack(friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refund(TransactionDeal deal) async {
    setState(() => _busy = true);
    try {
      await ref.read(backendServiceProvider).refundEscrow(deal.id);
      if (mounted) _snack('Deal cancelled — payment refunded.');
    } catch (e) {
      if (mounted) _snack(friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) _reload();
  }

  Widget _statusBanner(TransactionDeal deal) {
    final (label, detail, variant, icon) = switch (deal.status) {
      'pending' => (
          'Awaiting pickup',
          'Meet up, then confirm the handover with the QR code below.',
          StatusVariant.warning,
          Icons.schedule_outlined,
        ),
      'active' => (
          'Rental in progress',
          'Item picked up. Confirm the return with the QR code when it comes back.',
          StatusVariant.info,
          Icons.autorenew,
        ),
      'completed' => (
          'Completed',
          'This deal is done. Thanks for trading safely!',
          StatusVariant.success,
          Icons.check_circle_outline,
        ),
      _ => (
          'Cancelled',
          'This deal was cancelled.',
          StatusVariant.neutral,
          Icons.cancel_outlined,
        ),
    };
    return StatusBanner(icon: icon, title: label, detail: detail, variant: variant);
  }

  Widget _handshakeSection(
    BuildContext context,
    TransactionDeal deal,
    bool iAmSeller,
    bool iAmBuyer,
  ) {
    if (deal.status == 'completed' || deal.status == 'cancelled') {
      return const SizedBox.shrink();
    }

    // Pickup: seller gives -> buyer receives. Return: buyer gives -> seller receives.
    final giverIsSeller = deal.phase == 'pickup';
    final iAmGiver = (giverIsSeller && iAmSeller) || (!giverIsSeller && iAmBuyer);
    final phaseLabel = deal.phase == 'pickup' ? 'pickup' : 'return';

    if (iAmGiver) {
      return _QrDisplay(dealId: deal.id, phaseLabel: phaseLabel);
    }

    // Receiver
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CONFIRM $phaseLabel', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Scan the QR code on the other person\'s screen (or type the 6-digit code shown under it).',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text('Scan QR code'),
            onPressed: () => _scan(deal),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.dialpad, size: 18),
            label: const Text('Enter code manually'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(color: Theme.of(context).colorScheme.primary),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            onPressed: () => _enterCode(deal),
          ),
        ),
      ],
    );
  }

  Future<void> _scan(TransactionDeal deal) async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (scanned == null) return;

    if (scanned == QrScanScreen.manualEntryRequested) {
      await _enterCode(deal);
      return;
    }

    // The QR encodes {"transaction_id", "code"} — pull the code out.
    String code;
    try {
      final data = jsonDecode(scanned) as Map<String, dynamic>;
      code = data['code'] as String;
    } catch (_) {
      _snack('That QR code isn\'t a UniLink handover code.');
      return;
    }
    await _submit(deal, code);
  }

  Future<void> _enterCode(TransactionDeal deal) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => _ManualCodeDialog(controller: controller),
    );
    if (code == null || code.isEmpty) return;
    await _submit(deal, code);
  }

  Future<void> _submit(TransactionDeal deal, String code) async {
    try {
      final result = await ref.read(backendServiceProvider).verifyQr(deal.id, code);
      if (!mounted) return;
      _snack(result.message);
      _reload();
    } catch (e) {
      _snack(friendlyErrorMessage(e));
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '?';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Manual 6-digit code entry dialog with inline validation feedback — the
/// confirm button stays disabled until exactly 6 digits are entered.
class _ManualCodeDialog extends StatefulWidget {
  final TextEditingController controller;

  const _ManualCodeDialog({required this.controller});

  @override
  State<_ManualCodeDialog> createState() => _ManualCodeDialogState();
}

class _ManualCodeDialogState extends State<_ManualCodeDialog> {
  static final _sixDigits = RegExp(r'^\d{6}$');
  bool _touched = false;

  bool get _isValid => _sixDigits.hasMatch(widget.controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final showError = _touched && widget.controller.text.isNotEmpty && !_isValid;

    return AlertDialog(
      title: const Text('Enter code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            decoration: InputDecoration(
              hintText: '6-digit code',
              counterText: '',
              errorText: showError ? 'Enter exactly 6 digits' : null,
            ),
            onChanged: (_) => setState(() => _touched = true),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: _isValid ? () => Navigator.pop(context, widget.controller.text.trim()) : null,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

/// Live QR for the giver: fetches the current code from the backend and
/// auto-refreshes every 60s (the TOTP window), so a screenshot goes stale.
class _QrDisplay extends ConsumerStatefulWidget {
  final String dealId;
  final String phaseLabel;

  const _QrDisplay({required this.dealId, required this.phaseLabel});

  @override
  ConsumerState<_QrDisplay> createState() => _QrDisplayState();
}

class _QrDisplayState extends ConsumerState<_QrDisplay> {
  String? _payload;
  String? _code;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final result = await ref.read(backendServiceProvider).fetchCurrentQr(widget.dealId);
      if (!mounted) return;
      String? code;
      try {
        code = (jsonDecode(result.payload) as Map<String, dynamic>)['code'] as String?;
      } catch (_) {}
      setState(() {
        _payload = result.payload;
        _code = code;
        _error = null;
      });
      _timer?.cancel();
      // Refresh a touch after the code rotates.
      _timer = Timer(Duration(seconds: result.expiresIn + 1), _fetch);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyErrorMessage(e));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Column(
        children: [
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _fetch, child: const Text('Try again')),
        ],
      );
    }
    if (_payload == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }

    return Column(
      children: [
        Text('SHOW THIS FOR ${widget.phaseLabel.toUpperCase()}',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // Kept literal white regardless of theme — QR scanners need
            // reliable light-background/dark-module contrast to read.
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: QrImageView(
            data: _payload!,
            size: 220,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _code ?? '',
          style: AppFonts.mono(
            context,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 6,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Refreshes automatically. Have the other person scan it or type this code.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }
}
