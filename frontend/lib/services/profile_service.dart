import '../config/supabase_config.dart';
import '../models/user_profile.dart';

class ProfileService {
  Future<UserProfile?> getProfile(String userId) async {
    final row = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;
    return UserProfile.fromJson(row);
  }

  Future<void> upsertProfile(UserProfile profile) async {
    await supabase.from('profiles').upsert(profile.toJson());
  }
}
