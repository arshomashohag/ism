/// Analytics dashboard screen — admin home tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/analytics_models.dart';
import '../providers/analytics_provider.dart';
import 'widgets/date_range_selector.dart';
import 'widgets/kpi_card.dart';
import 'widgets/revenue_trend_chart.dart';
import 'widgets/salesman_leaderboard.dart';
import 'widgets/top_products_chart.dart';

/// Full-page analytics dashboard for admin users.
class DashboardScreen extends ConsumerWidget {
  /// Creates a [DashboardScreen].
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final salesState =
        ref.watch(salesSummaryAnalyticsProvider);
    final kpiState = ref.watch(salesmanKpiProvider);
    final invState =
        ref.watch(inventoryHealthAnalyticsProvider);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _refreshAll(ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshAll(ref),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Date range picker ─────────────────────
            const DateRangeSelector(),
            const SizedBox(height: 16),

            // ── KPI cards ────────────────────────────
            _KpiSection(salesState: salesState),
            const SizedBox(height: 24),

            // ── Revenue trend ─────────────────────────
            _SectionCard(
              title: 'Revenue Trend (30 days)',
              child: salesState.isLoading
                  ? const _LoadingBox(height: 220)
                  : salesState.error != null
                      ? _ErrorBox(
                          message: salesState.error!)
                      : RevenueTrendChart(
                          points: salesState.data
                                  ?.dailyTrend ??
                              [],
                        ),
            ),
            const SizedBox(height: 16),

            // ── Top products ──────────────────────────
            _SectionCard(
              title: 'Top Products by Revenue',
              child: salesState.isLoading
                  ? const _LoadingBox(height: 200)
                  : salesState.error != null
                      ? _ErrorBox(
                          message: salesState.error!)
                      : TopProductsChart(
                          products: salesState
                                  .data?.topProducts ??
                              [],
                        ),
            ),
            const SizedBox(height: 16),

            // ── Salesman leaderboard ─────────────────
            _SectionCard(
              title: 'Salesman Leaderboard',
              child: kpiState.isLoading
                  ? const _LoadingBox(height: 160)
                  : kpiState.error != null
                      ? _ErrorBox(
                          message: kpiState.error!)
                      : kpiState.data == null
                          ? const _LoadingBox(
                              height: 80)
                          : SalesmanLeaderboard(
                              data: kpiState.data!,
                            ),
            ),
            const SizedBox(height: 16),

            // ── Inventory health ──────────────────────
            _SectionCard(
              title: 'Inventory Health',
              child: invState.isLoading
                  ? const _LoadingBox(height: 120)
                  : invState.error != null
                      ? _ErrorBox(
                          message: invState.error!)
                      : invState.data == null
                          ? const _LoadingBox(
                              height: 80)
                          : _InventoryHealthPanel(
                              data: invState.data!,
                            ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshAll(WidgetRef ref) async {
    await Future.wait([
      ref
          .read(salesSummaryAnalyticsProvider.notifier)
          .refresh(),
      ref
          .read(salesmanKpiProvider.notifier)
          .refresh(),
      ref
          .read(inventoryHealthAnalyticsProvider.notifier)
          .refresh(),
    ]);
  }
}

// ── KPI cards section ─────────────────────────────────────────

class _KpiSection extends StatelessWidget {
  const _KpiSection({required this.salesState});

  final SalesSummaryState salesState;

  @override
  Widget build(BuildContext context) {
    final data = salesState.data;
    final currFmt = NumberFormat.currency(
        symbol: '\$', decimalDigits: 2);

    if (salesState.isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(
            child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxis =
            constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxis,
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            KpiCard(
              label: 'Revenue',
              value: currFmt
                  .format(data?.totalRevenue ?? 0),
              icon: Icons.attach_money,
              growthPct: data?.revenueGrowthPct,
            ),
            KpiCard(
              label: 'Transactions',
              value: (data?.totalTransactions ?? 0)
                  .toString(),
              icon: Icons.receipt_long_outlined,
              growthPct:
                  data?.transactionsGrowthPct,
            ),
            KpiCard(
              label: 'Avg Value',
              value: currFmt.format(
                  data?.avgTransactionValue ?? 0),
              icon:
                  Icons.show_chart,
            ),
            KpiCard(
              label: 'Low Stock',
              value: salesState.data == null
                  ? '—'
                  : '—',
              icon: Icons.warning_amber_outlined,
              subtitle: 'See inventory panel',
            ),
          ],
        );
      },
    );
  }
}

// ── Section card wrapper ──────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Inventory health panel ────────────────────────────────────

class _InventoryHealthPanel extends StatelessWidget {
  const _InventoryHealthPanel({required this.data});

  final InventoryHealthData data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final criticalRows = data.rows
        .where((r) => r.stockStatus != 'ok')
        .take(10)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatChip(
              label: '${data.lowStockCount} Low',
              color: Colors.orange,
            ),
            const SizedBox(width: 8),
            _StatChip(
              label:
                  '${data.outOfStockCount} Out',
              color: cs.error,
            ),
            const SizedBox(width: 8),
            Text(
              '${data.totalSkus} total SKUs',
              style: tt.bodySmall?.copyWith(
                color:
                    cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        if (criticalRows.isEmpty)
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'All products are well-stocked.',
              style: tt.bodyMedium?.copyWith(
                color:
                    cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          )
        else ...[
          const SizedBox(height: 12),
          ...criticalRows.map(
            (r) => _HealthRow(row: r),
          ),
        ],
      ],
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.row});

  final InventoryHealthRow row;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isOut = row.stockStatus == 'out';
    final color = isOut ? cs.error : Colors.orange;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isOut
                ? Icons.remove_circle_outline
                : Icons.warning_amber_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${row.productName} · '
              '${row.warehouseName}',
              style: tt.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${row.qtyOnHand} on hand',
            style: tt.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Loading / error placeholders ─────────────────────────────

class _LoadingBox extends StatelessWidget {
  const _LoadingBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: cs.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.error),
            ),
          ),
        ],
      ),
    );
  }
}
