// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : main.dart
// Description     : Application entry point -- initializes Supabase, sets up theming, and launches AuthGate as the root widget.
// First Written on: Friday,03-Jul-2026
// Edited on       : Tuesday,14-Jul-2026

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/supabase_config.dart';
import 'providers/theme_provider.dart';
import 'screens/web/web_landing_page.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Must be read before initSupabase(): Supabase's implicit auth flow strips
  // the recovery tokens out of the URL (history.replaceState) as part of
  // Supabase.initialize(), so checking Uri.base afterwards would always see
  // it already cleared.
  final isRecoveryLink = kIsWeb && Uri.base.fragment.contains('type=recovery');
  await initSupabase();
  runApp(ProviderScope(child: MyApp(isRecoveryLink: isRecoveryLink)));
}

class MyApp extends ConsumerWidget {
  final bool isRecoveryLink;

  const MyApp({super.key, required this.isRecoveryLink});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'UniLink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: (kIsWeb && !isRecoveryLink) ? const WebLandingPage() : const AuthGate(),
    );
  }
}
