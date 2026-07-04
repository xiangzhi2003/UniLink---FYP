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
import '../utils/error_messages.dart';

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

  // Sticky, not just "was the last event passwordRecovery" — a recovery
  // link opened in one tab is broadcast to every other tab of the same
  // browser (Supabase syncs session state across tabs), and a routine
  // token refresh can follow shortly after. Checking only the latest event
  // would let that refresh bump a tab that's mid-recovery straight to the
  // signed-in home screen before the password was ever actually changed.
  bool _inPasswordRecovery = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    ref.listen<AsyncValue<AuthState>>(authStateProvider, (previous, next) {
      final event = next.valueOrNull?.event;
      if (event == AuthChangeEvent.signedOut) {
        // Reset back to the welcome landing page on sign-out, instead of
        // reopening whichever of login/register was last shown.
        setState(() {
          _view = _AuthView.welcome;
          _inPasswordRecovery = false;
        });
      } else if (event == AuthChangeEvent.passwordRecovery) {
        setState(() => _inPasswordRecovery = true);
      } else if (event == AuthChangeEvent.userUpdated && _inPasswordRecovery) {
        // updatePassword() succeeded — release the gate.
        setState(() => _inPasswordRecovery = false);
      }
    });

    return authState.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(friendlyErrorMessage(error), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _view = _AuthView.welcome);
                    ref.invalidate(authStateProvider);
                  },
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (state) {
        // Tapping the reset-password link (in this tab or any other tab of
        // the same browser) opens a recovery session — route straight to
        // the set-new-password screen until updatePassword() completes.
        if (_inPasswordRecovery) {
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
          error: (error, _) => Scaffold(body: Center(child: Text(friendlyErrorMessage(error)))),
          data: (profile) => profile == null ? const EditProfileScreen() : const HomeShell(),
        );
      },
    );
  }
}
