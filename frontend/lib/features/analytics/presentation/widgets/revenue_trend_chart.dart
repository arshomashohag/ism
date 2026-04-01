/// Revenue trend line chart widget using fl_chart.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/analytics_models.dart';

/// Line chart showing daily revenue over the selected period.
class RevenueTrendChart extends StatelessWidget {
  /// Creates a [RevenueTrendChart].
  const RevenueTrendChart({
    super.key,
    required this.points,
  });

  /// Daily data points sorted by date ascending.
  final List<DailySalesPoint> points;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (points.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No data for this period',
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    final maxY = points
        .map((p) => p.totalRevenue)
        .reduce((a, b) => a > b ? a : b);
    final spots = points.asMap().entries.map((e) {
      return FlSpot(
          e.key.toDouble(), e.value.totalRevenue);
    }).toList();

    final dateFmt = DateFormat('d MMM');

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0
                ? (maxY * 1.2) / 4
                : 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: cs.outline.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                getTitlesWidget: (value, _) => Text(
                  _formatCompact(value),
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurface
                        .withValues(alpha: 0.55),
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
                reservedSize: 28,
                interval: _labelInterval(points.length),
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding:
                        const EdgeInsets.only(top: 6),
                    child: Text(
                      dateFmt.format(
                          points[idx].saleDate),
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((s) {
                  final idx = s.x.toInt();
                  final pt = points[idx];
                  return LineTooltipItem(
                    '${dateFmt.format(pt.saleDate)}\n'
                    '\$${pt.totalRevenue.toStringAsFixed(2)}',
                    tt.labelSmall?.copyWith(
                          color: Colors.white,
                        ) ??
                        const TextStyle(
                            color: Colors.white),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: cs.primary,
              barWidth: 2.5,
              dotData: FlDotData(
                show: points.length <= 14,
              ),
              belowBarData: BarAreaData(
                show: true,
                color: cs.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCompact(double value) {
    if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(1)}k';
    }
    return '\$${value.toStringAsFixed(0)}';
  }

  double _labelInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    if (count <= 30) return 5;
    return 7;
  }
}
