import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/home/home_shell.dart';

enum _AuthView { welcome, login, register }

/// Picks the right screen based on auth + profile state:
/// loading -> welcome -> (login|register) -> verify email -> complete profile -> home.
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

    return authState.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Auth error: $error'))),
      data: (state) {
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
                onBack: () => setState(() => _view = _AuthView.welcome),
              );
          }
        }

        if (user.emailConfirmedAt == null) {
          return const VerifyEmailScreen();
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
