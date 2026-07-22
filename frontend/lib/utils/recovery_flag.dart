// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : recovery_flag.dart
// Description     : Persists a flag marking an in-progress password reset across app reloads.
// First Written on: Saturday,04-Jul-2026
// Edited on       : Saturday,04-Jul-2026

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers "a password reset was started but not finished" across a full
/// page reload — not just while the tab/app instance stays open. A recovery
/// link authenticates the browser as a side effect the moment it's opened,
/// before the user ever types a new password; without this, closing and
/// reopening the app would just show the signed-in home screen instead of
/// the reset form, since the fresh load has no memory of the in-progress
/// recovery, only a session that now looks like a normal one.
const _key = 'unilink_password_recovery_pending';

Future<void> markRecoveryPending() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_key, true);
}

Future<void> clearRecoveryPending() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_key);
}

Future<bool> isRecoveryPending() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_key) ?? false;
}
