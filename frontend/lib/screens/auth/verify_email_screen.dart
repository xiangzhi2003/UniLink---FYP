import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../widgets/auth_header_scaffold.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String email;

  /// True when there's an active (but unconfirmed) session — reachable if
  /// "Confirm email" is off, or between confirming and re-logging-in. False
  /// right after registering, when Supabase hasn't created a session yet.
  final bool hasSession;

  final VoidCallback? onBackToLogin;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.hasSession,
    this.onBackToLogin,
  });

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _loading = false;
  String? _message;

  Future<void> _resend() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await ref.read(authServiceProvider).resendConfirmationEmail(widget.email);
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
    return AuthHeaderScaffold(
      title: 'Check your inbox',
      subtitle: 'We sent a confirmation link to ${widget.email}',
      onBack: widget.hasSession ? null : widget.onBackToLogin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_unread_outlined, size: 32, color: AppColors.gold),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Tap the link in that email, then come back here — this screen will '
            'move on by itself once your account is confirmed.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          if (widget.hasSession)
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
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loading ? null : _resend,
            child: const Text('Resend email'),
          ),
          TextButton(
            onPressed: widget.hasSession ? _signOut : widget.onBackToLogin,
            child: Text(widget.hasSession ? 'Sign out' : 'Back to log in'),
          ),
        ],
      ),
    );
  }
}
