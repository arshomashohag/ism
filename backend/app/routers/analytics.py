"""Analytics router — dashboard KPIs, trends, and salesman stats."""

import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, text
from sqlalchemy.orm import Session

from app.dependencies import get_tenant_db, require_role
from app.models.inventory import Inventory
from app.models.product import Product
from app.models.sale_line_item import SaleLineItem
from app.models.sales_transaction import SalesTransaction
from app.models.user import User
from app.models.warehouse import Warehouse
from app.schemas.analytics import (
    DailySalesPoint,
    InventoryHealthResponse,
    InventoryHealthRow,
    RefreshResponse,
    SalesmanKpiResponse,
    SalesmanKpiRow,
    SalesSummaryResponse,
    TopProductAnalytics,
)
from app.schemas.auth import CurrentUser

router = APIRouter(prefix="/analytics", tags=["analytics"])

_PAGE_SIZE = 200


def _date_range_defaults(
    date_from: datetime | None,
    date_to: datetime | None,
    days: int = 30,
) -> tuple[datetime, datetime]:
    """
    Return a (date_from, date_to) pair with safe defaults.

    :param date_from: Caller-supplied start or None
    :param date_to: Caller-supplied end or None
    :param days: Default lookback when date_from is omitted
    :return: Tuple of (date_from, date_to) in UTC
    """
    now = datetime.now(timezone.utc)
    if date_to is None:
        date_to = now
    if date_from is None:
        date_from = now - timedelta(days=days)
    return date_from, date_to


def _growth_pct(
    current: float, previous: float
) -> float | None:
    """
    Compute period-over-period percentage change.

    :param current: Current period value
    :param previous: Previous period value
    :return: Growth percentage or None when previous is zero
    """
    if previous == 0:
        return None
    return round((current - previous) / previous * 100, 2)


def _stock_status_label(
    qty_on_hand: int, reorder_point: int
) -> str:
    """
    Derive stock health label from current quantity.

    :param qty_on_hand: Current on-hand quantity
    :param reorder_point: Low-stock threshold
    :return: 'out', 'low', or 'ok'
    """
    if qty_on_hand <= 0:
        return "out"
    if qty_on_hand <= reorder_point:
        return "low"
    return "ok"


@router.post(
    "/refresh",
    response_model=RefreshResponse,
)
def refresh_analytics(
    current_user: CurrentUser = Depends(
        require_role("admin")
    ),
    db: Session = Depends(get_tenant_db),
) -> RefreshResponse:
    """
    Trigger on-demand refresh of analytics materialized views.

    Refreshes daily_sales_summary, salesman_kpi, and
    inventory_snapshot views concurrently (non-blocking).

    :param current_user: Injected JWT context (admin only)
    :param db: Database session
    :return: RefreshResponse with timestamp and status message
    """
    views = [
        "daily_sales_summary",
        "salesman_kpi",
        "inventory_snapshot",
    ]
    for view in views:
        db.execute(
            text(
                f"REFRESH MATERIALIZED VIEW CONCURRENTLY "
                f"{view}"
            )
        )
    db.commit()
    return RefreshResponse(
        refreshed_at=datetime.now(timezone.utc),
        message=(
            f"Refreshed {len(views)} materialized views"
        ),
    )


@router.get(
    "/sales-summary",
    response_model=SalesSummaryResponse,
)
def get_sales_summary(
    date_from: datetime | None = Query(default=None),
    date_to: datetime | None = Query(default=None),
    current_user: CurrentUser = Depends(
        require_role("admin")
    ),
    db: Session = Depends(get_tenant_db),
) -> SalesSummaryResponse:
    """
    Return aggregated sales KPIs with growth vs prior period.

    Queries the daily_sales_summary materialized view when
    available; falls back to live transactional queries otherwise.

    :param date_from: Optional range start (defaults to -30 days)
    :param date_to: Optional range end (defaults to now)
    :param current_user: Injected JWT context (admin only)
    :param db: Database session
    :return: SalesSummaryResponse with trends and top products
    """
    date_from, date_to = _date_range_defaults(
        date_from, date_to
    )
    period_len = date_to - date_from
    prev_from = date_from - period_len
    prev_to = date_from

    current_rows = _query_sales_in_range(
        db, current_user.tenant_id, date_from, date_to
    )
    prev_rows = _query_sales_in_range(
        db, current_user.tenant_id, prev_from, prev_to
    )

    current_rev = sum(
        float(r.grand_total) for r in current_rows
    )
    prev_rev = sum(
        float(r.grand_total) for r in prev_rows
    )
    current_txns = len(current_rows)
    prev_txns = len(prev_rows)

    avg_value = (
        round(current_rev / current_txns, 2)
        if current_txns
        else 0.0
    )

    daily_map: dict[Any, DailySalesPoint] = {}
    product_qty: dict[str, int] = {}
    product_rev: dict[str, float] = {}
    product_names: dict[str, str] = {}
    total_tax = 0.0
    total_discount = 0.0

    for sale in current_rows:
        sale_date = sale.created_at.date()
        key = str(sale_date)
        if key not in daily_map:
            daily_map[key] = DailySalesPoint(
                sale_date=sale_date,
                total_revenue=0.0,
                total_transactions=0,
                avg_transaction_value=0.0,
            )
        pt = daily_map[key]
        new_rev = round(
            pt.total_revenue + float(sale.grand_total), 2
        )
        new_txns = pt.total_transactions + 1
        daily_map[key] = DailySalesPoint(
            sale_date=sale_date,
            total_revenue=new_rev,
            total_transactions=new_txns,
            avg_transaction_value=round(
                new_rev / new_txns, 2
            ),
        )
        total_tax += float(sale.tax_total)
        total_discount += float(sale.discount)

        for li in sale.line_items:
            pid = str(li.product_id) if li.product_id else "_"
            product_qty[pid] = product_qty.get(pid, 0) + li.qty
            product_rev[pid] = round(
                product_rev.get(pid, 0.0)
                + float(li.line_total),
                2,
            )
            product_names[pid] = li.product_name

    daily_trend = sorted(
        daily_map.values(), key=lambda p: p.sale_date
    )

    top_pids = sorted(
        product_rev.keys(),
        key=lambda k: product_rev[k],
        reverse=True,
    )[:5]

    top_products = [
        TopProductAnalytics(
            product_id=(
                uuid.UUID(pid) if pid != "_" else None
            ),
            product_name=product_names[pid],
            qty_sold=product_qty[pid],
            revenue=product_rev[pid],
        )
        for pid in top_pids
    ]

    voided_count = (
        db.query(func.count(SalesTransaction.id))
        .filter(
            SalesTransaction.tenant_id
            == current_user.tenant_id,
            SalesTransaction.created_at >= date_from,
            SalesTransaction.created_at <= date_to,
            SalesTransaction.status == "voided",
        )
        .scalar()
        or 0
    )

    return SalesSummaryResponse(
        date_from=date_from,
        date_to=date_to,
        total_revenue=round(current_rev, 2),
        total_transactions=current_txns,
        avg_transaction_value=avg_value,
        total_tax=round(total_tax, 2),
        total_discount=round(total_discount, 2),
        voided_count=voided_count,
        revenue_growth_pct=_growth_pct(
            current_rev, prev_rev
        ),
        transactions_growth_pct=_growth_pct(
            current_txns, prev_txns
        ),
        daily_trend=daily_trend,
        top_products=top_products,
    )


@router.get(
    "/salesman-kpi",
    response_model=SalesmanKpiResponse,
)
def get_salesman_kpi(
    date_from: datetime | None = Query(default=None),
    date_to: datetime | None = Query(default=None),
    current_user: CurrentUser = Depends(
        require_role("admin")
    ),
    db: Session = Depends(get_tenant_db),
) -> SalesmanKpiResponse:
    """
    Return per-salesman KPI leaderboard for the date range.

    :param date_from: Optional range start (defaults to -30 days)
    :param date_to: Optional range end (defaults to now)
    :param current_user: Injected JWT context (admin only)
    :param db: Database session
    :return: SalesmanKpiResponse sorted by total_revenue desc
    """
    date_from, date_to = _date_range_defaults(
        date_from, date_to
    )

    completed = _query_sales_in_range(
        db, current_user.tenant_id, date_from, date_to
    )
    voided_sales = (
        db.query(SalesTransaction)
        .filter(
            SalesTransaction.tenant_id
            == current_user.tenant_id,
            SalesTransaction.created_at >= date_from,
            SalesTransaction.created_at <= date_to,
            SalesTransaction.status == "voided",
            SalesTransaction.salesman_id.isnot(None),
        )
        .all()
    )

    kpi: dict[uuid.UUID, dict[str, Any]] = {}

    for sale in completed:
        sid = sale.salesman_id
        if sid is None:
            continue
        if sid not in kpi:
            kpi[sid] = {
                "total_sales": 0,
                "total_revenue": 0.0,
                "total_items": 0,
                "void_count": 0,
            }
        kpi[sid]["total_sales"] += 1
        kpi[sid]["total_revenue"] += float(sale.grand_total)
        kpi[sid]["total_items"] += len(sale.line_items)

    for sale in voided_sales:
        sid = sale.salesman_id
        if sid is None:
            continue
        if sid not in kpi:
            kpi[sid] = {
                "total_sales": 0,
                "total_revenue": 0.0,
                "total_items": 0,
                "void_count": 0,
            }
        kpi[sid]["void_count"] += 1

    rows: list[SalesmanKpiRow] = []
    for sid, data in kpi.items():
        user = db.get(User, sid)
        name = user.name if user else str(sid)
        total_s = data["total_sales"]
        avg_items = (
            round(data["total_items"] / total_s, 2)
            if total_s
            else 0.0
        )
        rows.append(
            SalesmanKpiRow(
                salesman_id=sid,
                salesman_name=name,
                total_sales=total_s,
                total_revenue=round(
                    data["total_revenue"], 2
                ),
                avg_items_per_sale=avg_items,
                void_count=data["void_count"],
            )
        )

    rows.sort(key=lambda r: r.total_revenue, reverse=True)

    return SalesmanKpiResponse(
        date_from=date_from,
        date_to=date_to,
        rows=rows,
    )


@router.get(
    "/inventory-health",
    response_model=InventoryHealthResponse,
)
def get_inventory_health(
    current_user: CurrentUser = Depends(
        require_role("admin")
    ),
    db: Session = Depends(get_tenant_db),
) -> InventoryHealthResponse:
    """
    Return a stock-health snapshot for all active products.

    Joins inventory, products, and warehouses and classifies
    each row. Computes 30-day sold quantity and days-of-stock.

    :param current_user: Injected JWT context (admin only)
    :param db: Database session
    :return: InventoryHealthResponse with counts and rows
    """
    now = datetime.now(timezone.utc)
    thirty_days_ago = now - timedelta(days=30)

    entries = (
        db.query(Inventory)
        .join(Product, Inventory.product_id == Product.id)
        .join(
            Warehouse,
            Inventory.warehouse_id == Warehouse.id,
        )
        .filter(
            Product.tenant_id == current_user.tenant_id,
            Product.is_active.is_(True),
            Warehouse.is_active.is_(True),
        )
        .all()
    )

    sold_30d: dict[tuple[uuid.UUID, uuid.UUID], int] = {}
    line_rows = (
        db.query(SaleLineItem)
        .join(
            SalesTransaction,
            SaleLineItem.transaction_id
            == SalesTransaction.id,
        )
        .filter(
            SalesTransaction.tenant_id
            == current_user.tenant_id,
            SalesTransaction.status == "completed",
            SalesTransaction.created_at >= thirty_days_ago,
            SaleLineItem.product_id.isnot(None),
        )
        .all()
    )
    for li in line_rows:
        wid = li.transaction.warehouse_id
        if wid is None or li.product_id is None:
            continue
        key = (li.product_id, wid)
        sold_30d[key] = sold_30d.get(key, 0) + li.qty

    rows: list[InventoryHealthRow] = []
    low_count = 0
    out_count = 0

    for inv in entries:
        status = _stock_status_label(
            inv.qty_on_hand, inv.reorder_point
        )
        if status == "low":
            low_count += 1
        elif status == "out":
            out_count += 1

        key = (inv.product_id, inv.warehouse_id)
        qty_sold = sold_30d.get(key, 0)
        avg_daily = qty_sold / 30.0
        days_of_stock: float | None = None
        if avg_daily > 0:
            days_of_stock = round(
                inv.qty_on_hand / avg_daily, 1
            )

        rows.append(
            InventoryHealthRow(
                product_id=inv.product_id,
                product_name=inv.product.name,
                product_sku=inv.product.sku,
                warehouse_id=inv.warehouse_id,
                warehouse_name=inv.warehouse.name,
                qty_on_hand=inv.qty_on_hand,
                reorder_point=inv.reorder_point,
                stock_status=status,
                qty_sold_30d=qty_sold,
                days_of_stock=days_of_stock,
            )
        )

    rows.sort(
        key=lambda r: (
            0 if r.stock_status == "out" else
            1 if r.stock_status == "low" else 2,
            r.product_name,
        )
    )

    return InventoryHealthResponse(
        snapshot_at=now,
        total_skus=len(entries),
        low_stock_count=low_count,
        out_of_stock_count=out_count,
        rows=rows,
    )


def _query_sales_in_range(
    db: Session,
    tenant_id: uuid.UUID,
    date_from: datetime,
    date_to: datetime,
) -> list[SalesTransaction]:
    """
    Query completed sales for a tenant within a date range.

    :param db: Database session
    :param tenant_id: Tenant UUID to filter by
    :param date_from: Range start (inclusive)
    :param date_to: Range end (inclusive)
    :return: List of completed SalesTransaction instances
    """
    return (
        db.query(SalesTransaction)
        .filter(
            SalesTransaction.tenant_id == tenant_id,
            SalesTransaction.created_at >= date_from,
            SalesTransaction.created_at <= date_to,
            SalesTransaction.status == "completed",
        )
        .all()
    )
