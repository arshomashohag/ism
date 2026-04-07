/// Inventory list screen with warehouse filter and stock health.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/inventory_entry.dart';
import '../providers/inventory_provider.dart';
import 'widgets/adjust_dialog.dart';
import 'widgets/stock_status_badge.dart';

/// Displays paginated inventory with warehouse filter and health
/// colour coding.
class InventoryListScreen extends ConsumerStatefulWidget {
  /// Creates an [InventoryListScreen].
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() =>
      _InventoryListScreenState();
}

class _InventoryListScreenState
    extends ConsumerState<InventoryListScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(inventoryListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(inventoryListProvider);
    final warehousesAsync = ref.watch(warehousesProvider);
    final cs = Theme.of(context).colorScheme;

    return ColoredBox(
      color: cs.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(total: listState.total),
          _FilterBar(
            warehousesAsync: warehousesAsync,
            filter: listState.filter,
            onFilterChanged: (f) =>
                ref
                    .read(inventoryListProvider.notifier)
                    .applyFilter(f),
          ),
          Expanded(child: _buildBody(listState)),
        ],
      ),
    );
  }

  Widget _buildBody(InventoryListState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load inventory',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () =>
                  ref
                      .read(inventoryListProvider.notifier)
                      .refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warehouse_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No inventory records found',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(inventoryListProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: state.entries.length +
            (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.entries.length) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: CircularProgressIndicator()),
            );
          }
          return _InventoryCard(
            entry: state.entries[index],
            onAdjust: () =>
                _showAdjustDialog(state.entries[index]),
          );
        },
      ),
    );
  }

  Future<void> _showAdjustDialog(
      InventoryEntry entry) async {
    final warehousesAsync =
        ref.read(warehousesProvider);
    final warehouses =
        warehousesAsync.valueOrNull ?? [];

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AdjustDialog(
        entry: entry,
        warehouses: warehouses,
      ),
    );
    if (mounted) {
      ref.read(inventoryListProvider.notifier).refresh();
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventory',
                  style:
                      theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (total > 0)
                  Text(
                    '$total records',
                    style:
                        theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () =>
                context.push('/inventory/transfer'),
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('Transfer'),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.warehousesAsync,
    required this.filter,
    required this.onFilterChanged,
  });

  final AsyncValue<List<Warehouse>> warehousesAsync;
  final InventoryFilter filter;
  final ValueChanged<InventoryFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final warehouses = warehousesAsync.valueOrNull ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          if (warehouses.isNotEmpty) ...[
            Expanded(
              child: _WarehouseDropdown(
                warehouses: warehouses,
                selectedId: filter.warehouseId,
                onChanged: (id) => onFilterChanged(
                  filter.copyWith(
                    warehouseId: id,
                    clearWarehouse: id == null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          FilterChip(
            label: const Text('Low stock only'),
            selected: filter.lowStock,
            onSelected: (v) =>
                onFilterChanged(filter.copyWith(lowStock: v)),
          ),
        ],
      ),
    );
  }
}

class _WarehouseDropdown extends StatelessWidget {
  const _WarehouseDropdown({
    required this.warehouses,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Warehouse> warehouses;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedId,
          hint: const Text('All warehouses'),
          isExpanded: true,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All warehouses'),
            ),
            ...warehouses.map(
              (w) => DropdownMenuItem<String?>(
                value: w.id,
                child: Text(w.name),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.entry,
    required this.onAdjust,
  });

  final InventoryEntry entry;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.hardEdge,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    entry.productName.isNotEmpty
                        ? entry.productName[0].toUpperCase()
                        : '?',
                    style:
                        theme.textTheme.titleMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.productName,
                      style:
                          theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _SmallChip(entry.productSku),
                        const SizedBox(width: 6),
                        _SmallChip(
                          entry.warehouseName,
                          color: cs.secondaryContainer,
                          textColor: cs.onSecondaryContainer,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StockStatusBadge(status: entry.stockStatus),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.qtyOnHand} units',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'reorder @ ${entry.reorderPoint}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Adjust stock',
                onPressed: onAdjust,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip(
    this.label, {
    this.color,
    this.textColor,
  });

  final String label;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color ?? cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor ??
                  cs.onSurface.withValues(alpha: 0.65),
            ),
      ),
    );
  }
}
