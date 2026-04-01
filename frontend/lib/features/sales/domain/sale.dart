/// Sales domain models.
library;

/// One product line within a sale.
class SaleLineItem {
  /// Creates a [SaleLineItem].
  const SaleLineItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.qty,
    required this.unitPrice,
    required this.taxRate,
    required this.lineTotal,
    required this.lineTax,
  });

  /// Line item UUID.
  final String id;

  /// Product UUID (nullable if product deleted).
  final String? productId;

  /// Snapshot product name at time of sale.
  final String productName;

  /// Units sold.
  final int qty;

  /// Price per unit.
  final double unitPrice;

  /// Tax rate applied.
  final double taxRate;

  /// qty * unitPrice.
  final double lineTotal;

  /// Tax amount for this line.
  final double lineTax;

  /// Deserialises from API JSON.
  factory SaleLineItem.fromJson(Map<String, dynamic> json) {
    return SaleLineItem(
      id: json['id'] as String,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String,
      qty: json['qty'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      taxRate: (json['tax_rate'] as num).toDouble(),
      lineTotal: (json['line_total'] as num).toDouble(),
      lineTax: (json['line_tax'] as num).toDouble(),
    );
  }
}

/// Payment record attached to a sale.
class SalePayment {
  /// Creates a [SalePayment].
  const SalePayment({
    required this.id,
    required this.method,
    required this.amountTendered,
    required this.changeGiven,
    required this.reference,
    required this.paidAt,
  });

  /// Payment UUID.
  final String id;

  /// cash | card | mobile.
  final String method;

  /// Amount given by the customer.
  final double amountTendered;

  /// Change returned.
  final double changeGiven;

  /// Optional terminal reference.
  final String? reference;

  /// Payment timestamp.
  final DateTime paidAt;

  /// Deserialises from API JSON.
  factory SalePayment.fromJson(Map<String, dynamic> json) {
    return SalePayment(
      id: json['id'] as String,
      method: json['method'] as String,
      amountTendered:
          (json['amount_tendered'] as num).toDouble(),
      changeGiven:
          (json['change_given'] as num).toDouble(),
      reference: json['reference'] as String?,
      paidAt: DateTime.parse(json['paid_at'] as String),
    );
  }
}

/// Full sale record including line items and payment.
class Sale {
  /// Creates a [Sale].
  const Sale({
    required this.id,
    required this.invoiceNumber,
    required this.salesmanId,
    required this.salesmanName,
    required this.warehouseId,
    required this.warehouseName,
    required this.subtotal,
    required this.taxTotal,
    required this.discount,
    required this.grandTotal,
    required this.status,
    required this.lineItems,
    required this.payment,
    required this.createdAt,
  });

  /// Transaction UUID.
  final String id;

  /// Human-readable invoice number.
  final String invoiceNumber;

  /// Staff UUID who made the sale.
  final String? salesmanId;

  /// Resolved staff name.
  final String? salesmanName;

  /// Source warehouse UUID.
  final String? warehouseId;

  /// Resolved warehouse name.
  final String? warehouseName;

  /// Sum of line totals before tax/discount.
  final double subtotal;

  /// Total tax.
  final double taxTotal;

  /// Transaction-level discount.
  final double discount;

  /// Final amount charged.
  final double grandTotal;

  /// completed | voided.
  final String status;

  /// Individual product lines.
  final List<SaleLineItem> lineItems;

  /// Payment record.
  final SalePayment? payment;

  /// Sale timestamp.
  final DateTime createdAt;

  /// Whether this sale has been voided.
  bool get isVoided => status == 'voided';

  /// Deserialises from API JSON.
  factory Sale.fromJson(Map<String, dynamic> json) {
    final paymentJson =
        json['payment'] as Map<String, dynamic>?;
    return Sale(
      id: json['id'] as String,
      invoiceNumber: json['invoice_number'] as String,
      salesmanId: json['salesman_id'] as String?,
      salesmanName: json['salesman_name'] as String?,
      warehouseId: json['warehouse_id'] as String?,
      warehouseName: json['warehouse_name'] as String?,
      subtotal: (json['subtotal'] as num).toDouble(),
      taxTotal: (json['tax_total'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
      grandTotal: (json['grand_total'] as num).toDouble(),
      status: json['status'] as String,
      lineItems: (json['line_items'] as List<dynamic>)
          .map(
            (e) => SaleLineItem.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      payment: paymentJson != null
          ? SalePayment.fromJson(paymentJson)
          : null,
      createdAt:
          DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Compact sale entry used in list responses.
class SaleListItem {
  /// Creates a [SaleListItem].
  const SaleListItem({
    required this.id,
    required this.invoiceNumber,
    required this.salesmanName,
    required this.warehouseName,
    required this.grandTotal,
    required this.status,
    required this.itemCount,
    required this.createdAt,
  });

  /// Transaction UUID.
  final String id;

  /// Human-readable invoice number.
  final String invoiceNumber;

  /// Resolved staff name.
  final String? salesmanName;

  /// Resolved warehouse name.
  final String? warehouseName;

  /// Final amount charged.
  final double grandTotal;

  /// completed | voided.
  final String status;

  /// Number of distinct product lines.
  final int itemCount;

  /// Sale timestamp.
  final DateTime createdAt;

  /// Deserialises from API JSON.
  factory SaleListItem.fromJson(Map<String, dynamic> json) {
    return SaleListItem(
      id: json['id'] as String,
      invoiceNumber: json['invoice_number'] as String,
      salesmanName: json['salesman_name'] as String?,
      warehouseName: json['warehouse_name'] as String?,
      grandTotal: (json['grand_total'] as num).toDouble(),
      status: json['status'] as String,
      itemCount: json['item_count'] as int,
      createdAt:
          DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Paginated sales list response.
class SalesPage {
  /// Creates a [SalesPage].
  const SalesPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  /// Sales on the current page.
  final List<SaleListItem> items;

  /// Total matching sales.
  final int total;

  /// Current page (1-based).
  final int page;

  /// Items per page.
  final int pageSize;

  /// Deserialises from API JSON.
  factory SalesPage.fromJson(Map<String, dynamic> json) {
    return SalesPage(
      items: (json['items'] as List<dynamic>)
          .map(
            (e) => SaleListItem.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
    );
  }
}

/// A single top-selling product entry.
class TopProduct {
  /// Creates a [TopProduct].
  const TopProduct({
    required this.productId,
    required this.productName,
    required this.qtySold,
    required this.revenue,
  });

  /// Product UUID.
  final String? productId;

  /// Product display name.
  final String productName;

  /// Total units sold.
  final int qtySold;

  /// Total revenue from this product.
  final double revenue;

  /// Deserialises from API JSON.
  factory TopProduct.fromJson(Map<String, dynamic> json) {
    return TopProduct(
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String,
      qtySold: json['qty_sold'] as int,
      revenue: (json['revenue'] as num).toDouble(),
    );
  }
}

/// Aggregated sales summary for a date range.
class SalesSummary {
  /// Creates a [SalesSummary].
  const SalesSummary({
    required this.dateFrom,
    required this.dateTo,
    required this.totalSales,
    required this.totalRevenue,
    required this.totalTax,
    required this.totalDiscount,
    required this.voidedCount,
    required this.topProducts,
  });

  /// Start of range (inclusive).
  final DateTime dateFrom;

  /// End of range (inclusive).
  final DateTime dateTo;

  /// Number of completed transactions.
  final int totalSales;

  /// Sum of grand_totals for completed sales.
  final double totalRevenue;

  /// Sum of tax_totals for completed sales.
  final double totalTax;

  /// Sum of discounts for completed sales.
  final double totalDiscount;

  /// Number of voided transactions.
  final int voidedCount;

  /// Up to 5 best-selling products by qty.
  final List<TopProduct> topProducts;

  /// Deserialises from API JSON.
  factory SalesSummary.fromJson(Map<String, dynamic> json) {
    return SalesSummary(
      dateFrom:
          DateTime.parse(json['date_from'] as String),
      dateTo: DateTime.parse(json['date_to'] as String),
      totalSales: json['total_sales'] as int,
      totalRevenue:
          (json['total_revenue'] as num).toDouble(),
      totalTax: (json['total_tax'] as num).toDouble(),
      totalDiscount:
          (json['total_discount'] as num).toDouble(),
      voidedCount: json['voided_count'] as int,
      topProducts: (json['top_products'] as List<dynamic>)
          .map(
            (e) => TopProduct.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

/// A cart line item pending checkout.
class CartItem {
  /// Creates a [CartItem].
  const CartItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.taxRate,
    required this.qty,
  });

  /// Product UUID.
  final String productId;

  /// Product display name.
  final String productName;

  /// Unit price.
  final double unitPrice;

  /// Tax rate (0.0 – 1.0).
  final double taxRate;

  /// Quantity in cart.
  final int qty;

  /// Line total before tax.
  double get lineTotal => unitPrice * qty;

  /// Tax amount for this line.
  double get lineTax => lineTotal * taxRate;

  /// Returns a copy with overridden fields.
  CartItem copyWith({int? qty, double? unitPrice}) {
    return CartItem(
      productId: productId,
      productName: productName,
      unitPrice: unitPrice ?? this.unitPrice,
      taxRate: taxRate,
      qty: qty ?? this.qty,
    );
  }
}
