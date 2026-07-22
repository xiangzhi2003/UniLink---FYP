// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : edit_profile_screen.dart
// Description     : Form for editing the signed-in user's profile details.
// First Written on: Friday,03-Jul-2026
// Edited on       : Tuesday,07-Jul-2026

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_messages.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_header_scaffold.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _universityController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-fill when reached from the Profile screen's "Edit profile" action
    // on an already-complete profile; stays blank for AuthGate's first-time
    // fallback since there's no profile to read yet.
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile != null) {
      _nameController.text = profile.fullName ?? '';
      _universityController.text = profile.university ?? '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(profileServiceProvider).upsertProfile(
            UserProfile(
              id: user.id,
              email: user.email!.toLowerCase(),
              fullName: _nameController.text.trim(),
              university: _universityController.text.trim(),
            ),
          );
      ref.invalidate(currentProfileProvider);
    } catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _universityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthHeaderScaffold(
      title: 'Complete your profile',
      subtitle: 'Just a couple of details before you start trading',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              label: 'Save and continue',
              isLoading: _loading,
              onPressed: _loading ? null : _save,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _loading ? null : () => ref.read(authServiceProvider).signOut(),
                child: const Text('Sign out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
