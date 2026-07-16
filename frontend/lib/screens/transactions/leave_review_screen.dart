import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/transaction.dart';
import '../../providers/review_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/error_messages.dart';
import '../../widgets/app_button.dart';
import '../../widgets/star_rating.dart';

/// One-way review form: buyer rates seller after a completed deal. Pushed
/// from [TransactionDetailScreen]'s "Leave a Review" CTA, pops `true` on a
/// successful submit so the caller can refresh its "already reviewed" state.
class LeaveReviewScreen extends ConsumerStatefulWidget {
  final TransactionDeal deal;

  const LeaveReviewScreen({super.key, required this.deal});

  @override
  ConsumerState<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends ConsumerState<LeaveReviewScreen> {
  final _commentController = TextEditingController();
  int _rating = 0;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_rating == 0) return;
    setState(() => _submitting = true);
    try {
      await ref.read(reviewServiceProvider).submitReview(
            transactionId: widget.deal.id,
            listingId: widget.deal.listingId,
            sellerId: widget.deal.sellerId,
            rating: _rating,
            comment: _commentController.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave a Review')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text(
                'How was your experience with ${widget.deal.sellerName ?? 'the seller'}?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: StarRating(
                  rating: _rating,
                  size: 36,
                  onChanged: (value) => setState(() => _rating = value),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _commentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                  hintText: 'Share details about your experience...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Submit Review',
                isLoading: _submitting,
                onPressed: _rating == 0 || _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
