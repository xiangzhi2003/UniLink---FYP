import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_messages.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
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
      await ref
          .read(authServiceProvider)
          .signIn(
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
            LabeledTextField(
              label: 'University email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              hintText: 'you@student.university.edu.my',
              prefixIcon: const Icon(Icons.mail_outline),
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
            LabeledTextField(
              label: 'Password',
              controller: _passwordController,
              obscureText: _obscurePassword,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed:
                    () =>
                        setState(() => _obscurePassword = !_obscurePassword),
              ),
              // Only checks non-empty (not length) — an existing account's
              // password could predate any length rule register.dart enforces.
              validator:
                  (value) =>
                      (value == null || value.isEmpty)
                          ? 'Enter your password'
                          : null,
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
              text:
                  'UniLink is exclusively for verified university students. '
                  'Only .edu.my email addresses are accepted.',
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Sign In',
              icon: Icons.arrow_forward,
              isLoading: _loading,
              onPressed: _login,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: widget.onSwitchToRegister,
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                    children: [
                      const TextSpan(text: 'New student? '),
                      TextSpan(
                        text: 'Create account',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
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
