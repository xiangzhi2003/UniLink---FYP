import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/listing.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';

class _Msg {
  final bool fromMe;
  final String text;
  const _Msg(this.text, {required this.fromMe});
}

/// AI chatbot scoped to one specific listing — pushed as its own screen from
/// [ListingDetailScreen]'s "Ask AI about this item" button. Answers using
/// both the listing's real details and the model's own general knowledge.
/// Pure Q&A — deliberately doesn't surface other listings.
class ListingChatScreen extends ConsumerStatefulWidget {
  final Listing listing;

  const ListingChatScreen({super.key, required this.listing});

  @override
  ConsumerState<ListingChatScreen> createState() => _ListingChatScreenState();
}

class _ListingChatScreenState extends ConsumerState<ListingChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_Msg>[];
  final List<({String role, String text})> _history = [];
  bool _sending = false;

  late final List<String> _suggestions = [
    'Is this a good deal?',
    'How do I use this?',
    'Any tips or things to know?',
  ];

  Future<void> _send(String message) async {
    final q = message.trim();
    if (q.isEmpty || _sending) return;
    _controller.clear();
    setState(() {
      _messages.add(_Msg(q, fromMe: true));
      _sending = true;
    });
    _scrollToBottom();

    try {
      final reply = await ref.read(backendServiceProvider).askAboutListing(
            listingId: widget.listing.id!,
            message: q,
            history: _history,
          );

      setState(() {
        _messages.add(_Msg(reply, fromMe: false));
        _history.add((role: 'user', text: q));
        _history.add((role: 'assistant', text: reply));
        if (_history.length > 6) {
          _history.removeRange(0, _history.length - 6);
        }
      });
    } catch (e) {
      setState(() {
        _messages.add(_Msg(friendlyErrorMessage(e), fromMe: false));
      });
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listing.title, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _greeting(context)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _bubble(context, _messages[index]),
                  ),
          ),
          if (_sending) const LinearProgressIndicator(minHeight: 2),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: const InputDecoration(
                        hintText: 'Ask about this item...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : () => _send(_controller.text),
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: const Color(0xFF3A2200),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _greeting(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Ask me anything about "${widget.listing.title}"!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final s in _suggestions)
                  ActionChip(label: Text(s), onPressed: () => _send(s)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context, _Msg msg) {
    final scheme = Theme.of(context).colorScheme;
    if (msg.fromMe) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(msg.text, style: const TextStyle(color: Colors.white)),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(msg.text, style: TextStyle(color: scheme.onSurface)),
      ),
    );
  }
}
