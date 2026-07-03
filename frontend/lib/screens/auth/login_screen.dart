import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_messages.dart';
import '../../widgets/auth_header_scaffold.dart';
import '../../widgets/info_banner.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback onSwitchToRegister;
  final VoidCallback? onBack;

  const LoginScreen({super.key, required this.onSwitchToRegister, this.onBack});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _emailController.text.trim();

    try {
      await ref.read(authServiceProvider).signIn(
            email: email,
            password: _passwordController.text,
          );
    } catch (e) {
      final message = isInvalidCredentialsError(e)
          ? await _describeInvalidCredentials(email)
          : friendlyErrorMessage(e);
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Supabase returns one generic error for both "no such account" and
  /// "wrong password" (an anti-enumeration measure). We ask the backend
  /// which case it is so the message can be specific; if that check itself
  /// fails (e.g. backend unreachable), fall back to the generic message.
  Future<String> _describeInvalidCredentials(String email) async {
    try {
      final exists = await ref.read(backendServiceProvider).checkEmailExists(email);
      return exists
          ? 'Incorrect password — try again.'
          : 'No account found with this email — check the address or register.';
    } catch (_) {
      return 'Incorrect email or password.';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthHeaderScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in with your .edu.my email',
      onBack: widget.onBack,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UNIVERSITY EMAIL', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'you@student.university.edu.my',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Enter your email' : null,
            ),
            const SizedBox(height: 20),
            Text('PASSWORD', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Enter your password' : null,
            ),
            const SizedBox(height: 20),
            const InfoBanner(
              text: 'UniLink is exclusively for verified university students. '
                  'Only .edu.my email addresses are accepted.',
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Sign In'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: widget.onSwitchToRegister,
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(color: Color(0xFF5B6472), fontSize: 14),
                    children: [
                      TextSpan(text: 'New student? '),
                      TextSpan(
                        text: 'Create account',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F2A4A)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
