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
  Map<String, int> listingsByCategory,
});

/// Marketplace-wide counts, straight from GET /admin/stats. Cards jump to
/// the relevant tab when tapped (via [onNavigateToTab]) so the dashboard
/// doubles as a shortcut hub, not just a readout.
class AdminDashboardTab extends ConsumerStatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const AdminDashboardTab({super.key, this.onNavigateToTab});

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
        // (icon, color, label, value, sublabel, tab index to jump to on tap)
        final cards = [
          (Icons.people_outline, scheme.primary, 'Users', '${stats.users}', null, 2),
          (
            Icons.storefront_outlined,
            scheme.tertiary,
            'Active listings',
            '${stats.activeListings}',
            'of ${stats.totalListings} total',
            1,
          ),
          (
            Icons.handshake_outlined,
            infoBlue,
            'Deals',
            '${stats.deals}',
            '${stats.completedDeals} completed',
            null,
          ),
          (Icons.star_border, gold, 'Reviews', '${stats.reviews}', null, null),
          (
            Icons.flag_outlined,
            stats.openReports > 0 ? scheme.error : scheme.onSurfaceVariant,
            'Open reports',
            '${stats.openReports}',
            stats.openReports > 0 ? 'needs attention' : 'all clear',
            3,
          ),
        ];

        final maxCategoryCount = stats.listingsByCategory.values.isEmpty
            ? 0
            : stats.listingsByCategory.values.reduce((a, b) => a > b ? a : b);

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 600
                      ? 3
                      : 2;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      childAspectRatio: 0.92,
                    ),
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      final (icon, color, label, value, sublabel, tabIndex) = cards[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        onTap: tabIndex == null
                            ? null
                            : () => widget.onNavigateToTab?.call(tabIndex),
                        child: Container(
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
                              Row(
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
                                  if (tabIndex != null)
                                    Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
                                ],
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
                        ),
                      );
                    },
                  ),
                  if (stats.listingsByCategory.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Text('LISTINGS BY CATEGORY', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: scheme.outline),
                      ),
                      child: Column(
                        children: [
                          for (final entry in stats.listingsByCategory.entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 90,
                                    child: Text(entry.key, style: const TextStyle(fontSize: 13)),
                                  ),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(AppRadius.pill),
                                      child: LinearProgressIndicator(
                                        value: maxCategoryCount == 0
                                            ? 0
                                            : entry.value / maxCategoryCount,
                                        minHeight: 10,
                                        backgroundColor: scheme.surfaceContainerHighest,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  SizedBox(
                                    width: 24,
                                    child: Text(
                                      '${entry.value}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}
