/// Inventory domain entities.
library;

/// Stock health classification.
enum StockStatus {
  /// Quantity is above reorder point.
  ok,

  /// Quantity is at or below reorder point but above zero.
  low,

  /// Quantity is zero or negative.
  out;

  /// Deserializes from backend string value.
  static StockStatus fromString(String value) {
    switch (value) {
      case 'low':
        return StockStatus.low;
      case 'out':
        return StockStatus.out;
      default:
        return StockStatus.ok;
    }
  }
}

/// Stock level for one product at one warehouse.
class InventoryEntry {
  /// Creates an [InventoryEntry].
  const InventoryEntry({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.warehouseId,
    required this.warehouseName,
    required this.qtyOnHand,
    required this.qtyReserved,
    required this.qtyAvailable,
    required this.reorderPoint,
    required this.stockStatus,
    this.lastCountedAt,
  });

  /// Inventory record UUID.
  final String id;

  /// Associated product UUID.
  final String productId;

  /// Resolved product name.
  final String productName;

  /// Product SKU.
  final String productSku;

  /// Associated warehouse UUID.
  final String warehouseId;

  /// Resolved warehouse name.
  final String warehouseName;

  /// Current on-hand quantity.
  final int qtyOnHand;

  /// Reserved quantity.
  final int qtyReserved;

  /// Available quantity (on_hand - reserved).
  final int qtyAvailable;

  /// Low-stock alert threshold.
  final int reorderPoint;

  /// Stock health classification.
  final StockStatus stockStatus;

  /// Timestamp of last physical count.
  final DateTime? lastCountedAt;

  /// Deserializes from backend JSON map.
  factory InventoryEntry.fromJson(Map<String, dynamic> json) {
    return InventoryEntry(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      productSku: json['product_sku'] as String,
      warehouseId: json['warehouse_id'] as String,
      warehouseName: json['warehouse_name'] as String,
      qtyOnHand: (json['qty_on_hand'] as num).toInt(),
      qtyReserved: (json['qty_reserved'] as num).toInt(),
      qtyAvailable: (json['qty_available'] as num).toInt(),
      reorderPoint: (json['reorder_point'] as num).toInt(),
      stockStatus: StockStatus.fromString(
        json['stock_status'] as String? ?? 'ok',
      ),
      lastCountedAt: json['last_counted_at'] != null
          ? DateTime.parse(json['last_counted_at'] as String)
          : null,
    );
  }
}

/// Paginated list of inventory entries.
class InventoryPage {
  /// Creates an [InventoryPage].
  const InventoryPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  /// Entries on this page.
  final List<InventoryEntry> items;

  /// Total matching entries across all pages.
  final int total;

  /// Current page (1-indexed).
  final int page;

  /// Items per page.
  final int pageSize;

  /// Whether more pages exist.
  bool get hasMore => page * pageSize < total;

  /// Deserializes from backend JSON map.
  factory InventoryPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>;
    return InventoryPage(
      items: rawItems
          .map(
            (i) => InventoryEntry.fromJson(
              i as Map<String, dynamic>,
            ),
          )
          .toList(),
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      pageSize: (json['page_size'] as num).toInt(),
    );
  }
}

/// Brief stock snapshot for a single warehouse (embedded in product).
class InventorySummaryItem {
  /// Creates an [InventorySummaryItem].
  const InventorySummaryItem({
    required this.warehouseId,
    required this.warehouseName,
    required this.qtyOnHand,
    required this.qtyReserved,
    required this.qtyAvailable,
    required this.reorderPoint,
    required this.stockStatus,
  });

  /// Warehouse UUID.
  final String warehouseId;

  /// Warehouse display name.
  final String warehouseName;

  /// On-hand quantity.
  final int qtyOnHand;

  /// Reserved quantity.
  final int qtyReserved;

  /// Available quantity.
  final int qtyAvailable;

  /// Low-stock threshold.
  final int reorderPoint;

  /// Stock health.
  final StockStatus stockStatus;

  /// Deserializes from backend JSON map.
  factory InventorySummaryItem.fromJson(
      Map<String, dynamic> json) {
    return InventorySummaryItem(
      warehouseId: json['warehouse_id'] as String,
      warehouseName: json['warehouse_name'] as String,
      qtyOnHand: (json['qty_on_hand'] as num).toInt(),
      qtyReserved: (json['qty_reserved'] as num).toInt(),
      qtyAvailable: (json['qty_available'] as num).toInt(),
      reorderPoint: (json['reorder_point'] as num).toInt(),
      stockStatus: StockStatus.fromString(
        json['stock_status'] as String? ?? 'ok',
      ),
    );
  }
}

/// Low-stock or out-of-stock alert.
class StockAlert {
  /// Creates a [StockAlert].
  const StockAlert({
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.warehouseId,
    required this.warehouseName,
    required this.qtyOnHand,
    required this.reorderPoint,
    required this.stockStatus,
  });

  /// Product UUID.
  final String productId;

  /// Product display name.
  final String productName;

  /// Product SKU.
  final String productSku;

  /// Warehouse UUID.
  final String warehouseId;

  /// Warehouse display name.
  final String warehouseName;

  /// Current on-hand quantity.
  final int qtyOnHand;

  /// Configured threshold.
  final int reorderPoint;

  /// low or out.
  final StockStatus stockStatus;

  /// Deserializes from backend JSON map.
  factory StockAlert.fromJson(Map<String, dynamic> json) {
    return StockAlert(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      productSku: json['product_sku'] as String,
      warehouseId: json['warehouse_id'] as String,
      warehouseName: json['warehouse_name'] as String,
      qtyOnHand: (json['qty_on_hand'] as num).toInt(),
      reorderPoint: (json['reorder_point'] as num).toInt(),
      stockStatus: StockStatus.fromString(
        json['stock_status'] as String? ?? 'low',
      ),
    );
  }
}

/// Represents a warehouse for selection UI.
class Warehouse {
  /// Creates a [Warehouse].
  const Warehouse({
    required this.id,
    required this.name,
    required this.isActive,
  });

  /// Warehouse UUID.
  final String id;

  /// Display name.
  final String name;

  /// Whether warehouse is active.
  final bool isActive;

  /// Deserializes from backend JSON map.
  factory Warehouse.fromJson(Map<String, dynamic> json) {
    return Warehouse(
      id: json['id'] as String,
      name: json['name'] as String,
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
}
