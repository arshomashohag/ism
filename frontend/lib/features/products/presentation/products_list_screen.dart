/// Product list screen with search, filter, and pagination.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../domain/category.dart';
import '../providers/products_provider.dart';
import 'widgets/product_card.dart';

/// Displays paginated product list with search and category filter.
class ProductsListScreen extends ConsumerStatefulWidget {
  /// Creates a [ProductsListScreen].
  const ProductsListScreen({super.key});

  @override
  ConsumerState<ProductsListScreen> createState() =>
      _ProductsListScreenState();
}

class _ProductsListScreenState
    extends ConsumerState<ProductsListScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(productListProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(productListProvider.notifier).applyFilter(
            ProductFilter(
              search: value,
              categoryId: _selectedCategoryId,
            ),
          );
    });
  }

  void _onCategoryChanged(String? categoryId) {
    setState(() => _selectedCategoryId = categoryId);
    ref.read(productListProvider.notifier).applyFilter(
          ProductFilter(
            search: _searchCtrl.text,
            categoryId: categoryId,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(productListProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            totalCount: listState.total,
            onAddPressed: () => context.push('/products/new'),
          ),
          _SearchFilterBar(
            searchCtrl: _searchCtrl,
            onSearchChanged: _onSearchChanged,
            selectedCategoryId: _selectedCategoryId,
            onCategoryChanged: _onCategoryChanged,
            categoriesAsync: categoriesAsync,
          ),
          Expanded(child: _buildBody(listState)),
        ],
      ),
    );
  }

  Widget _buildBody(ProductListState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.products.isEmpty) {
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
              'Failed to load products',
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
                  ref.read(productListProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.push('/products/new'),
              icon: const Icon(Icons.add),
              label: const Text('Add your first product'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(productListProvider.notifier).refresh(),
      child: ResponsiveGridView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: const ResponsiveGridDelegate(
          maxCrossAxisExtent: 440,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 4.5,
        ),
        itemCount:
            state.products.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.products.length) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final product = state.products[index];
          return ProductCard(
            product: product,
            onTap: () =>
                context.push('/products/${product.id}'),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.totalCount,
    required this.onAddPressed,
  });

  final int totalCount;
  final VoidCallback onAddPressed;

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
                  'Products',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (totalCount > 0)
                  Text(
                    '$totalCount items',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onAddPressed,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Product'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchFilterBar extends StatelessWidget {
  const _SearchFilterBar({
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.categoriesAsync,
  });

  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategoryChanged;
  final AsyncValue<List<Category>> categoriesAsync;

  List<Category> _flatten(List<Category> cats) {
    final result = <Category>[];
    for (final c in cats) {
      result.add(c);
      result.addAll(_flatten(c.children));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final flatCategories =
        _flatten(categoriesAsync.valueOrNull ?? []);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name or SKU...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline
                        .withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline
                        .withValues(alpha: 0.3),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
              ),
            ),
          ),
          if (flatCategories.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: selectedCategoryId,
                  hint: const Text('All categories'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All categories'),
                    ),
                    ...flatCategories.map(
                      (c) => DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(c.name),
                      ),
                    ),
                  ],
                  onChanged: onCategoryChanged,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
