import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_messages.dart';
import '../../widgets/auth_scaffold.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _loading = false;
  String? _message;

  Future<void> _resend() async {
    final email = ref.read(authServiceProvider).currentUser?.email;
    if (email == null) return;

    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).resendConfirmationEmail(email);
      setState(() => _message = 'Confirmation email sent again — check your inbox.');
    } catch (e) {
      setState(() => _message = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkVerified() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await ref.read(authServiceProvider).refreshSession();
      // Refreshing the session updates currentUser in place; re-evaluate
      // the auth stream so AuthGate picks up the new emailConfirmedAt.
      ref.invalidate(authStateProvider);
      if (!ref.read(authServiceProvider).isEmailConfirmed) {
        setState(() => _message = "Not confirmed yet — tap the link in your inbox first.");
      }
    } catch (e) {
      setState(() => _message = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authServiceProvider).currentUser?.email ?? 'your email';

    return AuthScaffold(
      title: 'Check your inbox',
      subtitle: 'We sent a confirmation link to $email. Tap it, then come back here.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_message != null) ...[
            Text(_message!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed: _loading ? null : _checkVerified,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text("I've confirmed — Continue"),
          ),
          TextButton(
            onPressed: _loading ? null : _resend,
            child: const Text('Resend email'),
          ),
          TextButton(
            onPressed: _signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
