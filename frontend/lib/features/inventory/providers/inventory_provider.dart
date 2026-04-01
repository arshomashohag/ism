/// Inventory Riverpod providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/inventory_repository.dart';
import '../domain/inventory_entry.dart';

// ── Repository ────────────────────────────────────────────────

/// Singleton inventory repository provider.
final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (_) => InventoryRepository(),
);

// ── Warehouses ────────────────────────────────────────────────

/// Fetches and caches all active warehouses.
final warehousesProvider =
    AsyncNotifierProvider.autoDispose<WarehousesNotifier,
        List<Warehouse>>(WarehousesNotifier.new);

/// Manages warehouse list state.
class WarehousesNotifier
    extends AutoDisposeAsyncNotifier<List<Warehouse>> {
  @override
  Future<List<Warehouse>> build() {
    return ref
        .read(inventoryRepositoryProvider)
        .listWarehouses();
  }
}

// ── Inventory list ────────────────────────────────────────────

/// Filters applied to the inventory list.
class InventoryFilter {
  /// Creates an [InventoryFilter].
  const InventoryFilter({
    this.warehouseId,
    this.lowStock = false,
  });

  /// Optional warehouse to filter by.
  final String? warehouseId;

  /// If true, show only low/out-of-stock entries.
  final bool lowStock;

  /// Returns a copy with overridden fields.
  InventoryFilter copyWith({
    String? warehouseId,
    bool? lowStock,
    bool clearWarehouse = false,
  }) {
    return InventoryFilter(
      warehouseId: clearWarehouse
          ? null
          : warehouseId ?? this.warehouseId,
      lowStock: lowStock ?? this.lowStock,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is InventoryFilter &&
      other.warehouseId == warehouseId &&
      other.lowStock == lowStock;

  @override
  int get hashCode =>
      Object.hash(warehouseId, lowStock);
}

/// Immutable state for the inventory list screen.
class InventoryListState {
  /// Creates an [InventoryListState].
  const InventoryListState({
    this.entries = const [],
    this.total = 0,
    this.page = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.filter = const InventoryFilter(),
    this.error,
  });

  /// Current page of entries.
  final List<InventoryEntry> entries;

  /// Total matching entries (all pages).
  final int total;

  /// Current page number.
  final int page;

  /// Whether initial load is in progress.
  final bool isLoading;

  /// Whether a subsequent page is loading.
  final bool isLoadingMore;

  /// Active filter.
  final InventoryFilter filter;

  /// Error message, if any.
  final String? error;

  /// Whether more pages are available.
  bool get hasMore => page * 50 < total;

  /// Returns a copy with overridden fields.
  InventoryListState copyWith({
    List<InventoryEntry>? entries,
    int? total,
    int? page,
    bool? isLoading,
    bool? isLoadingMore,
    InventoryFilter? filter,
    String? error,
    bool clearError = false,
  }) {
    return InventoryListState(
      entries: entries ?? this.entries,
      total: total ?? this.total,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      filter: filter ?? this.filter,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Manages paginated inventory list with filter support.
class InventoryListNotifier
    extends AutoDisposeNotifier<InventoryListState> {
  static const _pageSize = 50;

  @override
  InventoryListState build() {
    _load(const InventoryFilter(), page: 1);
    return const InventoryListState(isLoading: true);
  }

  Future<void> _load(
    InventoryFilter filter, {
    required int page,
    bool append = false,
  }) async {
    final repo = ref.read(inventoryRepositoryProvider);
    try {
      final result = await repo.listInventory(
        page: page,
        pageSize: _pageSize,
        warehouseId: filter.warehouseId,
        lowStock: filter.lowStock,
      );
      state = state.copyWith(
        entries: append
            ? [...state.entries, ...result.items]
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
  Future<void> applyFilter(InventoryFilter filter) async {
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
    await _load(state.filter, page: state.page + 1, append: true);
  }

  /// Replace a single entry after an adjustment or transfer.
  void replaceEntry(InventoryEntry updated) {
    state = state.copyWith(
      entries: [
        for (final e in state.entries)
          if (e.id == updated.id) updated else e,
      ],
    );
  }
}

/// Provider for [InventoryListNotifier].
final inventoryListProvider = NotifierProvider.autoDispose<
    InventoryListNotifier, InventoryListState>(
  InventoryListNotifier.new,
);

// ── Alerts ────────────────────────────────────────────────────

/// Fetches current low-stock alerts.
final stockAlertsProvider =
    FutureProvider.autoDispose<List<StockAlert>>(
  (ref) => ref.read(inventoryRepositoryProvider).getAlerts(),
);

/// Provides the count of active alerts for badge display.
final alertCountProvider = FutureProvider.autoDispose<int>(
  (ref) async {
    final alerts =
        await ref.watch(stockAlertsProvider.future);
    return alerts.length;
  },
);
