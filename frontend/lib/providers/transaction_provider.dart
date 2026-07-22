// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : transaction_provider.dart
// Description     : Riverpod providers exposing TransactionService, BackendService, and the live count of deals held in escrow.
// First Written on: Monday,06-Jul-2026
// Edited on       : Thursday,16-Jul-2026

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/backend_service.dart';
import '../services/transaction_service.dart';
import 'auth_provider.dart';

final transactionServiceProvider =
    Provider<TransactionService>((ref) => TransactionService());

final backendServiceProvider = Provider<BackendService>((ref) => BackendService());

/// Deals of mine with payment held in escrow, not yet released — powers the
/// My Deals badge. Deliberately separate from notifications: this only
/// clears once a deal is captured/refunded, not when a notification is read.
/// Watches [authStateProvider] so it rebuilds correctly-scoped on sign-out/
/// sign-in, same reasoning as the chat/notification unread-count providers.
final heldDealsCountProvider = StreamProvider<int>((ref) {
  ref.watch(authStateProvider);
  final svc = ref.watch(transactionServiceProvider);
  return svc.myTransactionsStream().asyncMap((_) => svc.heldDealsCount());
});

/// Completed deals of mine awaiting a review -- a second signal combined
/// into the My Deals badge and shown on the History tab. Driven off the
/// same transactions realtime stream as [heldDealsCountProvider]; submitting
/// a review doesn't touch the transactions table, so
/// [LeaveReviewScreen] explicitly invalidates this provider on submit.
final unreviewedCompletedCountProvider = StreamProvider<int>((ref) {
  ref.watch(authStateProvider);
  final svc = ref.watch(transactionServiceProvider);
  return svc.myTransactionsStream().asyncMap((_) => svc.unreviewedCompletedCount());
});
