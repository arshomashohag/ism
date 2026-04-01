/// Point-of-sale screen — product grid and cart.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../inventory/providers/inventory_provider.dart';
import '../../products/domain/product.dart';
import '../../products/providers/products_provider.dart';
import '../domain/sale.dart';
import '../providers/sales_provider.dart';
import 'widgets/checkout_dialog.dart';

/// POS screen with product grid (left) and live cart (right).
class PosScreen extends ConsumerStatefulWidget {
  /// Creates a [PosScreen].
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Point of Sale'),
        actions: [
          _CartBadge(),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 800;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _ProductGrid(search: _search),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                ),
                const SizedBox(
                  width: 340,
                  child: _CartPanel(),
                ),
              ],
            );
          }
          return _ProductGrid(search: _search);
        },
      ),
      floatingActionButton:
          LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;
        if (wide) return const SizedBox.shrink();
        return _FloatingCartButton();
      }),
      bottomNavigationBar: _SearchBar(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: const InputDecoration(
            hintText: 'Search products…',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
    );
  }
}

// ── Cart badge on AppBar ───────────────────────────────────────

class _CartBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count =
        ref.watch(cartProvider.select((s) => s.items.length));
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: IconButton(
        icon: const Icon(Icons.shopping_cart_outlined),
        tooltip: 'Cart',
        onPressed: () => _showCart(context),
      ),
    );
  }

  void _showCart(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scroll) =>
            _CartPanel(scrollController: scroll),
      ),
    );
  }
}

// ── Floating cart button (mobile) ─────────────────────────────

class _FloatingCartButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count =
        ref.watch(cartProvider.select((s) => s.items.length));
    if (count == 0) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      icon: const Icon(Icons.shopping_cart),
      label: Text('Cart ($count)'),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (ctx, scroll) =>
              _CartPanel(scrollController: scroll),
        ),
      ),
    );
  }
}

// ── Product grid ──────────────────────────────────────────────

class _ProductGrid extends ConsumerWidget {
  const _ProductGrid({required this.search});

  final String search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(
      productListProvider.select((s) => s.products),
    );
    final filtered = search.isEmpty
        ? productsAsync
        : productsAsync
            .where(
              (p) => p.name
                  .toLowerCase()
                  .contains(search.toLowerCase()),
            )
            .toList();

    if (filtered.isEmpty && search.isNotEmpty) {
      return Center(
        child: Text(
          'No products match "$search"',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate:
          const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) =>
          _ProductCard(product: filtered[index]),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ref.read(cartProvider.notifier).addItem(
                productId: product.id,
                productName: product.name,
                unitPrice: product.unitPrice,
                taxRate: product.taxRate ?? 0.0,
              );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${product.name} added to cart',
              ),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    product.name.isNotEmpty
                        ? product.name[0].toUpperCase()
                        : '?',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Text(
                '\$${product.unitPrice.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: cs.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cart panel ────────────────────────────────────────────────

class _CartPanel extends ConsumerWidget {
  const _CartPanel({this.scrollController});

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final cs = Theme.of(context).colorScheme;

    return ColoredBox(
      color: cs.surface,
      child: Column(
        children: [
          _CartHeader(itemCount: cart.items.length),
          if (cart.isEmpty)
            const Expanded(
              child: Center(
                child: Text('Cart is empty'),
              ),
            )
          else ...[
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: cart.items.length,
                itemBuilder: (context, index) =>
                    _CartLineItem(
                  item: cart.items[index],
                ),
              ),
            ),
            _CartTotals(cart: cart),
          ],
          _CartActions(cart: cart),
        ],
      ),
    );
  }
}

class _CartHeader extends StatelessWidget {
  const _CartHeader({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            'Cart',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Chip(
            label: Text('$itemCount items'),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _CartLineItem extends ConsumerWidget {
  const _CartLineItem({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '\$${item.unitPrice.toStringAsFixed(2)} × ${item.qty}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: cs.onSurface
                            .withValues(alpha: 0.55),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _QtyControl(item: item),
          const SizedBox(width: 8),
          Text(
            '\$${item.lineTotal.toStringAsFixed(2)}',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 18,
              color: cs.error,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 28,
            ),
            onPressed: () => ref
                .read(cartProvider.notifier)
                .removeItem(item.productId),
          ),
        ],
      ),
    );
  }
}

class _QtyControl extends ConsumerWidget {
  const _QtyControl({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SmallIconButton(
          icon: Icons.remove,
          color: cs.primary,
          onPressed: () => ref
              .read(cartProvider.notifier)
              .setQty(item.productId, item.qty - 1),
        ),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '${item.qty}',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        _SmallIconButton(
          icon: Icons.add,
          color: cs.primary,
          onPressed: () => ref
              .read(cartProvider.notifier)
              .setQty(item.productId, item.qty + 1),
        ),
      ],
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _CartTotals extends StatelessWidget {
  const _CartTotals({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall;
    final boldStyle = style?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Divider(
            color: cs.outline.withValues(alpha: 0.2),
          ),
          _TotalsRow(
            label: 'Subtotal',
            value:
                '\$${cart.subtotal.toStringAsFixed(2)}',
            labelStyle: style,
            valueStyle: boldStyle,
          ),
          _TotalsRow(
            label: 'Tax',
            value:
                '\$${cart.taxTotal.toStringAsFixed(2)}',
            labelStyle: style,
            valueStyle: boldStyle,
          ),
          if (cart.discount > 0)
            _TotalsRow(
              label: 'Discount',
              value:
                  '-\$${cart.discount.toStringAsFixed(2)}',
              labelStyle: style,
              valueStyle: boldStyle?.copyWith(
                color: Colors.green.shade600,
              ),
            ),
          _TotalsRow(
            label: 'Total',
            value:
                '\$${cart.grandTotal.toStringAsFixed(2)}',
            labelStyle: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            valueStyle: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
          ),
        ],
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: labelStyle),
          const Spacer(),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

class _CartActions extends ConsumerWidget {
  const _CartActions({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehouses =
        ref.watch(warehousesProvider).valueOrNull ?? [];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (warehouses.isNotEmpty)
            _WarehouseDropdown(warehouses: warehouses),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: cart.isEmpty
                    ? null
                    : () => ref
                        .read(cartProvider.notifier)
                        .clear(),
                child: const Text('Clear'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(
                    Icons.point_of_sale,
                    size: 18,
                  ),
                  label: Text(
                    'Checkout'
                    ' (\$${cart.grandTotal.toStringAsFixed(2)})',
                  ),
                  onPressed:
                      (cart.isEmpty || cart.warehouseId == null)
                          ? null
                          : () => _openCheckout(
                                context,
                                ref,
                                cart,
                              ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openCheckout(
    BuildContext context,
    WidgetRef ref,
    CartState cart,
  ) async {
    final sale = await showDialog<Sale>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CheckoutDialog(cart: cart),
    );
    if (sale == null || !context.mounted) return;
    ref.read(cartProvider.notifier).clear();
    context.push('/sales/${sale.id}');
  }
}

class _WarehouseDropdown extends ConsumerWidget {
  const _WarehouseDropdown({required this.warehouses});

  final List<dynamic> warehouses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId =
        ref.watch(cartProvider.select((s) => s.warehouseId));

    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      decoration: const InputDecoration(
        labelText: 'Warehouse',
        prefixIcon: Icon(Icons.warehouse_outlined),
      ),
      items: warehouses.map<DropdownMenuItem<String>>((w) {
        return DropdownMenuItem<String>(
          value: w.id as String,
          child: Text(w.name as String),
        );
      }).toList(),
      onChanged: (id) {
        if (id != null) {
          ref
              .read(cartProvider.notifier)
              .setWarehouse(id);
        }
      },
    );
  }
}
