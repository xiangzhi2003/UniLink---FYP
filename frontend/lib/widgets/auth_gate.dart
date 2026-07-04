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
import '../utils/recovery_flag.dart';

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
  //
  // This also has to survive a full page close/reopen, not just switching
  // tabs — opening a recovery link authenticates the browser immediately,
  // before any new password is typed, so a fresh app instance would
  // otherwise see what looks like a completely normal signed-in session
  // and show home. `recovery_flag.dart` persists it locally so a fresh
  // load still knows to gate on the reset screen.
  bool _inPasswordRecovery = false;
  bool _checkingPersistedRecoveryFlag = true;

  @override
  void initState() {
    super.initState();
    _loadPersistedRecoveryFlag();
  }

  Future<void> _loadPersistedRecoveryFlag() async {
    final pending = await isRecoveryPending();
    if (mounted) {
      setState(() {
        _inPasswordRecovery = pending;
        _checkingPersistedRecoveryFlag = false;
      });
    }
  }

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
        clearRecoveryPending();
      } else if (event == AuthChangeEvent.passwordRecovery) {
        setState(() => _inPasswordRecovery = true);
        markRecoveryPending();
      } else if (event == AuthChangeEvent.userUpdated && _inPasswordRecovery) {
        // updatePassword() succeeded — release the gate.
        setState(() => _inPasswordRecovery = false);
        clearRecoveryPending();
      }
    });

    if (_checkingPersistedRecoveryFlag) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
        final user = state.session?.user;

        // Tapping the reset-password link (in this tab, another tab of the
        // same browser, or a fresh reload) opens a recovery session — route
        // straight to the set-new-password screen until updatePassword()
        // completes. Guard against a stale persisted flag with no real
        // session behind it (e.g. it expired) by also requiring `user`.
        if (_inPasswordRecovery && user != null) {
          return const ResetPasswordScreen();
        }
        if (_inPasswordRecovery && user == null) {
          _inPasswordRecovery = false;
          clearRecoveryPending();
        }

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
