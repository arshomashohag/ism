/// Inventory repository — API calls for stock management.
library;

import '../../../core/network/api_client.dart';
import '../domain/inventory_entry.dart';

/// Handles all inventory-related API calls.
class InventoryRepository {
  /// Creates an [InventoryRepository].
  InventoryRepository({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// Fetch a paginated inventory list, optionally filtered.
  Future<InventoryPage> listInventory({
    int page = 1,
    int pageSize = 50,
    String? warehouseId,
    bool lowStock = false,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      if (warehouseId != null) 'warehouse_id': warehouseId,
      if (lowStock) 'low_stock': 'true',
    };
    final data =
        await _client.get('/inventory/', query: query);
    return InventoryPage.fromJson(
        data as Map<String, dynamic>);
  }

  /// Adjust stock by a signed delta. Requires admin/manager.
  Future<InventoryEntry> adjustStock({
    required String warehouseId,
    required String productId,
    required int delta,
    required String reason,
  }) async {
    final body = <String, dynamic>{
      'warehouse_id': warehouseId,
      'product_id': productId,
      'delta': delta,
      'reason': reason,
    };
    final data =
        await _client.post('/inventory/adjust', body: body);
    return InventoryEntry.fromJson(
        data as Map<String, dynamic>);
  }

  /// Transfer stock between warehouses. Requires admin/manager.
  Future<List<InventoryEntry>> transferStock({
    required String productId,
    required String fromWarehouseId,
    required String toWarehouseId,
    required int qty,
    required String reason,
  }) async {
    final body = <String, dynamic>{
      'product_id': productId,
      'from_warehouse_id': fromWarehouseId,
      'to_warehouse_id': toWarehouseId,
      'qty': qty,
      'reason': reason,
    };
    final data =
        await _client.post('/inventory/transfer', body: body);
    return (data as List<dynamic>)
        .map(
          (e) => InventoryEntry.fromJson(
            e as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  /// Record a physical stock count. Requires admin/manager.
  Future<InventoryEntry> recordCount({
    required String warehouseId,
    required String productId,
    required int countedQty,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'warehouse_id': warehouseId,
      'product_id': productId,
      'counted_qty': countedQty,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final data =
        await _client.post('/inventory/count', body: body);
    return InventoryEntry.fromJson(
        data as Map<String, dynamic>);
  }

  /// Fetch all low-stock and out-of-stock alerts.
  Future<List<StockAlert>> getAlerts() async {
    final data = await _client.get('/inventory/alerts');
    return (data as List<dynamic>)
        .map(
          (e) => StockAlert.fromJson(
            e as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  /// Fetch all active warehouses.
  Future<List<Warehouse>> listWarehouses() async {
    final data = await _client.get('/inventory/warehouses');
    return (data as List<dynamic>)
        .map(
          (e) => Warehouse.fromJson(
            e as Map<String, dynamic>,
          ),
        )
        .toList();
  }
}
