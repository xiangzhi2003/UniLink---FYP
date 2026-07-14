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

  /// Fires whenever any transaction row changes — used to keep the My Deals
  /// badge live without polling. Deliberately unfiltered (the realtime
  /// stream builder can't express "buyer OR seller"); relies on
  /// [heldDealsCount]'s own explicit `.or(...)` filter for correctness, same
  /// as chat's unfiltered myMessagesStream()+unreadCount() pairing.
  Stream<List<Map<String, dynamic>>> myTransactionsStream() {
    return supabase.from('transactions').stream(primaryKey: ['id']);
  }
}
