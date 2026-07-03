import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class AuthService {
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  User? get currentUser => supabase.auth.currentSession?.user;

  bool get isEmailConfirmed => currentUser?.emailConfirmedAt != null;

  /// `emailRedirectTo` points at the app's own deep link (registered in
  /// AndroidManifest.xml). Tapping the confirmation email on the same phone
  /// that has the app installed opens it directly, and `supabase_flutter`
  /// completes sign-in automatically — no separate page, no manual re-login.
  /// Only works when the link is opened on that same phone.
  Future<void> signUp({required String email, required String password}) async {
    await supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'unilink://login-callback',
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
      emailRedirectTo: 'unilink://login-callback',
    );
  }

  /// Re-fetches the session from Supabase so `isEmailConfirmed` reflects
  /// whether the user has clicked the confirmation link yet.
  Future<void> refreshSession() async {
    await supabase.auth.refreshSession();
  }
}
