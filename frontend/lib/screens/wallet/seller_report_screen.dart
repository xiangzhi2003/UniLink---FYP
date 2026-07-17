import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state_view.dart';

typedef _SellerReport = ({
  int dealCount,
  int saleCount,
  int rentCount,
  double earnings,
  String? topCategory,
  int? earningsChangePercent,
  List<({String category, int count, double earnings})> categoryBreakdown,
  String narrative,
});

/// A seller's own monthly/yearly performance report -- real stats (stat
/// cards) plus an AI-written narrative that only ever describes those same
/// numbers, never invents new ones.
class SellerReportScreen extends ConsumerStatefulWidget {
  const SellerReportScreen({super.key});

  @override
  ConsumerState<SellerReportScreen> createState() => _SellerReportScreenState();
}

class _SellerReportScreenState extends ConsumerState<SellerReportScreen> {
  String _period = 'month';
  late Future<_SellerReport> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(backendServiceProvider).fetchSellerReport(_period);
  }

  void _setPeriod(String period) {
    setState(() {
      _period = period;
      _future = ref.read(backendServiceProvider).fetchSellerReport(period);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sales Report')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ChoiceChip(
                  label: const Text('This Month'),
                  selected: _period == 'month',
                  onSelected: (_) => _setPeriod('month'),
                ),
                const SizedBox(width: AppSpacing.sm),
                ChoiceChip(
                  label: const Text('This Year'),
                  selected: _period == 'year',
                  onSelected: (_) => _setPeriod('year'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: AsyncStateView<_SellerReport>(
                future: _future,
                loadingSkeleton: const Center(child: CircularProgressIndicator()),
                builder: (context, report) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childAspectRatio: 1.15,
                        children: [
                          _statCard(
                            context,
                            icon: Icons.handshake_outlined,
                            label: 'Deals completed',
                            value: '${report.dealCount}',
                            sublabel: '${report.saleCount} sales · ${report.rentCount} rentals',
                          ),
                          _statCard(
                            context,
                            icon: Icons.payments_outlined,
                            label: 'Earnings',
                            value: 'RM${report.earnings.toStringAsFixed(2)}',
                            sublabel: report.earningsChangePercent == null
                                ? null
                                : '${report.earningsChangePercent! >= 0 ? '+' : ''}'
                                    '${report.earningsChangePercent}% vs last $_period',
                            sublabelColor: report.earningsChangePercent == null
                                ? null
                                : (report.earningsChangePercent! >= 0
                                    ? scheme.tertiary
                                    : scheme.error),
                          ),
                          _statCard(
                            context,
                            icon: Icons.category_outlined,
                            label: 'Top category',
                            value: report.topCategory ?? '—',
                          ),
                        ],
                      ),
                      if (report.categoryBreakdown.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _categoryChart(context, report.categoryBreakdown),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'AI Insights',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(report.narrative, style: const TextStyle(height: 1.5)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A simple horizontal bar chart of earnings per category -- built with
  /// plain Flutter widgets (no charting package needed for one bar chart).
  Widget _categoryChart(
    BuildContext context,
    List<({String category, int count, double earnings})> breakdown,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final maxEarnings = breakdown.map((c) => c.earnings).reduce((a, b) => a > b ? a : b);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              const Text('Earnings by Category', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < breakdown.length; i++) ...[
            _categoryBarRow(scheme, breakdown[i], maxEarnings),
            if (i != breakdown.length - 1) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _categoryBarRow(
    ColorScheme scheme,
    ({String category, int count, double earnings}) c,
    double maxEarnings,
  ) {
    final fraction = maxEarnings == 0 ? 0.0 : c.earnings / maxEarnings;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            c.category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(height: 18, color: scheme.surfaceContainerHighest),
                    Container(
                      height: 18,
                      width: constraints.maxWidth * fraction,
                      color: scheme.primary,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            'RM${c.earnings.toStringAsFixed(2)}',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    String? sublabel,
    Color? sublabelColor,
  }) {
    final scheme = Theme.of(context).colorScheme;
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
          Icon(icon, color: scheme.primary, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              if (sublabel != null)
                Text(
                  sublabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: sublabelColor ?? scheme.onSurfaceVariant, fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
