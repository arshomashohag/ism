"""Pydantic schemas for analytics response models."""

import uuid
from datetime import date, datetime

from pydantic import BaseModel


class DailySalesPoint(BaseModel):
    """
    Single day's aggregated sales data for trend charts.

    :ivar sale_date: The calendar date
    :ivar total_revenue: Sum of completed grand_totals
    :ivar total_transactions: Count of completed sales
    :ivar avg_transaction_value: Revenue divided by transactions
    """

    sale_date: date
    total_revenue: float
    total_transactions: int
    avg_transaction_value: float


class SalesSummaryResponse(BaseModel):
    """
    Sales KPI summary with period-over-period growth.

    :ivar date_from: Start of the query range
    :ivar date_to: End of the query range
    :ivar total_revenue: Sum of completed grand_totals
    :ivar total_transactions: Count of completed sales
    :ivar avg_transaction_value: Revenue / transactions
    :ivar total_tax: Sum of tax_totals
    :ivar total_discount: Sum of discounts
    :ivar voided_count: Number of voided transactions
    :ivar revenue_growth_pct: Period-over-period revenue growth %
    :ivar transactions_growth_pct: Period-over-period txn growth %
    :ivar daily_trend: Per-day breakdown for trend chart
    :ivar top_products: Top 5 products by revenue
    """

    date_from: datetime
    date_to: datetime
    total_revenue: float
    total_transactions: int
    avg_transaction_value: float
    total_tax: float
    total_discount: float
    voided_count: int
    revenue_growth_pct: float | None
    transactions_growth_pct: float | None
    daily_trend: list[DailySalesPoint]
    top_products: list["TopProductAnalytics"]


class TopProductAnalytics(BaseModel):
    """
    Top-selling product entry for analytics.

    :ivar product_id: Product UUID
    :ivar product_name: Product display name
    :ivar qty_sold: Total units sold
    :ivar revenue: Total revenue from this product
    """

    product_id: uuid.UUID | None
    product_name: str
    qty_sold: int
    revenue: float


class SalesmanKpiRow(BaseModel):
    """
    Per-salesman KPI row for the leaderboard.

    :ivar salesman_id: User UUID
    :ivar salesman_name: Display name
    :ivar total_sales: Number of completed transactions
    :ivar total_revenue: Revenue generated
    :ivar avg_items_per_sale: Average line items per transaction
    :ivar void_count: Number of voided transactions
    """

    salesman_id: uuid.UUID
    salesman_name: str
    total_sales: int
    total_revenue: float
    avg_items_per_sale: float
    void_count: int


class SalesmanKpiResponse(BaseModel):
    """
    Salesman leaderboard for a date range.

    :ivar date_from: Start of the query range
    :ivar date_to: End of the query range
    :ivar rows: Per-salesman KPI rows sorted by revenue desc
    """

    date_from: datetime
    date_to: datetime
    rows: list[SalesmanKpiRow]


class InventoryHealthRow(BaseModel):
    """
    Stock health summary row per product-warehouse pair.

    :ivar product_id: Product UUID
    :ivar product_name: Product display name
    :ivar product_sku: Product SKU
    :ivar warehouse_id: Warehouse UUID
    :ivar warehouse_name: Warehouse display name
    :ivar qty_on_hand: Current on-hand quantity
    :ivar reorder_point: Low-stock threshold
    :ivar stock_status: ok | low | out
    :ivar qty_sold_30d: Units sold in last 30 days
    :ivar days_of_stock: Estimated days of stock remaining
    """

    product_id: uuid.UUID
    product_name: str
    product_sku: str
    warehouse_id: uuid.UUID
    warehouse_name: str
    qty_on_hand: int
    reorder_point: int
    stock_status: str
    qty_sold_30d: int
    days_of_stock: float | None


class InventoryHealthResponse(BaseModel):
    """
    Inventory health snapshot for the dashboard.

    :ivar snapshot_at: Timestamp when data was gathered
    :ivar total_skus: Total active product-warehouse pairs
    :ivar low_stock_count: Products at or below reorder point
    :ivar out_of_stock_count: Products with zero on-hand
    :ivar rows: Per-product health rows
    """

    snapshot_at: datetime
    total_skus: int
    low_stock_count: int
    out_of_stock_count: int
    rows: list[InventoryHealthRow]


class RefreshResponse(BaseModel):
    """
    Result of a manual analytics refresh.

    :ivar refreshed_at: Timestamp of the refresh
    :ivar message: Human-readable status
    """

    refreshed_at: datetime
    message: str
