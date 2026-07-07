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
  await initSupabase();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    // Supabase's implicit auth flow appends `type=recovery` to the URL fragment
    // when a password-reset link is opened — let that still reach AuthGate
    // (which already knows how to show ResetPasswordScreen) instead of the
    // marketing landing page.
    final isRecoveryLink = kIsWeb && Uri.base.fragment.contains('type=recovery');
    return MaterialApp(
      title: 'UniLink',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: (kIsWeb && !isRecoveryLink) ? const WebLandingPage() : const AuthGate(),
    );
  }
}
