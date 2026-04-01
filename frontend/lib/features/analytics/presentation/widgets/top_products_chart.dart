/// Top products horizontal bar chart widget.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/analytics_models.dart';

/// Horizontal bar chart showing top 5 products by revenue.
class TopProductsChart extends StatelessWidget {
  /// Creates a [TopProductsChart].
  const TopProductsChart({
    super.key,
    required this.products,
  });

  /// Top products sorted by revenue descending (max 5).
  final List<TopProductAnalytics> products;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (products.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'No sales data',
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface.withOpacity(0.5),
            ),
          ),
        ),
      );
    }

    final maxRev = products
        .map((p) => p.revenue)
        .reduce((a, b) => a > b ? a : b);

    final barGroups = products
        .asMap()
        .entries
        .map(
          (e) => BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.revenue,
                color: cs.primary,
                width: 18,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
            ],
          ),
        )
        .toList();

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxRev * 1.2,
          barGroups: barGroups,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxRev > 0
                ? (maxRev * 1.2) / 4
                : 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: cs.outline.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                getTitlesWidget: (value, _) => Text(
                  _compact(value),
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurface
                        .withOpacity(0.55),
                  ),
                ),
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= products.length) {
                    return const SizedBox.shrink();
                  }
                  final name = products[idx].productName;
                  final short = name.length > 10
                      ? '${name.substring(0, 10)}…'
                      : name;
                  return Padding(
                    padding:
                        const EdgeInsets.only(top: 6),
                    child: Text(
                      short,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurface
                            .withOpacity(0.55),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) {
                final p = products[group.x];
                return BarTooltipItem(
                  '${p.productName}\n'
                  '\$${p.revenue.toStringAsFixed(2)}\n'
                  '${p.qtySold} units',
                  tt.labelSmall?.copyWith(
                        color: Colors.white,
                      ) ??
                      const TextStyle(
                          color: Colors.white),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _compact(double value) {
    if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(1)}k';
    }
    return '\$${value.toStringAsFixed(0)}';
  }
}
