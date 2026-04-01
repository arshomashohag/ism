/// Product detail screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../inventory/presentation/widgets/stock_status_badge.dart';
import '../providers/products_provider.dart';

/// Shows full product details with edit and delete actions.
class ProductDetailScreen extends ConsumerWidget {
  /// Creates a [ProductDetailScreen].
  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  /// UUID of the product to display.
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync =
        ref.watch(productDetailProvider(productId));

    return Scaffold(
      backgroundColor:
          Theme.of(context).colorScheme.surfaceContainerLowest,
      body: productAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text('Could not load product: $err'),
            ],
          ),
        ),
        data: (product) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              title: Text(product.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit',
                  onPressed: () => context.push(
                    '/products/$productId/edit',
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  tooltip: 'Delete',
                  onPressed: () =>
                      _confirmDelete(context, ref),
                ),
                const SizedBox(width: 8),
              ],
            ),
            Expanded(
              child: MaxWidthBox(
                maxWidth: 720,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _PriceCard(product: product),
                    const SizedBox(height: 12),
                    _DetailsCard(product: product),
                    if (product.inventorySummary.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _InventorySummaryCard(
                        product: product,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => ctx.pop(true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  Theme.of(ctx).colorScheme.error,
              foregroundColor:
                  Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(productsRepositoryProvider)
          .deleteProduct(productId);
      ref
          .read(productListProvider.notifier)
          .removeProduct(productId);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.product});

  final dynamic product;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  (product.name as String).isNotEmpty
                      ? (product.name as String)[0].toUpperCase()
                      : '?',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name as String,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SKU: ${product.sku}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: cs.onSurface.withOpacity(0.55),
                        ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${(product.unitPrice as double).toStringAsFixed(2)}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Unit price',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                        color: cs.onSurface.withOpacity(0.45),
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.product});

  final dynamic product;

  @override
  Widget build(BuildContext context) {
    final rows = <_Row>[];

    if (product.categoryName != null) {
      rows.add(_Row('Category', product.categoryName as String));
    }
    if (product.barcode != null) {
      rows.add(_Row('Barcode', product.barcode as String));
    }
    if (product.costPrice != null) {
      rows.add(_Row(
        'Cost Price',
        '\$${(product.costPrice as double).toStringAsFixed(2)}',
      ));
    }
    if (product.taxRate != null) {
      rows.add(_Row(
        'Tax Rate',
        '${((product.taxRate as double) * 100).toStringAsFixed(1)}%',
      ));
    }
    rows.add(_Row(
      'Status',
      (product.isActive as bool) ? 'Active' : 'Inactive',
      valueColor: (product.isActive as bool)
          ? Colors.green.shade600
          : Colors.red.shade400,
    ));

    if (rows.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (int i = 0; i < rows.length; i++) ...[
              _DetailRow(row: rows[i]),
              if (i < rows.length - 1)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withOpacity(0.15),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row {
  const _Row(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.row});

  final _Row row;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Row(
        children: [
          Text(
            row.label,
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withOpacity(0.55),
                    ),
          ),
          const Spacer(),
          Text(
            row.value,
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: row.valueColor,
                    ),
          ),
        ],
      ),
    );
  }
}

class _InventorySummaryCard extends StatelessWidget {
  const _InventorySummaryCard({required this.product});

  final dynamic product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final items =
        product.inventorySummary as List<dynamic>;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STOCK LEVELS',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurface.withOpacity(0.6),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            for (final item in items) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.warehouseName as String,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${item.qtyOnHand} units',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StockStatusBadge(
                    status: item.stockStatus,
                  ),
                ],
              ),
              if (items.last != item)
                Divider(
                  height: 16,
                  color: cs.outline.withOpacity(0.15),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
