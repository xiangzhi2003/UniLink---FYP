import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/report.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/error_messages.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';

/// The reports/disputes queue: everything users have flagged, open first.
class AdminReportsTab extends ConsumerStatefulWidget {
  const AdminReportsTab({super.key});

  @override
  ConsumerState<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends ConsumerState<AdminReportsTab> {
  late Future<List<Report>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(backendServiceProvider).fetchAdminReports();
  }

  void _reload() {
    setState(() {
      _future = ref.read(backendServiceProvider).fetchAdminReports();
    });
  }

  Future<void> _resolve(Report report) async {
    setState(() => _busy = true);
    try {
      await ref.read(backendServiceProvider).adminResolveReport(report.id);
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

  String _date(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AsyncStateView<List<Report>>(
      future: _future,
      onRetry: _reload,
      loadingSkeleton: const Center(child: CircularProgressIndicator()),
      isEmpty: (reports) => reports.isEmpty,
      emptyState: const EmptyState(
        icon: Icons.flag_outlined,
        title: 'No reports',
        message: 'User-filed reports on listings and users show up here.',
      ),
      builder: (context, reports) {
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final target = report.listingTitle != null
                  ? 'Listing: ${report.listingTitle}'
                  : report.reportedUserName != null
                      ? 'User: ${report.reportedUserName}'
                      : 'Unknown target';
              final isOpen = report.status == 'open';

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              target,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          StatusChip(
                            label: isOpen ? 'Open' : 'Resolved',
                            variant: isOpen ? StatusVariant.warning : StatusVariant.success,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text('Reason: ${report.reason}'),
                      const SizedBox(height: 2),
                      Text(
                        'Reported by ${report.reporterName ?? 'Unknown'} · ${_date(report.createdAt)}',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                      ),
                      if (isOpen) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _busy ? null : () => _resolve(report),
                            child: const Text('Mark resolved'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
