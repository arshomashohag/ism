"""Tests verifying all SQLAlchemy models load and are well-formed."""

from app.models import Base
from app.models.audit_log import AuditLog
from app.models.category import Category
from app.models.inventory import Inventory
from app.models.payment import Payment
from app.models.product import Product
from app.models.sale_line_item import SaleLineItem
from app.models.sales_transaction import SalesTransaction
from app.models.sync_changelog import SyncChangelog
from app.models.sync_conflict import SyncConflict
from app.models.tenant import Tenant
from app.models.user import User
from app.models.warehouse import Warehouse

EXPECTED_TABLES = {
    "tenants",
    "users",
    "categories",
    "warehouses",
    "products",
    "inventory",
    "sales_transactions",
    "sale_line_items",
    "payments",
    "audit_log",
    "sync_changelog",
    "sync_conflicts",
}


def test_all_tables_registered() -> None:
    """
    Verify all 12 tables are registered in Base.metadata.

    :return: None
    """
    assert set(Base.metadata.tables.keys()) == EXPECTED_TABLES


def test_tenant_columns() -> None:
    """
    Verify tenants table has required columns.

    :return: None
    """
    cols = {c.name for c in Tenant.__table__.columns}
    assert {"id", "name", "slug", "plan", "is_active"}.issubset(cols)


def test_user_columns() -> None:
    """
    Verify users table has required columns including role.

    :return: None
    """
    cols = {c.name for c in User.__table__.columns}
    assert {
        "id", "tenant_id", "email", "password_hash", "role"
    }.issubset(cols)


def test_product_columns() -> None:
    """
    Verify products table has all core business columns.

    :return: None
    """
    cols = {c.name for c in Product.__table__.columns}
    assert {
        "id", "tenant_id", "category_id", "sku", "name",
        "barcode", "unit_price", "cost_price", "tax_rate",
        "metadata", "hlc_timestamp", "is_active",
    }.issubset(cols)


def test_inventory_unique_constraint() -> None:
    """
    Verify the product/warehouse unique constraint exists.

    :return: None
    """
    constraint_names = {
        c.name for c in Inventory.__table__.constraints
    }
    assert "uq_inventory_product_warehouse" in constraint_names


def test_product_check_constraints() -> None:
    """
    Verify price check constraints are present on products.

    :return: None
    """
    constraint_names = {
        c.name for c in Product.__table__.constraints
    }
    assert "ck_products_unit_price_positive" in constraint_names
    assert "ck_products_cost_price_nonneg" in constraint_names


def test_user_unique_constraint() -> None:
    """
    Verify the tenant/email unique constraint exists on users.

    :return: None
    """
    constraint_names = {
        c.name for c in User.__table__.constraints
    }
    assert "uq_users_tenant_email" in constraint_names


def test_sales_transaction_columns() -> None:
    """
    Verify sales_transactions has all required financial columns.

    :return: None
    """
    cols = {c.name for c in SalesTransaction.__table__.columns}
    assert {
        "id", "tenant_id", "invoice_number",
        "subtotal", "tax_total", "discount", "grand_total",
        "status", "device_id",
    }.issubset(cols)


def test_sale_line_item_columns() -> None:
    """
    Verify sale_line_items captures price snapshot fields.

    :return: None
    """
    cols = {c.name for c in SaleLineItem.__table__.columns}
    assert {
        "transaction_id", "product_id", "product_name",
        "qty", "unit_price", "tax_rate", "line_total", "line_tax",
    }.issubset(cols)


def test_payment_columns() -> None:
    """
    Verify payments table has method and tendered amount.

    :return: None
    """
    cols = {c.name for c in Payment.__table__.columns}
    assert {
        "transaction_id", "method",
        "amount_tendered", "change_given",
    }.issubset(cols)


def test_audit_log_columns() -> None:
    """
    Verify audit_log captures old and new JSONB values.

    :return: None
    """
    cols = {c.name for c in AuditLog.__table__.columns}
    assert {
        "tenant_id", "user_id", "entity_type",
        "entity_id", "action", "old_value", "new_value",
    }.issubset(cols)


def test_sync_changelog_hlc_column() -> None:
    """
    Verify sync_changelog has hlc_timestamp for delta pulls.

    :return: None
    """
    cols = {c.name for c in SyncChangelog.__table__.columns}
    assert "hlc_timestamp" in cols


def test_sync_conflict_status_column() -> None:
    """
    Verify sync_conflicts has a status column for resolution flow.

    :return: None
    """
    cols = {c.name for c in SyncConflict.__table__.columns}
    assert {"status", "version_a", "version_b"}.issubset(cols)
