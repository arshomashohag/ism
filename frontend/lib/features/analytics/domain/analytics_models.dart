/// Analytics domain models for the dashboard.
library;

/// A single day's aggregated sales data point.
class DailySalesPoint {
  /// Creates a [DailySalesPoint].
  const DailySalesPoint({
    required this.saleDate,
    required this.totalRevenue,
    required this.totalTransactions,
    required this.avgTransactionValue,
  });

  /// Deserialise from API JSON.
  factory DailySalesPoint.fromJson(
      Map<String, dynamic> json) {
    return DailySalesPoint(
      saleDate: DateTime.parse(
          json['sale_date'] as String),
      totalRevenue:
          (json['total_revenue'] as num).toDouble(),
      totalTransactions:
          json['total_transactions'] as int,
      avgTransactionValue:
          (json['avg_transaction_value'] as num)
              .toDouble(),
    );
  }

  /// Calendar date of this data point.
  final DateTime saleDate;

  /// Sum of grand_totals for that day.
  final double totalRevenue;

  /// Count of completed transactions.
  final int totalTransactions;

  /// Revenue divided by transaction count.
  final double avgTransactionValue;
}

/// Top-selling product entry.
class TopProductAnalytics {
  /// Creates a [TopProductAnalytics].
  const TopProductAnalytics({
    required this.productId,
    required this.productName,
    required this.qtySold,
    required this.revenue,
  });

  /// Deserialise from API JSON.
  factory TopProductAnalytics.fromJson(
      Map<String, dynamic> json) {
    return TopProductAnalytics(
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String,
      qtySold: json['qty_sold'] as int,
      revenue: (json['revenue'] as num).toDouble(),
    );
  }

  /// Product UUID (null if product deleted).
  final String? productId;

  /// Product display name.
  final String productName;

  /// Total units sold.
  final int qtySold;

  /// Total revenue.
  final double revenue;
}

/// Aggregated sales KPIs with period-over-period growth.
class SalesSummaryAnalytics {
  /// Creates a [SalesSummaryAnalytics].
  const SalesSummaryAnalytics({
    required this.dateFrom,
    required this.dateTo,
    required this.totalRevenue,
    required this.totalTransactions,
    required this.avgTransactionValue,
    required this.totalTax,
    required this.totalDiscount,
    required this.voidedCount,
    required this.revenueGrowthPct,
    required this.transactionsGrowthPct,
    required this.dailyTrend,
    required this.topProducts,
  });

  /// Deserialise from API JSON.
  factory SalesSummaryAnalytics.fromJson(
      Map<String, dynamic> json) {
    return SalesSummaryAnalytics(
      dateFrom:
          DateTime.parse(json['date_from'] as String),
      dateTo: DateTime.parse(json['date_to'] as String),
      totalRevenue:
          (json['total_revenue'] as num).toDouble(),
      totalTransactions:
          json['total_transactions'] as int,
      avgTransactionValue:
          (json['avg_transaction_value'] as num)
              .toDouble(),
      totalTax: (json['total_tax'] as num).toDouble(),
      totalDiscount:
          (json['total_discount'] as num).toDouble(),
      voidedCount: json['voided_count'] as int,
      revenueGrowthPct:
          (json['revenue_growth_pct'] as num?)
              ?.toDouble(),
      transactionsGrowthPct:
          (json['transactions_growth_pct'] as num?)
              ?.toDouble(),
      dailyTrend: (json['daily_trend'] as List<dynamic>)
          .map((e) => DailySalesPoint.fromJson(
              e as Map<String, dynamic>))
          .toList(),
      topProducts:
          (json['top_products'] as List<dynamic>)
              .map((e) => TopProductAnalytics.fromJson(
                  e as Map<String, dynamic>))
              .toList(),
    );
  }

  /// Start of the query range.
  final DateTime dateFrom;

  /// End of the query range.
  final DateTime dateTo;

  /// Sum of completed grand_totals.
  final double totalRevenue;

  /// Count of completed transactions.
  final int totalTransactions;

  /// Revenue / transactions.
  final double avgTransactionValue;

  /// Sum of tax totals.
  final double totalTax;

  /// Sum of discounts.
  final double totalDiscount;

  /// Count of voided transactions.
  final int voidedCount;

  /// Period-over-period revenue growth percentage (null if no prior data).
  final double? revenueGrowthPct;

  /// Period-over-period transaction growth percentage.
  final double? transactionsGrowthPct;

  /// Per-day revenue trend for the chart.
  final List<DailySalesPoint> dailyTrend;

  /// Top 5 products by revenue.
  final List<TopProductAnalytics> topProducts;
}

/// Per-salesman KPI row.
class SalesmanKpiRow {
  /// Creates a [SalesmanKpiRow].
  const SalesmanKpiRow({
    required this.salesmanId,
    required this.salesmanName,
    required this.totalSales,
    required this.totalRevenue,
    required this.avgItemsPerSale,
    required this.voidCount,
  });

  /// Deserialise from API JSON.
  factory SalesmanKpiRow.fromJson(
      Map<String, dynamic> json) {
    return SalesmanKpiRow(
      salesmanId: json['salesman_id'] as String,
      salesmanName: json['salesman_name'] as String,
      totalSales: json['total_sales'] as int,
      totalRevenue:
          (json['total_revenue'] as num).toDouble(),
      avgItemsPerSale:
          (json['avg_items_per_sale'] as num).toDouble(),
      voidCount: json['void_count'] as int,
    );
  }

  /// User UUID.
  final String salesmanId;

  /// Display name.
  final String salesmanName;

  /// Completed transaction count.
  final int totalSales;

  /// Revenue generated.
  final double totalRevenue;

  /// Average line items per sale.
  final double avgItemsPerSale;

  /// Voided transaction count.
  final int voidCount;
}

/// Salesman leaderboard for a date range.
class SalesmanKpiData {
  /// Creates a [SalesmanKpiData].
  const SalesmanKpiData({
    required this.dateFrom,
    required this.dateTo,
    required this.rows,
  });

  /// Deserialise from API JSON.
  factory SalesmanKpiData.fromJson(
      Map<String, dynamic> json) {
    return SalesmanKpiData(
      dateFrom:
          DateTime.parse(json['date_from'] as String),
      dateTo: DateTime.parse(json['date_to'] as String),
      rows: (json['rows'] as List<dynamic>)
          .map((e) => SalesmanKpiRow.fromJson(
              e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Range start.
  final DateTime dateFrom;

  /// Range end.
  final DateTime dateTo;

  /// KPI rows sorted by revenue desc.
  final List<SalesmanKpiRow> rows;
}

/// Stock health row per product-warehouse pair.
class InventoryHealthRow {
  /// Creates an [InventoryHealthRow].
  const InventoryHealthRow({
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.warehouseId,
    required this.warehouseName,
    required this.qtyOnHand,
    required this.reorderPoint,
    required this.stockStatus,
    required this.qtySold30d,
    required this.daysOfStock,
  });

  /// Deserialise from API JSON.
  factory InventoryHealthRow.fromJson(
      Map<String, dynamic> json) {
    return InventoryHealthRow(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      productSku: json['product_sku'] as String,
      warehouseId: json['warehouse_id'] as String,
      warehouseName: json['warehouse_name'] as String,
      qtyOnHand: json['qty_on_hand'] as int,
      reorderPoint: json['reorder_point'] as int,
      stockStatus: json['stock_status'] as String,
      qtySold30d: json['qty_sold_30d'] as int,
      daysOfStock: (json['days_of_stock'] as num?)
          ?.toDouble(),
    );
  }

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

  /// Low-stock threshold.
  final int reorderPoint;

  /// ok | low | out.
  final String stockStatus;

  /// Units sold in last 30 days.
  final int qtySold30d;

  /// Estimated days of stock remaining.
  final double? daysOfStock;
}

/// Inventory health snapshot for the dashboard.
class InventoryHealthData {
  /// Creates an [InventoryHealthData].
  const InventoryHealthData({
    required this.snapshotAt,
    required this.totalSkus,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.rows,
  });

  /// Deserialise from API JSON.
  factory InventoryHealthData.fromJson(
      Map<String, dynamic> json) {
    return InventoryHealthData(
      snapshotAt:
          DateTime.parse(json['snapshot_at'] as String),
      totalSkus: json['total_skus'] as int,
      lowStockCount: json['low_stock_count'] as int,
      outOfStockCount: json['out_of_stock_count'] as int,
      rows: (json['rows'] as List<dynamic>)
          .map((e) => InventoryHealthRow.fromJson(
              e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Timestamp when data was gathered.
  final DateTime snapshotAt;

  /// Total active product-warehouse pairs.
  final int totalSkus;

  /// Count of low-stock products.
  final int lowStockCount;

  /// Count of out-of-stock products.
  final int outOfStockCount;

  /// Per-product health rows.
  final List<InventoryHealthRow> rows;
}
