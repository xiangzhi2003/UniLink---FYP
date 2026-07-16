import '../config/supabase_config.dart';

/// User-side reporting: plain insert into the `reports` table (RLS only
/// allows inserting as yourself). Reading/resolving reports is admin-only,
/// via the backend -- there's deliberately no fetch here.
class ReportService {
  Future<void> submitReport({
    String? listingId,
    String? reportedUserId,
    required String reason,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('reports').insert({
      'reporter_id': userId,
      'listing_id': listingId,
      'reported_user_id': reportedUserId,
      'reason': reason,
    });
  }
}
