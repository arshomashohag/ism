/// Analytics Riverpod providers — dashboard data management.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/analytics_repository.dart';
import '../domain/analytics_models.dart';

// ── Repository ────────────────────────────────────────────────

/// Singleton analytics repository provider.
final analyticsRepositoryProvider =
    Provider<AnalyticsRepository>(
  (_) => AnalyticsRepository(),
);

// ── Date range ────────────────────────────────────────────────

/// Holds the selected analytics date range.
class DateRangeState {
  /// Creates a [DateRangeState].
  const DateRangeState({
    required this.dateFrom,
    required this.dateTo,
  });

  /// Range start (inclusive).
  final DateTime dateFrom;

  /// Range end (inclusive).
  final DateTime dateTo;

  /// Returns a copy with overridden fields.
  DateRangeState copyWith({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    return DateRangeState(
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
    );
  }
}

/// Manages the active analytics date range.
class DateRangeNotifier extends Notifier<DateRangeState> {
  @override
  DateRangeState build() {
    final now = DateTime.now();
    return DateRangeState(
      dateFrom: DateTime(
          now.year, now.month, now.day)
          .subtract(const Duration(days: 29)),
      dateTo: DateTime(
          now.year, now.month, now.day, 23, 59, 59),
    );
  }

  /// Update the date range and trigger dependent providers.
  void setRange(DateTime dateFrom, DateTime dateTo) {
    state = state.copyWith(
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }

  /// Set a predefined quick-select range.
  void setLastDays(int days) {
    final now = DateTime.now();
    state = DateRangeState(
      dateFrom: DateTime(
              now.year, now.month, now.day)
          .subtract(Duration(days: days - 1)),
      dateTo: DateTime(
          now.year, now.month, now.day, 23, 59, 59),
    );
  }
}

/// Provider for [DateRangeNotifier].
final dateRangeProvider =
    NotifierProvider<DateRangeNotifier, DateRangeState>(
        DateRangeNotifier.new);

// ── Sales summary ─────────────────────────────────────────────

/// Immutable state for the sales summary card cluster.
class SalesSummaryState {
  /// Creates a [SalesSummaryState].
  const SalesSummaryState({
    this.data,
    this.isLoading = false,
    this.error,
  });

  /// Loaded analytics data or null.
  final SalesSummaryAnalytics? data;

  /// Whether a load is in progress.
  final bool isLoading;

  /// Error message or null.
  final String? error;

  /// Returns a copy with overridden fields.
  SalesSummaryState copyWith({
    SalesSummaryAnalytics? data,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SalesSummaryState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// Manages sales summary data for the dashboard.
class SalesSummaryNotifier
    extends AutoDisposeNotifier<SalesSummaryState> {
  @override
  SalesSummaryState build() {
    final range = ref.watch(dateRangeProvider);
    Future.microtask(() => _load(range));
    return const SalesSummaryState(isLoading: true);
  }

  Future<void> _load(DateRangeState range) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await ref
          .read(analyticsRepositoryProvider)
          .getSalesSummary(
            dateFrom: range.dateFrom,
            dateTo: range.dateTo,
          );
      state = state.copyWith(data: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Reload using the current date range.
  Future<void> refresh() async {
    _load(ref.read(dateRangeProvider));
  }
}

/// Provider for [SalesSummaryNotifier].
final salesSummaryAnalyticsProvider =
    AutoDisposeNotifierProvider<SalesSummaryNotifier,
        SalesSummaryState>(SalesSummaryNotifier.new);

// ── Salesman KPI ──────────────────────────────────────────────

/// Immutable state for the salesman leaderboard.
class SalesmanKpiState {
  /// Creates a [SalesmanKpiState].
  const SalesmanKpiState({
    this.data,
    this.isLoading = false,
    this.error,
    this.sortColumn = 'revenue',
    this.sortAscending = false,
  });

  /// Loaded KPI data or null.
  final SalesmanKpiData? data;

  /// Whether a load is in progress.
  final bool isLoading;

  /// Error message or null.
  final String? error;

  /// Current sort column: revenue | sales | avg_items.
  final String sortColumn;

  /// Sort direction.
  final bool sortAscending;

  /// Returns a copy with overridden fields.
  SalesmanKpiState copyWith({
    SalesmanKpiData? data,
    bool? isLoading,
    String? error,
    String? sortColumn,
    bool? sortAscending,
    bool clearError = false,
  }) {
    return SalesmanKpiState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      sortColumn: sortColumn ?? this.sortColumn,
      sortAscending:
          sortAscending ?? this.sortAscending,
    );
  }
}

/// Manages salesman KPI leaderboard state.
class SalesmanKpiNotifier
    extends AutoDisposeNotifier<SalesmanKpiState> {
  @override
  SalesmanKpiState build() {
    final range = ref.watch(dateRangeProvider);
    Future.microtask(() => _load(range));
    return const SalesmanKpiState(isLoading: true);
  }

  Future<void> _load(DateRangeState range) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await ref
          .read(analyticsRepositoryProvider)
          .getSalesmanKpi(
            dateFrom: range.dateFrom,
            dateTo: range.dateTo,
          );
      state = state.copyWith(data: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Change sort column; toggles direction if same column.
  void sort(String column) {
    final ascending = state.sortColumn == column
        ? !state.sortAscending
        : false;
    state = state.copyWith(
      sortColumn: column,
      sortAscending: ascending,
    );
  }

  /// Reload using the current date range.
  Future<void> refresh() async {
    _load(ref.read(dateRangeProvider));
  }
}

/// Provider for [SalesmanKpiNotifier].
final salesmanKpiProvider =
    AutoDisposeNotifierProvider<SalesmanKpiNotifier,
        SalesmanKpiState>(SalesmanKpiNotifier.new);

// ── Inventory health ──────────────────────────────────────────

/// Immutable state for the inventory health panel.
class InventoryHealthState {
  /// Creates an [InventoryHealthState].
  const InventoryHealthState({
    this.data,
    this.isLoading = false,
    this.error,
  });

  /// Loaded health data or null.
  final InventoryHealthData? data;

  /// Whether a load is in progress.
  final bool isLoading;

  /// Error message or null.
  final String? error;

  /// Returns a copy with overridden fields.
  InventoryHealthState copyWith({
    InventoryHealthData? data,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return InventoryHealthState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// Manages inventory health data for the dashboard.
class InventoryHealthNotifier
    extends AutoDisposeNotifier<InventoryHealthState> {
  @override
  InventoryHealthState build() {
    Future.microtask(refresh);
    return const InventoryHealthState(isLoading: true);
  }

  /// Load inventory health data from the API.
  Future<void> refresh() async {
    state =
        state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await ref
          .read(analyticsRepositoryProvider)
          .getInventoryHealth();
      state = state.copyWith(data: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

/// Provider for [InventoryHealthNotifier].
final inventoryHealthAnalyticsProvider =
    AutoDisposeNotifierProvider<InventoryHealthNotifier,
        InventoryHealthState>(InventoryHealthNotifier.new);
