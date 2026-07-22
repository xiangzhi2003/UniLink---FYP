// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : transaction_service.dart
// Description     : Wraps Supabase queries for fetching the signed-in user's transactions/deals.
// First Written on: Monday,06-Jul-2026
// Edited on       : Thursday,16-Jul-2026

import '../config/supabase_config.dart';
import '../models/transaction.dart';

class TransactionService {
  // Disambiguate the two FKs to profiles (buyer_id / seller_id) with the
  // `profiles!<column>` hint so PostgREST knows which relationship to join.
  static const _select =
      '*, listings(title, price, image_urls), buyer:profiles!buyer_id(full_name), seller:profiles!seller_id(full_name)';

  /// All deals where the current user is buyer or seller, newest first.
  Future<List<TransactionDeal>> fetchMyDeals() async {
    final userId = supabase.auth.currentSession!.user.id;
    final rows = await supabase
        .from('transactions')
        .select(_select)
        .or('buyer_id.eq.$userId,seller_id.eq.$userId')
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((r) => TransactionDeal.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<TransactionDeal> fetchDeal(String id) async {
    final row = await supabase.from('transactions').select(_select).eq('id', id).single();
    return TransactionDeal.fromJson(row);
  }

  Future<void> cancel(String id) async {
    await supabase.from('transactions').update({
      'status': 'cancelled',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Deals of mine with money currently sitting in escrow (paid, not yet
  /// released) — powers the My Deals badge, isolated from notifications:
  /// it clears only once the handover is confirmed and escrow is captured
  /// or refunded, not when a notification is marked read.
  Future<int> heldDealsCount() async {
    final userId = supabase.auth.currentSession!.user.id;
    final rows = await supabase
        .from('transactions')
        .select('id')
        .or('buyer_id.eq.$userId,seller_id.eq.$userId')
        .eq('escrow_status', 'held');
    return (rows as List<dynamic>).length;
  }

  /// Completed deals of mine (as buyer) I haven't reviewed yet -- powers a
  /// second signal on the My Deals badge/History tab nudging buyers to
  /// leave feedback. Two queries + a client-side set diff since the
  /// Supabase client SDK has no clean "not in another table" filter; both
  /// result sets are small per-user so this is cheap.
  Future<int> unreviewedCompletedCount() async {
    final userId = supabase.auth.currentSession!.user.id;
    final completed = await supabase
        .from('transactions')
        .select('id')
        .eq('buyer_id', userId)
        .eq('status', 'completed');
    final completedIds = (completed as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['id'] as String)
        .toSet();
    if (completedIds.isEmpty) return 0;

    final reviewed = await supabase
        .from('reviews')
        .select('transaction_id')
        .eq('reviewer_id', userId);
    final reviewedIds = (reviewed as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['transaction_id'] as String)
        .toSet();

    return completedIds.difference(reviewedIds).length;
  }

  /// Fires whenever any transaction row changes — used to keep the My Deals
  /// badge live without polling. Deliberately unfiltered (the realtime
  /// stream builder can't express "buyer OR seller"); relies on
  /// [heldDealsCount]'s own explicit `.or(...)` filter for correctness, same
  /// as chat's unfiltered myMessagesStream()+unreadCount() pairing.
  Stream<List<Map<String, dynamic>>> myTransactionsStream() {
    return supabase.from('transactions').stream(primaryKey: ['id']);
  }
}
