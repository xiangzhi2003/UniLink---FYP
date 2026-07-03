import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/home/home_shell.dart';

enum _AuthView { welcome, login, register, forgotPassword }

/// Picks the right screen based on auth state:
/// loading -> welcome -> (login|register) -> complete profile -> home.
///
/// Email confirmation is intentionally not required — registering creates a
/// usable account immediately. The `.edu.my` domain check (validators.dart)
/// is the only gate on who can join.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  _AuthView _view = _AuthView.welcome;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    // Reset back to the welcome landing page on sign-out, instead of
    // reopening whichever of login/register was last shown.
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (previous, next) {
      if (next.valueOrNull?.event == AuthChangeEvent.signedOut) {
        setState(() => _view = _AuthView.welcome);
      }
    });

    return authState.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Auth error: $error'))),
      data: (state) {
        // Tapping the reset-password link opens the app with a temporary
        // recovery session — route straight to the set-new-password screen.
        // Once updatePassword succeeds the next auth event isn't
        // passwordRecovery, so this stops applying and we fall through.
        if (state.event == AuthChangeEvent.passwordRecovery) {
          return const ResetPasswordScreen();
        }

        final user = state.session?.user;

        if (user == null) {
          switch (_view) {
            case _AuthView.welcome:
              return WelcomeScreen(
                onGetStarted: () => setState(() => _view = _AuthView.register),
                onLogin: () => setState(() => _view = _AuthView.login),
              );
            case _AuthView.register:
              return RegisterScreen(
                onSwitchToLogin: () => setState(() => _view = _AuthView.login),
                onBack: () => setState(() => _view = _AuthView.welcome),
              );
            case _AuthView.login:
              return LoginScreen(
                onSwitchToRegister: () => setState(() => _view = _AuthView.register),
                onForgotPassword: () => setState(() => _view = _AuthView.forgotPassword),
                onBack: () => setState(() => _view = _AuthView.welcome),
              );
            case _AuthView.forgotPassword:
              return ForgotPasswordScreen(
                onBack: () => setState(() => _view = _AuthView.login),
              );
          }
        }

        final profileAsync = ref.watch(currentProfileProvider);
        return profileAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(body: Center(child: Text('Profile error: $error'))),
          data: (profile) => profile == null ? const EditProfileScreen() : const HomeShell(),
        );
      },
    );
  }
}
