// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : theme_provider.dart
// Description     : Riverpod provider/notifier persisting the user's System/Light/Dark theme choice.
// First Written on: Tuesday,07-Jul-2026
// Edited on       : Monday,13-Jul-2026

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'theme_mode';

/// Persists the user's System/Light/Dark choice across launches.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    state = switch (saved) {
      'dark' => ThemeMode.dark,
      // 'system' may exist from before the System option was removed —
      // treat it (and anything else unset) as Light.
      _ => ThemeMode.light,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());
