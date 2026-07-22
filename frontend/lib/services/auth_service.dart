// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : auth_service.dart
// Description     : Wraps Supabase Auth calls for sign up, sign in, sign out and auth-state changes.
// First Written on: Friday,03-Jul-2026
// Edited on       : Saturday,04-Jul-2026

import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class AuthService {
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  User? get currentUser => supabase.auth.currentSession?.user;

  /// Email confirmation is off (Supabase Auth settings) — signing up creates
  /// a usable session immediately. The `.edu.my` domain check happens
  /// client-side before this is ever called (see validators.dart).
  Future<void> signUp({required String email, required String password}) async {
    await supabase.auth.signUp(email: email, password: password);
  }

  Future<void> signIn({required String email, required String password}) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  /// Sends a password-reset email. Supabase never reveals whether the email
  /// is actually registered here — it "succeeds" either way — so the UI
  /// shows one generic confirmation message regardless.
  Future<void> sendPasswordResetEmail(String email) async {
    await supabase.auth.resetPasswordForEmail(email, redirectTo: webAppUrl);
  }

  /// Sets a new password using the temporary session established after the
  /// user taps the link from [sendPasswordResetEmail].
  Future<void> updatePassword(String newPassword) async {
    await supabase.auth.updateUser(UserAttributes(password: newPassword));
  }
}
