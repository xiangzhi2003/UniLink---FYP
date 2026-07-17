import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/error_messages.dart';
import '../../widgets/app_button.dart';

/// Full-screen composer for a new RAG knowledge-base doc -- not a modal
/// dialog. A TextField inside a dialog is a confirmed freeze trigger on
/// this project's test device (see reply_to_review_screen.dart), so every
/// text-entry flow in this app uses a pushed screen instead.
/// Pops `true` on a successful submit.
class AddKnowledgeDocScreen extends ConsumerStatefulWidget {
  const AddKnowledgeDocScreen({super.key});

  @override
  ConsumerState<AddKnowledgeDocScreen> createState() => _AddKnowledgeDocScreenState();
}

class _AddKnowledgeDocScreenState extends ConsumerState<AddKnowledgeDocScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _submitting = false;

  bool get _isValid =>
      _titleController.text.trim().isNotEmpty && _bodyController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() => _submitting = true);
    try {
      await ref.read(backendServiceProvider).createKnowledgeDoc(
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Knowledge')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text(
                'Add reference information the AI chatbot can use when '
                'answering student questions (e.g. campus policies, how the '
                'QR handshake works, category-specific safety notes).',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Rental late-return policy',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _bodyController,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  hintText: 'Write the information in plain language...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Save',
                isLoading: _submitting,
                onPressed: _isValid && !_submitting ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
