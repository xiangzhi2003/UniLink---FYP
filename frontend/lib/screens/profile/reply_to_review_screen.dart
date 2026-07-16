import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_button.dart';

/// Full-screen text composer for a seller's reply to a review — pushed
/// (not a modal dialog) deliberately: an AlertDialog+TextField combo
/// triggered a real freeze/ANR on tapping "Post" (the keyboard dismissing
/// while a dialog pops in the same frame is a known trouble spot on this
/// project's test device). A normal page-route transition avoids that.
/// Pops with the typed reply text, or null if cancelled.
class ReplyToReviewScreen extends StatefulWidget {
  final String? initialText;

  const ReplyToReviewScreen({super.key, this.initialText});

  @override
  State<ReplyToReviewScreen> createState() => _ReplyToReviewScreenState();
}

class _ReplyToReviewScreenState extends State<ReplyToReviewScreen> {
  late final _controller = TextEditingController(text: widget.initialText ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = (widget.initialText ?? '').isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit reply' : 'Reply to review')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Your reply',
                  hintText: 'Write a public reply...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Post',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
