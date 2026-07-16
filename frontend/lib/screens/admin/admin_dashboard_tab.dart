import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final gold = isDark ? AppColorsDark.gold : AppColors.gold;
    final infoBlue = isDark ? AppColorsDark.infoBlue : AppColors.infoBlue;

    return AsyncStateView<_AdminStats>(
      future: _future,
      onRetry: _reload,
      loadingSkeleton: const Center(child: CircularProgressIndicator()),
      builder: (context, stats) {
        final cards = [
          (
            Icons.people_outline,
            scheme.primary,
            'Users',
            '${stats.users}',
            null,
          ),
          (
            Icons.storefront_outlined,
            scheme.tertiary,
            'Active listings',
            '${stats.activeListings}',
            'of ${stats.totalListings} total',
          ),
          (
            Icons.handshake_outlined,
            infoBlue,
            'Deals',
            '${stats.deals}',
            '${stats.completedDeals} completed',
          ),
          (
            Icons.star_border,
            gold,
            'Reviews',
            '${stats.reviews}',
            null,
          ),
          (
            Icons.flag_outlined,
            stats.openReports > 0 ? scheme.error : scheme.onSurfaceVariant,
            'Open reports',
            '${stats.openReports}',
            stats.openReports > 0 ? 'needs attention' : 'all clear',
          ),
        ];

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 600
                      ? 3
                      : 2;
              return GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.92,
                ),
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  final (icon, color, label, value, sublabel) = cards[index];
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: scheme.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              value,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                            ),
                            if (sublabel != null)
                              Text(
                                sublabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
