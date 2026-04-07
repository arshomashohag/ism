/// Date range selector widget for the analytics dashboard.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/analytics_provider.dart';

/// Chip row + custom picker for selecting the analytics date range.
class DateRangeSelector extends ConsumerWidget {
  /// Creates a [DateRangeSelector].
  const DateRangeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(dateRangeProvider);
    final fmt = DateFormat('d MMM yy');
    final label =
        '${fmt.format(range.dateFrom)} – '
        '${fmt.format(range.dateTo)}';

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        const _QuickChip(label: '7d', days: 7),
        const _QuickChip(label: '30d', days: 30),
        const _QuickChip(label: '90d', days: 90),
        ActionChip(
          avatar: const Icon(
              Icons.date_range_outlined, size: 16),
          label: Text(label),
          onPressed: () =>
              _pickCustomRange(context, ref, range),
        ),
      ],
    );
  }

  Future<void> _pickCustomRange(
    BuildContext context,
    WidgetRef ref,
    DateRangeState current,
  ) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: current.dateFrom,
        end: current.dateTo,
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(
          const Duration(days: 1)),
    );
    if (picked == null) return;
    ref.read(dateRangeProvider.notifier).setRange(
          picked.start,
          DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
          ),
        );
  }
}

class _QuickChip extends ConsumerWidget {
  const _QuickChip({
    required this.label,
    required this.days,
  });

  final String label;
  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ActionChip(
      label: Text(label),
      onPressed: () => ref
          .read(dateRangeProvider.notifier)
          .setLastDays(days),
    );
  }
}
