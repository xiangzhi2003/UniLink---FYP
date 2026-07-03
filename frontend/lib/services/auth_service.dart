import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class AuthService {
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  User? get currentUser => supabase.auth.currentSession?.user;

  bool get isEmailConfirmed => currentUser?.emailConfirmedAt != null;

  /// `emailRedirectTo` points at the deployed web app (Railway). Tapping the
  /// confirmation link on any device opens the real running app there, and
  /// `supabase_flutter` picks up the confirmation tokens from the URL and
  /// completes sign-in automatically — works everywhere, not just one phone.
  Future<void> signUp({required String email, required String password}) async {
    await supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'https://unilink-fyp-production.up.railway.app',
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  Future<void> resendConfirmationEmail(String email) async {
    await supabase.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: 'https://unilink-fyp-production.up.railway.app',
    );
  }

  /// Re-fetches the session from Supabase so `isEmailConfirmed` reflects
  /// whether the user has clicked the confirmation link yet.
  Future<void> refreshSession() async {
    await supabase.auth.refreshSession();
  }
}
