"""Create analytics materialized views.

Revision ID: 0003
Revises: 0002
Create Date: 2026-04-01

Creates three materialized views that power the analytics dashboard:
  - daily_sales_summary: per-day revenue and transaction aggregates
  - salesman_kpi: per-salesman performance metrics
  - inventory_snapshot: stock-level snapshots per product-warehouse
"""

from alembic import op


revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Create analytics materialized views with unique indexes."""
    op.execute(
        """
        CREATE MATERIALIZED VIEW IF NOT EXISTS
        daily_sales_summary AS
        SELECT
            st.tenant_id,
            DATE(st.created_at AT TIME ZONE 'UTC') AS sale_date,
            st.warehouse_id,
            COUNT(st.id)              AS total_transactions,
            SUM(st.grand_total)       AS total_revenue,
            AVG(st.grand_total)       AS avg_transaction_value,
            SUM(st.tax_total)         AS total_tax,
            SUM(st.discount)          AS total_discount,
            JSONB_AGG(
                JSONB_BUILD_OBJECT(
                    'product_id',   sli.product_id,
                    'product_name', sli.product_name,
                    'qty_sold',     sli.qty,
                    'revenue',      sli.line_total
                )
            ) FILTER (WHERE sli.id IS NOT NULL) AS top_products,
            JSONB_BUILD_OBJECT(
                'cash',   COALESCE(SUM(p.amount_tendered)
                          FILTER (WHERE p.method = 'cash'), 0),
                'card',   COALESCE(SUM(p.amount_tendered)
                          FILTER (WHERE p.method = 'card'), 0),
                'mobile', COALESCE(SUM(p.amount_tendered)
                          FILTER (WHERE p.method = 'mobile'), 0)
            )                          AS payment_breakdown
        FROM sales_transactions st
        LEFT JOIN sale_line_items sli
               ON sli.transaction_id = st.id
        LEFT JOIN payments p
               ON p.transaction_id = st.id
        WHERE st.status = 'completed'
        GROUP BY
            st.tenant_id,
            DATE(st.created_at AT TIME ZONE 'UTC'),
            st.warehouse_id
        WITH NO DATA
        """
    )
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS
        uix_daily_sales_summary
        ON daily_sales_summary (tenant_id, sale_date, warehouse_id)
        """
    )

    op.execute(
        """
        CREATE MATERIALIZED VIEW IF NOT EXISTS
        salesman_kpi AS
        SELECT
            st.tenant_id,
            st.salesman_id,
            DATE(st.created_at AT TIME ZONE 'UTC') AS kpi_date,
            COUNT(st.id) FILTER (WHERE st.status = 'completed')
                                              AS total_sales,
            COALESCE(
                SUM(st.grand_total)
                FILTER (WHERE st.status = 'completed'), 0
            )                                 AS total_revenue,
            COALESCE(
                AVG(item_counts.cnt)
                FILTER (WHERE st.status = 'completed'), 0
            )                                 AS avg_items_per_sale,
            COUNT(st.id) FILTER (WHERE st.status = 'voided')
                                              AS void_count
        FROM sales_transactions st
        LEFT JOIN (
            SELECT transaction_id, COUNT(*) AS cnt
            FROM sale_line_items
            GROUP BY transaction_id
        ) item_counts ON item_counts.transaction_id = st.id
        WHERE st.salesman_id IS NOT NULL
        GROUP BY
            st.tenant_id,
            st.salesman_id,
            DATE(st.created_at AT TIME ZONE 'UTC')
        WITH NO DATA
        """
    )
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS
        uix_salesman_kpi
        ON salesman_kpi (tenant_id, salesman_id, kpi_date)
        """
    )

    op.execute(
        """
        CREATE MATERIALIZED VIEW IF NOT EXISTS
        inventory_snapshot AS
        SELECT
            p.tenant_id,
            i.product_id,
            i.warehouse_id,
            CURRENT_DATE                 AS snapshot_date,
            i.qty_on_hand,
            COALESCE(sold.qty_sold, 0)   AS qty_sold,
            COALESCE(
                i.qty_on_hand::DECIMAL
                / NULLIF(sold.qty_sold::DECIMAL / 30, 0),
                NULL
            )                            AS days_of_stock
        FROM inventory i
        JOIN products p ON p.id = i.product_id
        LEFT JOIN (
            SELECT
                sli.product_id,
                st.warehouse_id,
                SUM(sli.qty) AS qty_sold
            FROM sale_line_items sli
            JOIN sales_transactions st
              ON st.id = sli.transaction_id
            WHERE st.status = 'completed'
              AND st.created_at >= NOW() - INTERVAL '30 days'
            GROUP BY sli.product_id, st.warehouse_id
        ) sold ON sold.product_id  = i.product_id
              AND sold.warehouse_id = i.warehouse_id
        WHERE p.is_active = TRUE
        WITH NO DATA
        """
    )
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS
        uix_inventory_snapshot
        ON inventory_snapshot (
            tenant_id, product_id, warehouse_id
        )
        """
    )


def downgrade() -> None:
    """Drop analytics materialized views."""
    op.execute(
        "DROP MATERIALIZED VIEW IF EXISTS inventory_snapshot"
    )
    op.execute(
        "DROP MATERIALIZED VIEW IF EXISTS salesman_kpi"
    )
    op.execute(
        "DROP MATERIALIZED VIEW IF EXISTS daily_sales_summary"
    )
