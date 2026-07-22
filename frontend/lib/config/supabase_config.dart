// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : supabase_config.dart
// Description     : Initializes and exposes the global Supabase client, loading credentials from .env.
// First Written on: Friday,03-Jul-2026
// Edited on       : Saturday,04-Jul-2026

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads `.env` and initializes the Supabase client. Call once from `main()`
/// before `runApp`.
Future<void> initSupabase() async {
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
    // Default (PKCE) requires completing the auth link on the same
    // device/browser that requested it — a "code verifier" is stored
    // locally and the link can't be verified without it. We need reset
    // links to work when opened on a different device than the one that
    // requested them, so use the implicit flow instead, which doesn't have
    // that same-device requirement.
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.implicit),
  );
}

SupabaseClient get supabase => Supabase.instance.client;

/// The deployed web app's URL — used as the password-reset redirect target.
/// Configurable via `.env` instead of hardcoded, so it can differ between
/// local dev and deployed environments.
String get webAppUrl => dotenv.env['WEB_APP_URL']!;
