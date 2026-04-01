/// Sales Riverpod providers — cart, history, summary.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sales_repository.dart';
import '../domain/sale.dart';

// ── Repository ────────────────────────────────────────────────

/// Singleton sales repository provider.
final salesRepositoryProvider = Provider<SalesRepository>(
  (_) => SalesRepository(),
);

// ── Cart ──────────────────────────────────────────────────────

/// Immutable cart state.
class CartState {
  /// Creates a [CartState].
  const CartState({
    this.items = const [],
    this.warehouseId,
    this.discount = 0.0,
  });

  /// Items currently in the cart.
  final List<CartItem> items;

  /// Selected warehouse UUID.
  final String? warehouseId;

  /// Transaction-level discount.
  final double discount;

  /// Subtotal before tax and discount.
  double get subtotal => items.fold(
        0.0,
        (sum, item) => sum + item.lineTotal,
      );

  /// Total tax across all lines.
  double get taxTotal => items.fold(
        0.0,
        (sum, item) => sum + item.lineTax,
      );

  /// Final amount due.
  double get grandTotal =>
      (subtotal + taxTotal - discount).clamp(0.0, double.infinity);

  /// Whether the cart has at least one item.
  bool get isEmpty => items.isEmpty;

  /// Returns a copy with overridden fields.
  CartState copyWith({
    List<CartItem>? items,
    String? warehouseId,
    double? discount,
    bool clearWarehouse = false,
  }) {
    return CartState(
      items: items ?? this.items,
      warehouseId: clearWarehouse
          ? null
          : warehouseId ?? this.warehouseId,
      discount: discount ?? this.discount,
    );
  }
}

/// Manages POS cart state.
class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  /// Set the source warehouse.
  void setWarehouse(String warehouseId) {
    state = state.copyWith(warehouseId: warehouseId);
  }

  /// Add a product to the cart or increment its quantity.
  void addItem({
    required String productId,
    required String productName,
    required double unitPrice,
    required double taxRate,
  }) {
    final existing = state.items.indexWhere(
      (i) => i.productId == productId,
    );
    if (existing >= 0) {
      final updated = List<CartItem>.from(state.items);
      updated[existing] = updated[existing]
          .copyWith(qty: updated[existing].qty + 1);
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(
        items: [
          ...state.items,
          CartItem(
            productId: productId,
            productName: productName,
            unitPrice: unitPrice,
            taxRate: taxRate,
            qty: 1,
          ),
        ],
      );
    }
  }

  /// Set the quantity for a cart item. Removes if qty <= 0.
  void setQty(String productId, int qty) {
    if (qty <= 0) {
      removeItem(productId);
      return;
    }
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.productId == productId)
            item.copyWith(qty: qty)
          else
            item,
      ],
    );
  }

  /// Remove an item from the cart.
  void removeItem(String productId) {
    state = state.copyWith(
      items: state.items
          .where((i) => i.productId != productId)
          .toList(),
    );
  }

  /// Apply a transaction-level discount.
  void setDiscount(double discount) {
    state = state.copyWith(discount: discount);
  }

  /// Clear all items and reset the cart.
  void clear() {
    state = const CartState();
  }
}

/// Provider for [CartNotifier].
final cartProvider =
    NotifierProvider<CartNotifier, CartState>(CartNotifier.new);

// ── Sales history list ─────────────────────────────────────────

/// Filter state for the sales history screen.
class SalesFilter {
  /// Creates a [SalesFilter].
  const SalesFilter({
    this.status,
    this.dateFrom,
    this.dateTo,
  });

  /// Optional status filter (completed/voided).
  final String? status;

  /// Optional start of date range.
  final DateTime? dateFrom;

  /// Optional end of date range.
  final DateTime? dateTo;

  /// Returns a copy with overridden fields.
  SalesFilter copyWith({
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearStatus = false,
    bool clearDateFrom = false,
    bool clearDateTo = false,
  }) {
    return SalesFilter(
      status: clearStatus ? null : status ?? this.status,
      dateFrom: clearDateFrom
          ? null
          : dateFrom ?? this.dateFrom,
      dateTo:
          clearDateTo ? null : dateTo ?? this.dateTo,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SalesFilter &&
      other.status == status &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo;

  @override
  int get hashCode =>
      Object.hash(status, dateFrom, dateTo);
}

/// Immutable state for the sales history list.
class SalesListState {
  /// Creates a [SalesListState].
  const SalesListState({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.filter = const SalesFilter(),
    this.error,
  });

  /// Current page of sales.
  final List<SaleListItem> items;

  /// Total matching sales.
  final int total;

  /// Current page number.
  final int page;

  /// Whether initial load is in progress.
  final bool isLoading;

  /// Whether a subsequent page is loading.
  final bool isLoadingMore;

  /// Active filter.
  final SalesFilter filter;

  /// Error message, if any.
  final String? error;

  /// Whether more pages are available.
  bool get hasMore => page * 20 < total;

  /// Returns a copy with overridden fields.
  SalesListState copyWith({
    List<SaleListItem>? items,
    int? total,
    int? page,
    bool? isLoading,
    bool? isLoadingMore,
    SalesFilter? filter,
    String? error,
    bool clearError = false,
  }) {
    return SalesListState(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore:
          isLoadingMore ?? this.isLoadingMore,
      filter: filter ?? this.filter,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Manages paginated sales history with filter support.
class SalesListNotifier
    extends AutoDisposeNotifier<SalesListState> {
  static const _pageSize = 20;

  @override
  SalesListState build() {
    _load(const SalesFilter(), page: 1);
    return const SalesListState(isLoading: true);
  }

  Future<void> _load(
    SalesFilter filter, {
    required int page,
    bool append = false,
  }) async {
    final repo = ref.read(salesRepositoryProvider);
    try {
      final result = await repo.listSales(
        page: page,
        pageSize: _pageSize,
        status: filter.status,
        dateFrom: filter.dateFrom,
        dateTo: filter.dateTo,
      );
      state = state.copyWith(
        items: append
            ? [...state.items, ...result.items]
            : result.items,
        total: result.total,
        page: page,
        isLoading: false,
        isLoadingMore: false,
        filter: filter,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  /// Reload with a new filter from page 1.
  Future<void> applyFilter(SalesFilter filter) async {
    state = state.copyWith(
      isLoading: true,
      filter: filter,
      clearError: true,
    );
    await _load(filter, page: 1);
  }

  /// Reload the current filter from page 1.
  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );
    await _load(state.filter, page: 1);
  }

  /// Load the next page of results.
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    await _load(
      state.filter,
      page: state.page + 1,
      append: true,
    );
  }

  /// Replace a single list item after a void operation.
  void replaceItem(SaleListItem updated) {
    state = state.copyWith(
      items: [
        for (final s in state.items)
          if (s.id == updated.id) updated else s,
      ],
    );
  }
}

/// Provider for [SalesListNotifier].
final salesListProvider = NotifierProvider.autoDispose<
    SalesListNotifier, SalesListState>(SalesListNotifier.new);

// ── Summary ────────────────────────────────────────────────────

/// Fetches aggregated sales summary (last 30 days by default).
final salesSummaryProvider =
    FutureProvider.autoDispose<SalesSummary>(
  (ref) =>
      ref.read(salesRepositoryProvider).getSummary(),
);
