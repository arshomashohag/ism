/// Sales history screen — paginated list with filters.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../domain/sale.dart';
import '../providers/sales_provider.dart';

/// Displays a filterable, paginated list of past sales.
class SalesHistoryScreen extends ConsumerWidget {
  /// Creates a [SalesHistoryScreen].
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesState = ref.watch(salesListProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onPressed: () =>
                _showFilterSheet(context, ref, salesState),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref
                .read(salesListProvider.notifier)
                .refresh(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.point_of_sale),
        label: const Text('New Sale'),
        onPressed: () => context.push('/sales/pos'),
      ),
      body: _SalesBody(salesState: salesState),
    );
  }

  Future<void> _showFilterSheet(
    BuildContext context,
    WidgetRef ref,
    SalesListState state,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _FilterSheet(current: state.filter),
    );
  }
}

// ── Sales body ────────────────────────────────────────────────

class _SalesBody extends ConsumerWidget {
  const _SalesBody({required this.salesState});

  final SalesListState salesState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (salesState.isLoading) {
      return const Center(
          child: CircularProgressIndicator());
    }

    if (salesState.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(salesState.error!),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => ref
                  .read(salesListProvider.notifier)
                  .refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (salesState.items.isEmpty) {
      return const Center(child: Text('No sales found'));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.pixels >=
                n.metrics.maxScrollExtent - 200) {
          ref
              .read(salesListProvider.notifier)
              .loadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: salesState.items.length +
            (salesState.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) =>
            const SizedBox(height: 4),
        itemBuilder: (context, index) {
          if (index >= salesState.items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _SaleCard(
            item: salesState.items[index],
          );
        },
      ),
    );
  }
}

// ── Sale card ─────────────────────────────────────────────────

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.item});

  final SaleListItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt =
        DateFormat('dd MMM yyyy  HH:mm');
    final isVoided = item.status == 'voided';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            context.push('/sales/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isVoided
                      ? Colors.red.shade50
                      : cs.primaryContainer,
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Icon(
                  isVoided
                      ? Icons.cancel_outlined
                      : Icons.receipt_outlined,
                  color: isVoided
                      ? Colors.red.shade600
                      : cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.invoiceNumber,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                        ),
                        const SizedBox(width: 8),
                        if (isVoided)
                          Chip(
                            label: const Text(
                              'VOIDED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight:
                                    FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            backgroundColor:
                                Colors.red.shade50,
                            side: BorderSide.none,
                            padding: EdgeInsets.zero,
                            visualDensity:
                                VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fmt.format(
                          item.createdAt.toLocal()),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: cs.onSurface
                                .withOpacity(0.55),
                          ),
                    ),
                    if (item.salesmanName != null ||
                        item.warehouseName != null)
                      Text(
                        [
                          if (item.salesmanName != null)
                            item.salesmanName!,
                          if (item.warehouseName != null)
                            item.warehouseName!,
                        ].join(' · '),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: cs.onSurface
                                  .withOpacity(0.45),
                            ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${item.grandTotal.toStringAsFixed(2)}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isVoided
                              ? cs.onSurface
                                  .withOpacity(0.4)
                              : cs.primary,
                          decoration: isVoided
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                  ),
                  Text(
                    '${item.itemCount} item'
                    '${item.itemCount == 1 ? '' : 's'}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: cs.onSurface
                              .withOpacity(0.45),
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter bottom sheet ───────────────────────────────────────

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.current});

  final SalesFilter current;

  @override
  ConsumerState<_FilterSheet> createState() =>
      _FilterSheetState();
}

class _FilterSheetState
    extends ConsumerState<_FilterSheet> {
  late String? _status;
  late DateTime? _dateFrom;
  late DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _status = widget.current.status;
    _dateFrom = widget.current.dateFrom;
    _dateTo = widget.current.dateTo;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Sales',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            const Text('Status'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _status == null,
                  onSelected: (_) =>
                      setState(() => _status = null),
                ),
                ChoiceChip(
                  label: const Text('Completed'),
                  selected: _status == 'completed',
                  onSelected: (_) => setState(
                    () => _status = 'completed',
                  ),
                ),
                ChoiceChip(
                  label: const Text('Voided'),
                  selected: _status == 'voided',
                  onSelected: (_) => setState(
                    () => _status = 'voided',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(
                        Icons.calendar_today,
                        size: 16),
                    label: Text(
                      _dateFrom == null
                          ? 'From date'
                          : fmt.format(_dateFrom!),
                    ),
                    onPressed: () =>
                        _pickDate(isFrom: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(
                        Icons.calendar_today,
                        size: 16),
                    label: Text(
                      _dateTo == null
                          ? 'To date'
                          : fmt.format(_dateTo!),
                    ),
                    onPressed: () =>
                        _pickDate(isFrom: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: _clear,
                  child: const Text('Clear'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _apply,
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (_dateFrom ?? now)
          : (_dateTo ?? now),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
      } else {
        _dateTo = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
        );
      }
    });
  }

  void _clear() {
    ref.read(salesListProvider.notifier).applyFilter(
          const SalesFilter(),
        );
    Navigator.pop(context);
  }

  void _apply() {
    ref.read(salesListProvider.notifier).applyFilter(
          SalesFilter(
            status: _status,
            dateFrom: _dateFrom,
            dateTo: _dateTo,
          ),
        );
    Navigator.pop(context);
  }
}
