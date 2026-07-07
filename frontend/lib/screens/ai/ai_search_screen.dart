import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/listing.dart';
import '../../providers/listing_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/colored_header.dart';
import '../../widgets/listing_card.dart';
import '../marketplace/listing_detail_screen.dart';

class _Msg {
  final bool fromMe;
  final String? text;
  final List<Listing>? results;
  const _Msg.user(this.text) : fromMe = true, results = null;
  const _Msg.results(this.text, this.results) : fromMe = false;
}

/// Chat-style search screen, styled like the reference's AI Concierge.
/// Wired to plain keyword search for now (Sprint 3C's real Gemini/Pinecone
/// semantic search is parked) — this screen exists so real RAG can be
/// dropped in later without disturbing the nav.
class AiSearchScreen extends ConsumerStatefulWidget {
  const AiSearchScreen({super.key});

  @override
  ConsumerState<AiSearchScreen> createState() => _AiSearchScreenState();
}

class _AiSearchScreenState extends ConsumerState<AiSearchScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_Msg>[];
  bool _searching = false;

  static const _suggestions = [
    'Cheap calculator for engineering',
    'Textbooks for first year',
    'Something to rent for an event',
  ];

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty || _searching) return;
    _controller.clear();
    setState(() {
      _messages.add(_Msg.user(q));
      _searching = true;
    });
    _scrollToBottom();

    try {
      final results = await ref
          .read(listingServiceProvider)
          .fetchActiveListings(query: q);
      setState(() {
        _messages.add(
          _Msg.results(
            results.isEmpty
                ? "I couldn't find anything for \"$q\" — try different words?"
                : "Here's what I found for \"$q\":",
            results,
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _searching = false);
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
    // No own Scaffold — hosted inside HomeShell's ambient Scaffold, same as
    // the other tab bodies (Browse/Chat/Profile).
    return Column(
      children: [
        ColoredHeader(
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                'AI Search',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              _messages.isEmpty
                  ? _greeting(context)
                  : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder:
                        (context, index) => _bubble(context, _messages[index]),
                  ),
        ),
        if (_searching) const LinearProgressIndicator(minHeight: 2),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _search,
                    decoration: const InputDecoration(
                      hintText: 'Describe what you need...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed:
                      _searching ? null : () => _search(_controller.text),
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
    );
  }

  Widget _greeting(BuildContext context) {
    return Center(
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
              'What are you looking for?',
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
                  ActionChip(label: Text(s), onPressed: () => _search(s)),
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
          child: Text(msg.text!, style: const TextStyle(color: Colors.white)),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.text ?? '', style: TextStyle(color: scheme.onSurface)),
            if (msg.results != null && msg.results!.isNotEmpty) ...[
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.72,
                ),
                itemCount: msg.results!.length,
                itemBuilder: (context, i) {
                  final listing = msg.results![i];
                  return ListingCard(
                    listing: listing,
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => ListingDetailScreen(listing: listing),
                          ),
                        ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
