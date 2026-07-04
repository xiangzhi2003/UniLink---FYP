import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns a Supabase (or other) exception into a message a student can act on,
/// instead of the raw `AuthException(message: ..., statusCode: ..., code: ...)`
/// text.
String friendlyErrorMessage(Object error) {
  if (error is AuthException) {
    switch (error.code) {
      case 'user_already_exists':
      case 'email_exists':
        return 'This email is already registered — try logging in instead.';
      case 'weak_password':
        return 'Password must be at least 6 characters.';
      case 'email_not_confirmed':
        return 'Please confirm your email before logging in.';
      case 'over_email_send_rate_limit':
        return 'Too many attempts — please wait a minute and try again.';
      case 'validation_failed':
        return "That doesn't look like a valid email address.";
      case 'otp_expired':
        return 'This link has expired or was already used — request a new one.';
    }

    if (error.message.toLowerCase().contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }

    // Unmatched codes fall through to the generic message below rather than
    // surfacing Supabase's raw internal text to the user.
  }

  if (error is PostgrestException) {
    // Same reasoning — don't leak raw Postgres/Postgrest error text.
  }

  return 'Something went wrong. Please try again.';
}
