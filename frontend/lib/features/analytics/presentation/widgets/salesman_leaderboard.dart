/// Sortable salesman KPI leaderboard table widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/analytics_models.dart';
import '../../providers/analytics_provider.dart';

/// Displays a sortable table of per-salesman KPI metrics.
class SalesmanLeaderboard extends ConsumerWidget {
  /// Creates a [SalesmanLeaderboard].
  const SalesmanLeaderboard({
    super.key,
    required this.data,
  });

  /// Loaded KPI data to display.
  final SalesmanKpiData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpiState = ref.watch(salesmanKpiProvider);
    final rows = _sortedRows(
      data.rows,
      kpiState.sortColumn,
      kpiState.sortAscending,
    );
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: _sortIndex(kpiState.sortColumn),
        sortAscending: kpiState.sortAscending,
        headingRowColor: WidgetStateProperty.all(
          cs.surfaceContainerHighest,
        ),
        columns: [
          const DataColumn(label: Text('Salesman')),
          DataColumn(
            label: const Text('Revenue'),
            numeric: true,
            onSort: (_, __) => ref
                .read(salesmanKpiProvider.notifier)
                .sort('revenue'),
          ),
          DataColumn(
            label: const Text('Sales'),
            numeric: true,
            onSort: (_, __) => ref
                .read(salesmanKpiProvider.notifier)
                .sort('sales'),
          ),
          DataColumn(
            label: const Text('Avg Items'),
            numeric: true,
            onSort: (_, __) => ref
                .read(salesmanKpiProvider.notifier)
                .sort('avg_items'),
          ),
          DataColumn(
            label: const Text('Voids'),
            numeric: true,
            onSort: (_, __) => ref
                .read(salesmanKpiProvider.notifier)
                .sort('voids'),
          ),
        ],
        rows: rows
            .map(
              (r) => DataRow(
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              cs.primaryContainer,
                          foregroundColor:
                              cs.onPrimaryContainer,
                          child: Text(
                            _initials(r.salesmanName),
                            style: const TextStyle(
                                fontSize: 10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(r.salesmanName),
                      ],
                    ),
                  ),
                  DataCell(Text(
                    '\$${r.totalRevenue.toStringAsFixed(2)}',
                  )),
                  DataCell(
                      Text(r.totalSales.toString())),
                  DataCell(Text(
                    r.avgItemsPerSale
                        .toStringAsFixed(1),
                  )),
                  DataCell(
                      Text(r.voidCount.toString())),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  List<SalesmanKpiRow> _sortedRows(
    List<SalesmanKpiRow> rows,
    String column,
    bool ascending,
  ) {
    final sorted = List<SalesmanKpiRow>.from(rows);
    sorted.sort((a, b) {
      final cmp = switch (column) {
        'sales' => a.totalSales.compareTo(b.totalSales),
        'avg_items' => a.avgItemsPerSale
            .compareTo(b.avgItemsPerSale),
        'voids' => a.voidCount.compareTo(b.voidCount),
        _ => a.totalRevenue.compareTo(b.totalRevenue),
      };
      return ascending ? cmp : -cmp;
    });
    return sorted;
  }

  int _sortIndex(String column) {
    return switch (column) {
      'revenue' => 1,
      'sales' => 2,
      'avg_items' => 3,
      'voids' => 4,
      _ => 1,
    };
  }

  String _initials(String name) {
    return name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase())
        .take(2)
        .join();
  }
}
