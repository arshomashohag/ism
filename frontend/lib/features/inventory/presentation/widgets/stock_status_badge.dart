/// Color-coded stock status badge widget.
library;

import 'package:flutter/material.dart';

import '../../domain/inventory_entry.dart';

/// Displays a colour-coded pill for [StockStatus].
///
/// Green = ok, amber = low, red = out.
class StockStatusBadge extends StatelessWidget {
  /// Creates a [StockStatusBadge].
  const StockStatusBadge({super.key, required this.status});

  /// The stock health status to display.
  final StockStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _palette(status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  static (String, Color, Color) _palette(StockStatus s) {
    switch (s) {
      case StockStatus.ok:
        return ('In Stock', const Color(0xFFD1FAE5),
            const Color(0xFF065F46));
      case StockStatus.low:
        return ('Low Stock', const Color(0xFFFEF3C7),
            const Color(0xFF92400E));
      case StockStatus.out:
        return ('Out of Stock', const Color(0xFFFEE2E2),
            const Color(0xFF991B1B));
    }
  }
}
