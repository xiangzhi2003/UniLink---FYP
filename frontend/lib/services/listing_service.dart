import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/listing.dart';

class ListingService {
  static const _bucket = 'listing-images';

  /// Uploads each picked image to `listing-images/<userId>/<name>` and
  /// returns their public URLs, in order. Reads bytes so the same code path
  /// works on both mobile and web.
  Future<List<String>> uploadListingImages(String userId, List<XFile> images) async {
    final urls = <String>[];
    final stamp = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < images.length; i++) {
      final image = images[i];
      final ext = image.name.contains('.') ? image.name.split('.').last : 'jpg';
      final path = '$userId/${stamp}_$i.$ext';
      final bytes = await image.readAsBytes();

      await supabase.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: image.mimeType ?? 'image/jpeg'),
          );
      urls.add(supabase.storage.from(_bucket).getPublicUrl(path));
    }

    return urls;
  }

  /// Inserts the listing and returns its new id (so the caller can index it
  /// for semantic search).
  Future<String> createListing(Listing listing) async {
    final row =
        await supabase.from('listings').insert(listing.toInsertJson()).select('id').single();
    return row['id'] as String;
  }

  /// Fetch active listings for the given ids, preserving the order of [ids]
  /// (used to keep RAG search results in relevance order).
  Future<List<Listing>> fetchListingsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await supabase
        .from('listings')
        .select('*, profiles(full_name)')
        .inFilter('id', ids)
        .eq('status', 'active');
    final byId = {
      for (final row in rows as List<dynamic>)
        (row as Map<String, dynamic>)['id'] as String: Listing.fromJson(row),
    };
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// Active listings for the browse grid, newest first, with the seller's
  /// name joined in. Optional category filter and keyword search (basic
  /// ilike on title/description — the temporary fallback until Sprint 3C's
  /// RAG search replaces it).
  Future<List<Listing>> fetchActiveListings({
    String? category,
    String? query,
    String? listingType,
  }) async {
    var request = supabase
        .from('listings')
        .select('*, profiles(full_name)')
        .eq('status', 'active');

    if (category != null) {
      request = request.eq('category', category);
    }
    if (listingType != null) {
      request = request.eq('listing_type', listingType);
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim();
      request = request.or('title.ilike.%$q%,description.ilike.%$q%');
    }

    final rows = await request.order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => Listing.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// A seller's active listings, for the read-only seller profile screen.
  Future<List<Listing>> fetchListingsBySeller(String sellerId) async {
    final rows = await supabase
        .from('listings')
        .select('*, profiles(full_name)')
        .eq('seller_id', sellerId)
        .eq('status', 'active')
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => Listing.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// All of one student's own listings regardless of status, newest first.
  Future<List<Listing>> fetchMyListings(String userId) async {
    final rows = await supabase
        .from('listings')
        .select('*, profiles(full_name)')
        .eq('seller_id', userId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => Listing.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateListing(String id, Listing listing) async {
    await supabase.from('listings').update(listing.toUpdateJson()).eq('id', id);
  }

  Future<void> updateStatus(String id, String status) async {
    await supabase.from('listings').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Deletes the row, then best-effort removes its images from storage —
  /// a failed image cleanup shouldn't block the delete the user asked for.
  Future<void> deleteListing(Listing listing) async {
    await supabase.from('listings').delete().eq('id', listing.id!);

    final paths = listing.imageUrls
        .where((url) => url.contains('/$_bucket/'))
        .map((url) => Uri.decodeComponent(url.split('/$_bucket/').last))
        .toList();
    if (paths.isNotEmpty) {
      try {
        await supabase.storage.from(_bucket).remove(paths);
      } catch (_) {
        // Orphaned images are harmless; ignore.
      }
    }
  }
}
