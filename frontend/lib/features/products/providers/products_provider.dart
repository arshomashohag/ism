/// Riverpod providers for products and categories.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/products_repository.dart';
import '../domain/category.dart';
import '../domain/product.dart';

// ── Repository ───────────────────────────────────────────────

/// Singleton [ProductsRepository] provider.
final productsRepositoryProvider = Provider<ProductsRepository>(
  (_) => ProductsRepository(),
);

// ── Categories ───────────────────────────────────────────────

/// Provides the full category tree.
final categoriesProvider =
    AsyncNotifierProvider.autoDispose<CategoriesNotifier, List<Category>>(
  CategoriesNotifier.new,
);

/// Manages the categories list.
class CategoriesNotifier extends AutoDisposeAsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() {
    return ref.read(productsRepositoryProvider).listCategories();
  }

  /// Reload categories from the server.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(productsRepositoryProvider).listCategories(),
    );
  }

  /// Create a category and reload the list.
  Future<void> createCategory(String name, {String? parentId}) async {
    await ref.read(productsRepositoryProvider).createCategory(
          name: name,
          parentId: parentId,
        );
    await refresh();
  }
}

// ── Product list ─────────────────────────────────────────────

/// Filter / search parameters for the product list.
class ProductFilter {
  /// Creates a [ProductFilter].
  const ProductFilter({
    this.search = '',
    this.categoryId,
  });

  /// Text search query.
  final String search;

  /// Category UUID filter, null means all.
  final String? categoryId;

  /// Returns a copy with the given fields overridden.
  ProductFilter copyWith({String? search, String? categoryId}) {
    return ProductFilter(
      search: search ?? this.search,
      categoryId: categoryId ?? this.categoryId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProductFilter &&
      other.search == search &&
      other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(search, categoryId);
}

/// Notifier state for the paginated product list.
class ProductListState {
  /// Creates a [ProductListState].
  const ProductListState({
    this.products = const [],
    this.total = 0,
    this.page = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.filter = const ProductFilter(),
    this.error,
  });

  /// Currently loaded products.
  final List<Product> products;

  /// Total matching products on server.
  final int total;

  /// Last loaded page number.
  final int page;

  /// True while the initial load or filter change is in progress.
  final bool isLoading;

  /// True while loading the next page.
  final bool isLoadingMore;

  /// Active filter.
  final ProductFilter filter;

  /// Error message if last request failed.
  final String? error;

  /// Whether more pages can be fetched.
  bool get hasMore => products.length < total;

  /// Returns a copy with the given fields overridden.
  ProductListState copyWith({
    List<Product>? products,
    int? total,
    int? page,
    bool? isLoading,
    bool? isLoadingMore,
    ProductFilter? filter,
    Object? error = _sentinel,
  }) {
    return ProductListState(
      products: products ?? this.products,
      total: total ?? this.total,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      filter: filter ?? this.filter,
      error: error == _sentinel
          ? this.error
          : error as String?,
    );
  }
}

const _sentinel = Object();
const _pageSize = 20;

/// Manages paginated, filtered product list state.
class ProductListNotifier extends AutoDisposeNotifier<ProductListState> {
  @override
  ProductListState build() {
    _load(const ProductFilter());
    return const ProductListState(isLoading: true);
  }

  ProductsRepository get _repo =>
      ref.read(productsRepositoryProvider);

  /// Apply a new filter and reload from page 1.
  Future<void> applyFilter(ProductFilter filter) async {
    if (state.filter == filter) return;
    state = ProductListState(filter: filter, isLoading: true);
    await _load(filter);
  }

  /// Reload the current filter from page 1.
  Future<void> refresh() async {
    state = ProductListState(
      filter: state.filter,
      isLoading: true,
    );
    await _load(state.filter);
  }

  /// Load the next page if more are available.
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.page + 1;
      final result = await _repo.listProducts(
        page: nextPage,
        pageSize: _pageSize,
        search: state.filter.search.isEmpty
            ? null
            : state.filter.search,
        categoryId: state.filter.categoryId,
      );
      state = state.copyWith(
        products: [...state.products, ...result.items],
        total: result.total,
        page: nextPage,
        isLoadingMore: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  /// Remove a product from the local list after deletion.
  void removeProduct(String productId) {
    state = state.copyWith(
      products: state.products
          .where((p) => p.id != productId)
          .toList(),
      total: state.total - 1,
    );
  }

  /// Replace an updated product in the local list.
  void replaceProduct(Product updated) {
    state = state.copyWith(
      products: state.products
          .map((p) => p.id == updated.id ? updated : p)
          .toList(),
    );
  }

  Future<void> _load(ProductFilter filter) async {
    try {
      final result = await _repo.listProducts(
        page: 1,
        pageSize: _pageSize,
        search:
            filter.search.isEmpty ? null : filter.search,
        categoryId: filter.categoryId,
      );
      state = ProductListState(
        products: result.items,
        total: result.total,
        page: 1,
        filter: filter,
      );
    } catch (e) {
      state = ProductListState(
        filter: filter,
        error: e.toString(),
      );
    }
  }
}

/// Provider for [ProductListNotifier].
final productListProvider =
    NotifierProvider.autoDispose<ProductListNotifier, ProductListState>(
  ProductListNotifier.new,
);

// ── Product detail ───────────────────────────────────────────

/// Provides a single product fetched by [id].
final productDetailProvider = FutureProvider.autoDispose
    .family<Product, String>((ref, id) {
  return ref.read(productsRepositoryProvider).getProduct(id);
});
