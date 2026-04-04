"""Tenant provisioning service — schema creation and teardown."""

import logging
import re
import uuid

from alembic.config import Config
from sqlalchemy import text
from sqlalchemy.orm import Session

from alembic import command
from app.services.auth import PasswordService

logger = logging.getLogger("ims.tenant_provisioner")

_SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{1,98}[a-z0-9]$")

_ALEMBIC_CFG_PATH = "alembic.ini"

_PER_TENANT_TABLES = [
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
]

_DEFAULT_WAREHOUSE_NAME = "Main Store"


class TenantProvisioner:
    """
    Manages PostgreSQL schema lifecycle for tenants.

    Each tenant gets an isolated schema named after their slug.
    All per-tenant tables are created inside that schema via Alembic
    DDL, giving true row-level isolation without any shared tables.

    :ivar db: Admin-scoped SQLAlchemy session (public schema)
    """

    def __init__(self, db: Session) -> None:
        """
        Initialise the provisioner with an admin DB session.

        :param db: SQLAlchemy session scoped to the public schema
        """
        self.db = db

    def provision(
        self,
        name: str,
        slug: str,
        plan: str,
        admin_email: str,
        admin_password: str,
    ) -> uuid.UUID:
        """
        Provision a new tenant: schema + tables + seed data.

        Steps:
        1. Validate the slug format.
        2. Check for duplicate slug in public.tenants.
        3. Insert the tenant row in public.tenants.
        4. CREATE SCHEMA {slug}.
        5. Run Alembic DDL inside that schema.
        6. Seed the default admin user and warehouse.

        :param name: Human-readable tenant name
        :param slug: URL-safe lowercase identifier (2–100 chars)
        :param plan: Subscription plan (e.g. ``starter``)
        :param admin_email: Email for the seeded admin user
        :param admin_password: Plain-text password for the admin user
        :return: New tenant UUID
        :raises ValueError: If slug format is invalid
        :raises RuntimeError: If a tenant with that slug already exists
        """
        self._validate_slug(slug)

        existing = self.db.execute(
            text("SELECT id FROM tenants WHERE slug = :slug"),
            {"slug": slug},
        ).fetchone()
        if existing is not None:
            raise RuntimeError(
                f"Tenant with slug '{slug}' already exists"
            )

        tenant_id = uuid.uuid4()
        self.db.execute(
            text(
                "INSERT INTO tenants "
                "(id, name, slug, plan, is_active, schema_name) "
                "VALUES (:id, :name, :slug, :plan, true, :schema)"
            ),
            {
                "id": str(tenant_id),
                "name": name,
                "slug": slug,
                "plan": plan,
                "schema": slug,
            },
        )
        self.db.commit()

        self._create_schema(slug)
        self._run_migrations(slug)
        self._seed_tenant(slug, tenant_id, admin_email, admin_password)

        logger.info(
            "Tenant provisioned",
            extra={"tenant_id": str(tenant_id), "slug": slug},
        )
        return tenant_id

    def deprovision(self, slug: str) -> None:
        """
        Remove a tenant's schema and all its data permanently.

        Drops the PostgreSQL schema with CASCADE and removes the
        public.tenants row.

        :param slug: Tenant slug to remove
        :return: None
        :raises RuntimeError: If the tenant does not exist
        """
        existing = self.db.execute(
            text("SELECT id FROM tenants WHERE slug = :slug"),
            {"slug": slug},
        ).fetchone()
        if existing is None:
            raise RuntimeError(
                f"Tenant '{slug}' not found"
            )

        self.db.execute(
            text(f'DROP SCHEMA IF EXISTS "{slug}" CASCADE')
        )
        self.db.execute(
            text("DELETE FROM tenants WHERE slug = :slug"),
            {"slug": slug},
        )
        self.db.commit()

        logger.info(
            "Tenant deprovisioned", extra={"slug": slug}
        )

    def _validate_slug(self, slug: str) -> None:
        """
        Ensure the slug matches the allowed pattern.

        :param slug: Slug to validate
        :return: None
        :raises ValueError: If the slug is invalid
        """
        if not _SLUG_RE.match(slug):
            raise ValueError(
                "Slug must be 2–100 lowercase alphanumeric characters, "
                "hyphens, or underscores, starting and ending with "
                "alphanumeric."
            )

    def _create_schema(self, slug: str) -> None:
        """
        Create a PostgreSQL schema for the tenant.

        :param slug: Schema name to create
        :return: None
        """
        self.db.execute(
            text(f'CREATE SCHEMA IF NOT EXISTS "{slug}"')
        )
        self.db.commit()

    def _run_migrations(self, slug: str) -> None:
        """
        Run Alembic migrations targeting the tenant schema.

        Sets the search_path so Alembic DDL creates all tables
        inside the tenant's schema rather than public.

        :param slug: Schema name to migrate
        :return: None
        """
        cfg = Config(_ALEMBIC_CFG_PATH)
        cfg.attributes["tenant_schema"] = slug
        cfg.set_main_option(
            "sqlalchemy.url",
            str(self.db.bind.url),  # type: ignore[union-attr]
        )
        cfg.attributes["connection"] = self.db.connection()
        cfg.attributes["target_schema"] = slug

        self.db.execute(
            text(f"SET search_path TO {slug}, public")
        )
        command.upgrade(cfg, "head")
        self.db.execute(
            text("SET search_path TO public")
        )
        self.db.commit()

    def _seed_tenant(
        self,
        slug: str,
        tenant_id: uuid.UUID,
        admin_email: str,
        admin_password: str,
    ) -> None:
        """
        Seed the default admin user and warehouse for a new tenant.

        :param slug: Tenant schema name
        :param tenant_id: Tenant primary key UUID
        :param admin_email: Admin user email
        :param admin_password: Plain-text admin password
        :return: None
        """
        self.db.execute(
            text(f"SET LOCAL search_path TO {slug}, public")
        )

        admin_id = uuid.uuid4()
        pw_hash = PasswordService.hash(admin_password)
        self.db.execute(
            text(
                "INSERT INTO users "
                "(id, tenant_id, name, email, password_hash, role) "
                "VALUES (:id, :tid, :name, :email, :pw, 'admin')"
            ),
            {
                "id": str(admin_id),
                "tid": str(tenant_id),
                "name": "Admin",
                "email": admin_email,
                "pw": pw_hash,
            },
        )

        warehouse_id = uuid.uuid4()
        self.db.execute(
            text(
                "INSERT INTO warehouses (id, tenant_id, name) "
                "VALUES (:id, :tid, :name)"
            ),
            {
                "id": str(warehouse_id),
                "tid": str(tenant_id),
                "name": _DEFAULT_WAREHOUSE_NAME,
            },
        )

        self.db.commit()
        self.db.execute(
            text("SET search_path TO public")
        )
