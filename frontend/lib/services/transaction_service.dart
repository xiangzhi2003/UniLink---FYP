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
}
