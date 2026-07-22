// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : favorite_service.dart
// Description     : Wraps Supabase queries for adding, removing, and listing a user's favorited listings.
// First Written on: Monday,13-Jul-2026
// Edited on       : Monday,13-Jul-2026

import '../config/supabase_config.dart';
import '../models/listing.dart';

class FavoriteService {
  static const _table = 'favorites';

  Future<Set<String>> fetchFavoriteListingIds(String userId) async {
    final rows = await supabase.from(_table).select('listing_id').eq('user_id', userId);
    return (rows as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)['listing_id'] as String)
        .toSet();
  }

  Future<void> addFavorite(String userId, String listingId) async {
    await supabase.from(_table).insert({'user_id': userId, 'listing_id': listingId});
  }

  Future<void> removeFavorite(String userId, String listingId) async {
    await supabase.from(_table).delete().eq('user_id', userId).eq('listing_id', listingId);
  }

  /// The user's favorited listings, newest-favorited first.
  Future<List<Listing>> fetchFavoriteListings(String userId) async {
    final rows = await supabase
        .from(_table)
        .select('created_at, listings(*, profiles(full_name))')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)['listings'] as Map<String, dynamic>?)
        .where((listing) => listing != null)
        .map((listing) => Listing.fromJson(listing!))
        .toList();
  }
}
