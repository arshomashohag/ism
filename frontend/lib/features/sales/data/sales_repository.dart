/// Sales repository — API calls for POS and sales history.
library;

import '../../../core/network/api_client.dart';
import '../domain/sale.dart';

/// Handles all sales-related API calls.
class SalesRepository {
  /// Creates a [SalesRepository].
  SalesRepository({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// Create a new completed sale.
  Future<Sale> createSale({
    required String warehouseId,
    required List<Map<String, dynamic>> lineItems,
    required String paymentMethod,
    required double amountTendered,
    double discount = 0.0,
    String deviceId = 'web',
    String? reference,
  }) async {
    final body = <String, dynamic>{
      'warehouse_id': warehouseId,
      'line_items': lineItems,
      'payment_method': paymentMethod,
      'amount_tendered': amountTendered,
      'discount': discount,
      'device_id': deviceId,
      if (reference != null) 'reference': reference,
    };
    final data = await _client.post('/sales/', body: body);
    return Sale.fromJson(data as Map<String, dynamic>);
  }

  /// Fetch a paginated list of sales.
  Future<SalesPage> listSales({
    int page = 1,
    int pageSize = 20,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      if (status != null) 'status': status,
      if (dateFrom != null)
        'date_from': dateFrom.toIso8601String(),
      if (dateTo != null)
        'date_to': dateTo.toIso8601String(),
    };
    final data =
        await _client.get('/sales/', query: query);
    return SalesPage.fromJson(
        data as Map<String, dynamic>);
  }

  /// Fetch a single sale by ID.
  Future<Sale> getSale(String saleId) async {
    final data = await _client.get('/sales/$saleId');
    return Sale.fromJson(data as Map<String, dynamic>);
  }

  /// Void a completed sale. Requires admin/manager.
  Future<Sale> voidSale(String saleId) async {
    final data =
        await _client.post('/sales/$saleId/void', body: {});
    return Sale.fromJson(data as Map<String, dynamic>);
  }

  /// Fetch aggregated sales summary for a date range.
  Future<SalesSummary> getSummary({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final query = <String, dynamic>{
      if (dateFrom != null)
        'date_from': dateFrom.toIso8601String(),
      if (dateTo != null)
        'date_to': dateTo.toIso8601String(),
    };
    final data =
        await _client.get('/sales/summary', query: query);
    return SalesSummary.fromJson(
        data as Map<String, dynamic>);
  }
}
