"""Initial schema — all tables, indexes, pg_trgm extension.

Revision ID: 0001
Revises:
Create Date: 2026-03-31
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    """
    Create all IMS tables and indexes.

    :return: None
    """
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    op.create_table(
        "tenants",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
        ),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column(
            "slug", sa.String(100), nullable=False, unique=True
        ),
        sa.Column(
            "plan",
            sa.String(50),
            nullable=False,
            server_default="starter",
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default="true",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )

    op.create_table(
        "users",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
        ),
        sa.Column(
            "tenant_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("tenants.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column(
            "password_hash", sa.String(255), nullable=False
        ),
        sa.Column(
            "role",
            sa.String(20),
            nullable=False,
            server_default="salesman",
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default="true",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint(
            "tenant_id", "email", name="uq_users_tenant_email"
        ),
    )
    op.create_index("ix_users_tenant_id", "users", ["tenant_id"])

    op.create_table(
        "categories",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
        ),
        sa.Column(
            "tenant_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("tenants.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "parent_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey(
                "categories.id", ondelete="SET NULL"
            ),
            nullable=True,
        ),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_categories_tenant_id", "categories", ["tenant_id"]
    )

    op.create_table(
        "warehouses",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
        ),
        sa.Column(
            "tenant_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("tenants.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("address", sa.String(500), nullable=True),
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default="true",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_warehouses_tenant_id", "warehouses", ["tenant_id"]
    )

    op.create_table(
        "products",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
        ),
        sa.Column(
            "tenant_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("tenants.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "category_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey(
                "categories.id", ondelete="SET NULL"
            ),
            nullable=True,
        ),
        sa.Column("sku", sa.String(50), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("barcode", sa.String(100), nullable=True),
        sa.Column(
            "unit_price", sa.Numeric(12, 2), nullable=False
        ),
        sa.Column(
            "cost_price", sa.Numeric(12, 2), nullable=True
        ),
        sa.Column(
            "tax_rate",
            sa.Numeric(5, 4),
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "metadata",
            postgresql.JSONB(),
            nullable=False,
            server_default=sa.text("'{}'"),
        ),
        sa.Column(
            "is_hub_shared",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default="true",
        ),
        sa.Column(
            "hlc_timestamp",
            sa.BigInteger(),
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint(
            "tenant_id", "sku", name="uq_products_tenant_sku"
        ),
        sa.CheckConstraint(
            "unit_price > 0", name="ck_products_unit_price_positive"
        ),
        sa.CheckConstraint(
            "cost_price >= 0 OR cost_price IS NULL",
            name="ck_products_cost_price_nonneg",
        ),
    )
    op.create_index(
        "ix_products_tenant_id", "products", ["tenant_id"]
    )
    op.create_index(
        "ix_products_category_id", "products", ["category_id"]
    )
    op.create_index(
        "ix_products_barcode", "products", ["barcode"]
    )
    op.execute(
        "CREATE INDEX ix_products_name_trgm ON products "
        "USING GIN (name gin_trgm_ops)"
    )

    op.create_table(
        "inventory",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
        ),
        sa.Column(
            "product_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("products.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "warehouse_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("warehouses.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "qty_on_hand",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "qty_reserved",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "reorder_point",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "hlc_timestamp",
            sa.BigInteger(),
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "last_counted_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.UniqueConstraint(
            "product_id",
            "warehouse_id",
            name="uq_inventory_product_warehouse",
        ),
    )

    op.create_table(
        "sales_transactions",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
        ),
        sa.Column(
            "tenant_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("tenants.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "invoice_number",
            sa.String(30),
            nullable=False,
            unique=True,
        ),
        sa.Column(
            "salesman_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "warehouse_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("warehouses.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "subtotal", sa.Numeric(12, 2), nullable=False
        ),
        sa.Column(
            "tax_total", sa.Numeric(12, 2), nullable=False
        ),
        sa.Column(
            "discount",
            sa.Numeric(12, 2),
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "grand_total", sa.Numeric(12, 2), nullable=False
        ),
        sa.Column(
            "status",
            sa.String(20),
            nullable=False,
            server_default="completed",
        ),
        sa.Column(
            "device_id", sa.String(100), nullable=False
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "synced_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )
    op.create_index(
        "ix_sales_tenant_id",
        "sales_transactions",
        ["tenant_id"],
    )
    op.create_index(
        "ix_sales_salesman_id",
        "sales_transactions",
        ["salesman_id"],
    )
    op.create_index(
        "ix_sales_created_at",
        "sales_transactions",
        ["created_at"],
    )

    op.create_table(
        "sale_line_items",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
        ),
        sa.Column(
            "transaction_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey(
                "sales_transactions.id", ondelete="CASCADE"
            ),
            nullable=False,
        ),
        sa.Column(
            "product_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("products.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "product_name", sa.String(255), nullable=False
        ),
        sa.Column("qty", sa.Integer(), nullable=False),
        sa.Column(
            "unit_price", sa.Numeric(12, 2), nullable=False
        ),
        sa.Column(
            "tax_rate",
            sa.Numeric(5, 4),
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "line_total", sa.Numeric(12, 2), nullable=False
        ),
        sa.Column(
            "line_tax",
            sa.Numeric(12, 2),
            nullable=False,
            server_default="0",
        ),
    )
    op.create_index(
        "ix_sale_line_items_transaction_id",
        "sale_line_items",
        ["transaction_id"],
    )
    op.create_index(
        "ix_sale_line_items_product_id",
        "sale_line_items",
        ["product_id"],
    )

    op.create_table(
        "payments",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
        ),
        sa.Column(
            "transaction_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey(
                "sales_transactions.id", ondelete="CASCADE"
            ),
            nullable=False,
            unique=True,
        ),
        sa.Column("method", sa.String(20), nullable=False),
        sa.Column(
            "amount_tendered", sa.Numeric(12, 2), nullable=False
        ),
        sa.Column(
            "change_given",
            sa.Numeric(12, 2),
            nullable=False,
            server_default="0",
        ),
        sa.Column("reference", sa.String(100), nullable=True),
        sa.Column(
            "paid_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_payments_transaction_id",
        "payments",
        ["transaction_id"],
    )

    op.create_table(
        "audit_log",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
        ),
        sa.Column(
            "tenant_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("tenants.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "entity_type", sa.String(50), nullable=False
        ),
        sa.Column("entity_id", sa.Text(), nullable=False),
        sa.Column("action", sa.String(20), nullable=False),
        sa.Column(
            "old_value", postgresql.JSONB(), nullable=True
        ),
        sa.Column(
            "new_value", postgresql.JSONB(), nullable=True
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_audit_log_tenant_id", "audit_log", ["tenant_id"]
    )
    op.create_index(
        "ix_audit_log_user_id", "audit_log", ["user_id"]
    )
    op.create_index(
        "ix_audit_log_entity_type",
        "audit_log",
        ["entity_type"],
    )
    op.create_index(
        "ix_audit_log_created_at",
        "audit_log",
        ["created_at"],
    )

    op.create_table(
        "sync_changelog",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
        ),
        sa.Column(
            "tenant_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("tenants.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "product_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("products.id", ondelete="CASCADE"),
            nullable=True,
        ),
        sa.Column(
            "entity_type", sa.String(50), nullable=False
        ),
        sa.Column(
            "operation", sa.String(10), nullable=False
        ),
        sa.Column(
            "delta", postgresql.JSONB(), nullable=False
        ),
        sa.Column(
            "hlc_timestamp",
            sa.BigInteger(),
            nullable=False,
        ),
        sa.Column(
            "device_id", sa.String(100), nullable=False
        ),
        sa.Column(
            "applied_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_sync_changelog_tenant_id",
        "sync_changelog",
        ["tenant_id"],
    )
    op.create_index(
        "ix_sync_changelog_product_id",
        "sync_changelog",
        ["product_id"],
    )
    op.create_index(
        "ix_sync_changelog_hlc",
        "sync_changelog",
        ["hlc_timestamp"],
    )

    op.create_table(
        "sync_conflicts",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
        ),
        sa.Column(
            "tenant_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("tenants.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "entity_type", sa.String(50), nullable=False
        ),
        sa.Column(
            "entity_id", sa.String(100), nullable=False
        ),
        sa.Column(
            "version_a", postgresql.JSONB(), nullable=False
        ),
        sa.Column(
            "version_b", postgresql.JSONB(), nullable=False
        ),
        sa.Column(
            "status",
            sa.String(20),
            nullable=False,
            server_default="pending",
        ),
        sa.Column(
            "resolved_by_device",
            sa.String(100),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "resolved_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )
    op.create_index(
        "ix_sync_conflicts_tenant_id",
        "sync_conflicts",
        ["tenant_id"],
    )
    op.create_index(
        "ix_sync_conflicts_created_at",
        "sync_conflicts",
        ["created_at"],
    )


def downgrade() -> None:
    """
    Drop all IMS tables and extensions.

    :return: None
    """
    op.drop_table("sync_conflicts")
    op.drop_table("sync_changelog")
    op.drop_table("audit_log")
    op.drop_table("payments")
    op.drop_table("sale_line_items")
    op.drop_table("sales_transactions")
    op.drop_table("inventory")
    op.drop_table("products")
    op.drop_table("warehouses")
    op.drop_table("categories")
    op.drop_table("users")
    op.drop_table("tenants")
    op.execute("DROP EXTENSION IF EXISTS pg_trgm")
