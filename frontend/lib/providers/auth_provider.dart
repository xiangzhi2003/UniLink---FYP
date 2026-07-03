import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final profileServiceProvider = Provider<ProfileService>((ref) => ProfileService());

/// Fires on every Supabase auth event (sign in, sign out, token refresh, ...).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// The current user's `profiles` row, or null if they haven't completed
/// profile setup yet. Re-fetches whenever the signed-in user changes.
final currentProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final authState = ref.watch(authStateProvider).valueOrNull;
  final user = authState?.session?.user;
  if (user == null) return null;

  return ref.watch(profileServiceProvider).getProfile(user.id);
});
