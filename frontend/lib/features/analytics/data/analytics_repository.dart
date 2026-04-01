/// Analytics repository — API calls for the dashboard.
library;

import '../../../core/network/api_client.dart';
import '../domain/analytics_models.dart';

/// Handles all analytics API calls.
class AnalyticsRepository {
  /// Creates an [AnalyticsRepository].
  AnalyticsRepository({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// Fetch aggregated sales KPIs with trend and growth data.
  Future<SalesSummaryAnalytics> getSalesSummary({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final query = <String, dynamic>{
      if (dateFrom != null)
        'date_from': dateFrom.toUtc().toIso8601String(),
      if (dateTo != null)
        'date_to': dateTo.toUtc().toIso8601String(),
    };
    final data = await _client.get(
      '/analytics/sales-summary',
      query: query,
    );
    return SalesSummaryAnalytics.fromJson(
        data as Map<String, dynamic>);
  }

  /// Fetch per-salesman KPI leaderboard.
  Future<SalesmanKpiData> getSalesmanKpi({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final query = <String, dynamic>{
      if (dateFrom != null)
        'date_from': dateFrom.toUtc().toIso8601String(),
      if (dateTo != null)
        'date_to': dateTo.toUtc().toIso8601String(),
    };
    final data = await _client.get(
      '/analytics/salesman-kpi',
      query: query,
    );
    return SalesmanKpiData.fromJson(
        data as Map<String, dynamic>);
  }

  /// Fetch inventory health snapshot.
  Future<InventoryHealthData> getInventoryHealth() async {
    final data =
        await _client.get('/analytics/inventory-health');
    return InventoryHealthData.fromJson(
        data as Map<String, dynamic>);
  }

  /// Trigger on-demand materialized view refresh.
  Future<void> refreshAnalytics() async {
    await _client.post('/analytics/refresh');
  }
}
