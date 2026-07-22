// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : register_screen.dart
// Description     : Two-step registration wizard (account details, then profile) gated to .edu.my university emails.
// First Written on: Friday,03-Jul-2026
// Edited on       : Tuesday,07-Jul-2026

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_messages.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_header_scaffold.dart';
import '../../widgets/info_banner.dart';
import '../../widgets/step_progress_indicator.dart';

/// Two-step registration: account details, then profile — the account isn't
/// created in Supabase until both steps are filled in and "Register" is
/// tapped, so nobody ends up with an account but no profile.
class RegisterScreen extends ConsumerStatefulWidget {
  final VoidCallback onSwitchToLogin;
  final VoidCallback? onBack;

  const RegisterScreen({super.key, required this.onSwitchToLogin, this.onBack});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  int _step = 0;

  final _accountFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _profileFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _universityController = TextEditingController();

  bool _loading = false;
  String? _error;

  void _goToProfileStep() {
    if (!_accountFormKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _step = 1;
    });
  }

  Future<void> _register() async {
    if (!_profileFormKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    // signUp() creates a session immediately, before the profile row below
    // is written — this flag tells AuthGate to hold off deciding anything
    // until the whole sequence finishes, so it never shows a momentary
    // empty "complete your profile" screen for a profile that's about to
    // exist anyway.
    ref.read(isRegisteringProvider.notifier).state = true;

    try {
      await ref.read(authServiceProvider).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      final user = ref.read(authServiceProvider).currentUser;
      if (user != null) {
        await ref.read(profileServiceProvider).upsertProfile(
              UserProfile(
                id: user.id,
                email: (user.email ?? _emailController.text.trim()).toLowerCase(),
                fullName: _nameController.text.trim(),
                university: _universityController.text.trim(),
              ),
            );
        ref.invalidate(currentProfileProvider);
      }
    } catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      ref.read(isRegisteringProvider.notifier).state = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _universityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _step == 0 ? _buildAccountStep(context) : _buildProfileStep(context);
  }

  Widget _buildAccountStep(BuildContext context) {
    return AuthHeaderScaffold(
      title: 'Create your account',
      subtitle: 'Only students with a university email can join',
      onBack: widget.onBack,
      child: Form(
        key: _accountFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StepProgressIndicator(currentStep: _step, totalSteps: 2),
            const SizedBox(height: 20),
            LabeledTextField(
              label: 'University email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              hintText: 'you@student.university.edu.my',
              prefixIcon: const Icon(Icons.mail_outline),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your university email';
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
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (value) {
                if (value == null || value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            LabeledTextField(
              label: 'Confirm password',
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Re-enter your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            const InfoBanner(
              text: 'UniLink is exclusively for verified university students. '
                  'Only .edu.my email addresses are accepted.',
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Next',
              icon: Icons.arrow_forward,
              onPressed: _goToProfileStep,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: widget.onSwitchToLogin,
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'Sign in',
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

  Widget _buildProfileStep(BuildContext context) {
    return AuthHeaderScaffold(
      title: 'Complete your profile',
      subtitle: 'Just a couple of details before your account is created',
      onBack: () => setState(() {
        _error = null;
        _step = 0;
      }),
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StepProgressIndicator(currentStep: _step, totalSteps: 2),
            const SizedBox(height: 20),
            LabeledTextField(
              label: 'Full name',
              controller: _nameController,
              prefixIcon: const Icon(Icons.person_outline),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 20),
            LabeledTextField(
              label: 'University',
              controller: _universityController,
              prefixIcon: const Icon(Icons.school_outlined),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Enter your university' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Register',
              isLoading: _loading,
              onPressed: _register,
            ),
          ],
        ),
      ),
    );
  }
}
