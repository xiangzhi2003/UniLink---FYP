import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_messages.dart';
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
              email: user.email!,
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
      subtitle: "You're verified — add a couple of details before you start trading",
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FULL NAME', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline)),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 20),
            Text('UNIVERSITY', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextFormField(
              controller: _universityController,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.school_outlined)),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Enter your university' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save and continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
