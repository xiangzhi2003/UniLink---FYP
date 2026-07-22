// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : admin_reports_tab.dart
// Description     : Admin tab showing the queue of user-filed reports/disputes for review and resolution.
// First Written on: Friday,17-Jul-2026
// Edited on       : Friday,17-Jul-2026

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/report.dart';
import '../../providers/listing_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_tokens.dart';
import '../../utils/error_messages.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';
import '../marketplace/listing_detail_screen.dart';
import '../profile/seller_profile_screen.dart';

/// The reports/disputes queue: everything users have flagged, open first.
/// Tapping a report jumps to the actual reported listing or user profile.
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

  Future<void> _openTarget(Report report) async {
    if (report.reportedUserId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SellerProfileScreen(
            sellerId: report.reportedUserId!,
            adminView: true,
          ),
        ),
      );
      return;
    }
    if (report.listingId != null) {
      try {
        final listings = await ref
            .read(listingServiceProvider)
            .fetchListingsByIds([report.listingId!]);
        if (!mounted) return;
        if (listings.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This listing no longer exists.')),
          );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ListingDetailScreen(listing: listings.first, adminView: true),
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
        }
      }
    }
  }

  String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';

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
              final hasTarget = report.listingId != null || report.reportedUserId != null;
              final isOpen = report.status == 'open';

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  onTap: hasTarget ? () => _openTarget(report) : null,
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
                          if (hasTarget)
                            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
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
