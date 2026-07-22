// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : payment_success_screen.dart
// Description     : Confirmation screen shown immediately after a payment is confirmed held in escrow.
// First Written on: Tuesday,14-Jul-2026
// Edited on       : Tuesday,14-Jul-2026

import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';
import 'transaction_detail_screen.dart';

/// Shown right after a payment (Stripe or wallet) is confirmed held, before
/// handing off to the deal detail screen — a clear "you're done, here's what
/// happened" moment instead of jumping straight to the next screen.
class PaymentSuccessScreen extends StatelessWidget {
  final String transactionId;
  final double amount;
  final String listingTitle;

  const PaymentSuccessScreen({
    super.key,
    required this.transactionId,
    required this.amount,
    required this.listingTitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: scheme.primary,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 64),
                  const SizedBox(height: AppSpacing.xl),
                  const Text(
                    'Payment successful',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'RM ${amount.toStringAsFixed(2)} for "$listingTitle"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Your payment is held safely in escrow until the handover is confirmed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  SizedBox(
                    width: 220,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: scheme.primary,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => TransactionDetailScreen(dealId: transactionId),
                        ),
                      ),
                      child: const Text('View Deal'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
