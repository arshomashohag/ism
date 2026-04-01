/// Product domain entity.
library;

import '../../inventory/domain/inventory_entry.dart';

/// Represents a single product in the catalog.
class Product {
  /// Creates a [Product].
  const Product({
    required this.id,
    required this.tenantId,
    required this.sku,
    required this.name,
    required this.unitPrice,
    this.categoryId,
    this.categoryName,
    this.barcode,
    this.costPrice,
    this.taxRate,
    this.isActive = true,
    this.metadata = const {},
    this.inventorySummary = const [],
  });

  /// Product UUID.
  final String id;

  /// Tenant this product belongs to.
  final String tenantId;

  /// Stock-keeping unit code.
  final String sku;

  /// Display name.
  final String name;

  /// Selling price.
  final double unitPrice;

  /// Category UUID, null if uncategorised.
  final String? categoryId;

  /// Resolved category name for display.
  final String? categoryName;

  /// Barcode string (EAN/UPC/etc.).
  final String? barcode;

  /// Purchase/cost price.
  final double? costPrice;

  /// Tax rate in [0, 1].
  final double? taxRate;

  /// Whether the product is active (not deleted).
  final bool isActive;

  /// Arbitrary metadata key-value pairs.
  final Map<String, dynamic> metadata;

  /// Per-warehouse stock summary.
  final List<InventorySummaryItem> inventorySummary;

  /// Deserializes from a backend JSON map.
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      sku: json['sku'] as String,
      name: json['name'] as String,
      unitPrice: (json['unit_price'] as num).toDouble(),
      categoryId: json['category_id'] as String?,
      categoryName: json['category_name'] as String?,
      barcode: json['barcode'] as String?,
      costPrice: json['cost_price'] != null
          ? (json['cost_price'] as num).toDouble()
          : null,
      taxRate: json['tax_rate'] != null
          ? (json['tax_rate'] as num).toDouble()
          : null,
      isActive: (json['is_active'] as bool?) ?? true,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      inventorySummary: (json['inventory_summary'] as List<dynamic>?)
              ?.map(
                (e) => InventorySummaryItem.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
    );
  }

  /// Returns a copy with the given fields overridden.
  Product copyWith({
    String? name,
    double? unitPrice,
    String? categoryId,
    String? categoryName,
    String? barcode,
    double? costPrice,
    double? taxRate,
  }) {
    return Product(
      id: id,
      tenantId: tenantId,
      sku: sku,
      name: name ?? this.name,
      unitPrice: unitPrice ?? this.unitPrice,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      barcode: barcode ?? this.barcode,
      costPrice: costPrice ?? this.costPrice,
      taxRate: taxRate ?? this.taxRate,
      isActive: isActive,
      metadata: metadata,
    );
  }
}

/// Paginated list of products with total count.
class ProductPage {
  /// Creates a [ProductPage].
  const ProductPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  /// Products on this page.
  final List<Product> items;

  /// Total matching products across all pages.
  final int total;

  /// Current page (1-indexed).
  final int page;

  /// Number of items per page.
  final int pageSize;

  /// Whether there are more pages after this one.
  bool get hasMore => page * pageSize < total;

  /// Deserializes from a backend JSON map.
  factory ProductPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>;
    return ProductPage(
      items: rawItems
          .map((i) => Product.fromJson(i as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      pageSize: (json['page_size'] as num).toInt(),
    );
  }
}
