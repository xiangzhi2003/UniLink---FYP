// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : admin_knowledge_tab.dart
// Description     : Admin tab for managing RAG knowledge-base documents (list/create/delete).
// First Written on: Friday,17-Jul-2026
// Edited on       : Friday,17-Jul-2026

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/knowledge_doc.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/error_messages.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/empty_state.dart';
import 'add_knowledge_doc_screen.dart';

/// RAG knowledge base management: reference docs that feed the per-listing
/// AI chatbot's retrieval step, on top of a listing's own data.
class AdminKnowledgeTab extends ConsumerStatefulWidget {
  const AdminKnowledgeTab({super.key});

  @override
  ConsumerState<AdminKnowledgeTab> createState() => _AdminKnowledgeTabState();
}

class _AdminKnowledgeTabState extends ConsumerState<AdminKnowledgeTab> {
  late Future<List<KnowledgeDoc>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(backendServiceProvider).fetchKnowledgeDocs();
  }

  void _reload() {
    setState(() {
      _future = ref.read(backendServiceProvider).fetchKnowledgeDocs();
    });
  }

  Future<void> _add() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddKnowledgeDocScreen()),
    );
    if (created == true) _reload();
  }

  Future<void> _delete(KnowledgeDoc doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this doc?'),
        content: Text('"${doc.title}" will no longer be usable by the AI chatbot.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(backendServiceProvider).deleteKnowledgeDoc(doc.id);
      if (mounted) _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: AsyncStateView<List<KnowledgeDoc>>(
        future: _future,
        onRetry: _reload,
        loadingSkeleton: const Center(child: CircularProgressIndicator()),
        isEmpty: (docs) => docs.isEmpty,
        emptyState: const EmptyState(
          icon: Icons.menu_book_outlined,
          title: 'No knowledge docs yet',
          message: 'Add reference info the AI chatbot can draw on, like '
              'campus policies or how the QR handshake works.',
        ),
        builder: (context, docs) {
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 88,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc.title,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                doc.body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: Icon(Icons.delete_outline, color: scheme.error),
                          onPressed: _busy ? null : () => _delete(doc),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
