"""Remove tenant_id FK columns from per-tenant tables.

Revision ID: 0005
Revises: 0004
Create Date: 2026-04-04

Drops the tenant_id foreign-key columns from all per-tenant tables
inside each tenant schema. Run this ONLY after cross-tenant isolation
has been validated in Sprint 16 (S16).

At schema-per-tenant level, tenant_id is redundant — every row in
a schema already belongs to that tenant implicitly.
"""

from alembic import op
from sqlalchemy import text

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None

_TABLES_WITH_TENANT_ID = [
    "users",
    "categories",
    "warehouses",
    "products",
    "sales_transactions",
    "audit_log",
    "sync_changelog",
    "sync_conflicts",
]


def upgrade() -> None:
    """
    Drop tenant_id columns from per-tenant tables in every schema.

    Iterates all tenant schemas and drops the redundant tenant_id
    column from each applicable table.

    :return: None
    """
    conn = op.get_bind()

    tenants = conn.execute(
        text("SELECT slug FROM public.tenants")
    ).fetchall()

    for tenant in tenants:
        slug = tenant.slug
        conn.execute(
            text(f'SET search_path TO "{slug}", public')
        )
        for table in _TABLES_WITH_TENANT_ID:
            _drop_tenant_id(conn, table, slug)

    conn.execute(text("SET search_path TO public"))


def _drop_tenant_id(
    conn,
    table: str,
    slug: str,
) -> None:
    """
    Drop the tenant_id column from a table if it exists.

    :param conn: Active SQLAlchemy connection
    :param table: Table name
    :param slug: Schema name (for logging context only)
    :return: None
    """
    exists = conn.execute(
        text(
            "SELECT 1 FROM information_schema.columns "
            "WHERE table_schema = :schema "
            "AND table_name = :tbl "
            "AND column_name = 'tenant_id'"
        ),
        {"schema": slug, "tbl": table},
    ).fetchone()
    if exists:
        conn.execute(
            text(
                f"ALTER TABLE {table} "
                f"DROP COLUMN IF EXISTS tenant_id"
            )
        )


def downgrade() -> None:
    """
    Re-add tenant_id columns to per-tenant tables.

    Re-adds the columns as nullable UUID without FK constraints.
    Restoring FK constraints and data requires a manual step.

    :return: None
    """
    conn = op.get_bind()

    tenants = conn.execute(
        text("SELECT slug FROM public.tenants")
    ).fetchall()

    for tenant in tenants:
        slug = tenant.slug
        conn.execute(
            text(f'SET search_path TO "{slug}", public')
        )
        for table in _TABLES_WITH_TENANT_ID:
            conn.execute(
                text(
                    f"ALTER TABLE {table} "
                    f"ADD COLUMN IF NOT EXISTS tenant_id UUID"
                )
            )

    conn.execute(text("SET search_path TO public"))
