/// KPI summary card widget.
library;

import 'package:flutter/material.dart';

/// Displays a single KPI metric with optional growth indicator.
class KpiCard extends StatelessWidget {
  /// Creates a [KpiCard].
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.growthPct,
    this.subtitle,
  });

  /// Card label text.
  final String label;

  /// Primary value string (pre-formatted by caller).
  final String value;

  /// Icon to display.
  final IconData icon;

  /// Optional period-over-period growth percentage.
  final double? growthPct;

  /// Optional secondary subtitle text.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Color? growthColor;
    String? growthLabel;
    IconData? growthIcon;

    if (growthPct != null) {
      final isPos = growthPct! >= 0;
      growthColor = isPos ? Colors.green : cs.error;
      growthIcon = isPos
          ? Icons.trending_up
          : Icons.trending_down;
      final sign = isPos ? '+' : '';
      growthLabel =
          '$sign${growthPct!.toStringAsFixed(1)}%';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: cs.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurface
                          .withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (growthLabel != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        growthIcon,
                        size: 14,
                        color: growthColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        growthLabel,
                        style:
                            tt.labelSmall?.copyWith(
                          color: growthColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: tt.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: tt.bodySmall?.copyWith(
                  color:
                      cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
