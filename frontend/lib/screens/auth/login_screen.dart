import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_messages.dart';
import '../../utils/validators.dart';
import '../../widgets/auth_header_scaffold.dart';
import '../../widgets/info_banner.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback onSwitchToRegister;
  final VoidCallback onForgotPassword;
  final VoidCallback? onBack;

  const LoginScreen({
    super.key,
    required this.onSwitchToRegister,
    required this.onForgotPassword,
    this.onBack,
  });

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

    try {
      await ref.read(authServiceProvider).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
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
            Semantics(
              label: 'University email',
              child: Text('UNIVERSITY EMAIL', style: Theme.of(context).textTheme.labelLarge),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'you@student.university.edu.my',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your email';
                }
                if (!isValidUniversityEmail(value)) {
                  return 'Only .edu.my university emails are allowed';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            Semantics(
              label: 'Password',
              child: Text('PASSWORD', style: Theme.of(context).textTheme.labelLarge),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              // Only checks non-empty (not length) — an existing account's
              // password could predate any length rule register.dart enforces.
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Enter your password' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onForgotPassword,
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 8),
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
