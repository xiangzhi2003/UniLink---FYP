import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
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
        title: const Text('Deal'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _reload,
          ),
        ],
      ),
      body: FutureBuilder<TransactionDeal>(
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

          final deal = snapshot.data!;
          final iAmSeller = deal.sellerId == myId;
          final iAmBuyer = deal.buyerId == myId;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    deal.listingTitle ?? 'Listing',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${deal.type == 'rent' ? 'Rental' : 'Purchase'} · '
                    '${iAmSeller ? 'you are selling' : 'you are buying'}',
                    style: const TextStyle(color: AppColors.slate),
                  ),
                  const SizedBox(height: 20),
                  _statusBanner(deal),
                  const SizedBox(height: 16),
                  _escrowSection(context, deal, iAmBuyer),
                  const SizedBox(height: 8),
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
    final amount = deal.listingPrice == null
        ? ''
        : 'RM ${deal.listingPrice!.toStringAsFixed(2)}';

    final (label, detail, color, icon) = switch (deal.escrowStatus) {
      'pending' => (
          'Payment required',
          iAmBuyer
              ? 'Pay $amount to hold safely in escrow. The seller only gets '
                  'paid once you confirm the handover.'
              : 'Waiting for the buyer to pay into escrow.',
          AppColors.goldDeep,
          Icons.lock_clock_outlined,
        ),
      'held' => (
          'Payment held in escrow',
          '$amount is held safely. It\'s released to the seller once the '
              '${deal.type == 'rent' ? 'return' : 'pickup'} is confirmed.',
          AppColors.ink,
          Icons.shield_outlined,
        ),
      'captured' => (
          'Payment released',
          '$amount has been released to the seller. Deal complete.',
          AppColors.verified,
          Icons.verified_outlined,
        ),
      _ => (
          'Payment refunded',
          'The hold was released — the buyer was not charged.',
          AppColors.slate,
          Icons.undo_outlined,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(detail, style: const TextStyle(color: AppColors.slate, height: 1.4)),
          if (iAmBuyer && deal.escrowStatus == 'pending') ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : () => _pay(deal),
                icon: const Icon(Icons.credit_card, size: 18),
                label: Text('Pay $amount'),
              ),
            ),
          ],
          // Cancel + refund is allowed by either party while held and before pickup.
          if (deal.escrowStatus == 'held' && deal.pickupScannedAt == null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : () => _refund(deal),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Cancel deal & refund'),
              ),
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
    final (label, detail, color) = switch (deal.status) {
      'pending' => (
          'Awaiting pickup',
          'Meet up, then confirm the handover with the QR code below.',
          AppColors.goldDeep,
        ),
      'active' => (
          'Rental in progress',
          'Item picked up. Confirm the return with the QR code when it comes back.',
          AppColors.ink,
        ),
      'completed' => ('Completed', 'This deal is done. Thanks for trading safely!', AppColors.verified),
      _ => ('Cancelled', 'This deal was cancelled.', AppColors.slate),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text(detail, style: const TextStyle(color: AppColors.slate, height: 1.4)),
        ],
      ),
    );
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
        const SizedBox(height: 8),
        Text(
          'Scan the QR code on the other person\'s screen (or type the 6-digit code shown under it).',
          style: const TextStyle(color: AppColors.slate, height: 1.4),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text('Scan QR code'),
            onPressed: () => _scan(deal),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.dialpad, size: 18),
            label: const Text('Enter code manually'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.ink),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      builder: (context) => AlertDialog(
        title: const Text('Enter code'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(hintText: '6-digit code', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
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

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate)),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
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
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 6,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Refreshes automatically. Have the other person scan it or type this code.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.slate, fontSize: 12),
        ),
      ],
    );
  }
}
