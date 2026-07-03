import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_messages.dart';
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
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: widget.onBack,
            child: const Text('Back to log in'),
          ),
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
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _sendResetLink,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send reset link'),
            ),
          ),
        ],
      ),
    );
  }
}
