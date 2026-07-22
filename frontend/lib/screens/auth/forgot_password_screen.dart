// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : forgot_password_screen.dart
// Description     : Screen for requesting a password-reset email.
// First Written on: Saturday,04-Jul-2026
// Edited on       : Tuesday,07-Jul-2026

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_messages.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_header_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const ForgotPasswordScreen({super.key, required this.onBack});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _sent = false;

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).sendPasswordResetEmail(
            _emailController.text.trim(),
          );
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthHeaderScaffold(
      title: 'Reset your password',
      subtitle: "Enter your university email and we'll send you a reset link",
      onBack: widget.onBack,
      child: _sent ? _buildSentMessage(context) : _buildForm(context),
    );
  }

  Widget _buildSentMessage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "If an account exists for ${_emailController.text.trim()}, "
          "we've sent a reset link. Check your inbox.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        SecondaryButton(
          label: 'Back to log in',
          onPressed: widget.onBack,
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
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
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Send reset link',
            isLoading: _loading,
            onPressed: _sendResetLink,
          ),
        ],
      ),
    );
  }
}
