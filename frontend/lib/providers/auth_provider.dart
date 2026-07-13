import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final profileServiceProvider = Provider<ProfileService>((ref) => ProfileService());

/// True while register_screen.dart's signUp()+upsertProfile() sequence is
/// running. signUp() creates a real session immediately, before the profile
/// row is written — without this flag, AuthGate would react to that session
/// the instant it appears and briefly show an empty "complete your profile"
/// screen (currentProfileProvider correctly finds nothing yet), even though
/// the user just finished filling that in. AuthGate holds a loading state
/// instead of deciding anything while this is true.
final isRegisteringProvider = StateProvider<bool>((ref) => false);

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

/// Any user's `profiles` row by id — used by the read-only seller profile
/// screen, unlike [currentProfileProvider] which is always the signed-in user.
final profileByIdProvider =
    FutureProvider.family<UserProfile?, String>((ref, userId) async {
  return ref.watch(profileServiceProvider).getProfile(userId);
});
