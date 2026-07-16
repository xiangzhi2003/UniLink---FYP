import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state_view.dart';

typedef _AdminStats = ({
  int users,
  int activeListings,
  int totalListings,
  int deals,
  int completedDeals,
  int reviews,
  int openReports,
});

/// Marketplace-wide counts, straight from GET /admin/stats.
class AdminDashboardTab extends ConsumerStatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  ConsumerState<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends ConsumerState<AdminDashboardTab> {
  late Future<_AdminStats> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(backendServiceProvider).fetchAdminStats();
  }

  void _reload() {
    setState(() {
      _future = ref.read(backendServiceProvider).fetchAdminStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AsyncStateView<_AdminStats>(
      future: _future,
      onRetry: _reload,
      loadingSkeleton: const Center(child: CircularProgressIndicator()),
      builder: (context, stats) {
        final cards = [
          (Icons.people_outline, 'Users', '${stats.users}'),
          (Icons.storefront_outlined, 'Active listings',
              '${stats.activeListings} of ${stats.totalListings}'),
          (Icons.handshake_outlined, 'Deals',
              '${stats.deals} (${stats.completedDeals} completed)'),
          (Icons.star_border, 'Reviews', '${stats.reviews}'),
          (Icons.flag_outlined, 'Open reports', '${stats.openReports}'),
        ];

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              for (final (icon, label, value) in cards)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    child: Row(
                      children: [
                        Icon(icon, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: Text(label)),
                        Text(
                          value,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
