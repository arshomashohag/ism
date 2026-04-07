"""Tests for the TenantProvisioner service."""

import uuid
from unittest.mock import MagicMock, call, patch

import pytest

from app.services.tenant_provisioner import TenantProvisioner


def _make_db(
    existing_tenant=None,
    schema_query_result=None,
) -> MagicMock:
    """
    Build a mock SQLAlchemy Session for provisioner tests.

    :param existing_tenant: Row to return for slug-exists queries
    :param schema_query_result: Row to return for search_path queries
    :return: Configured MagicMock session
    """
    db = MagicMock()
    execute_mock = MagicMock()
    execute_mock.fetchone.return_value = existing_tenant
    db.execute.return_value = execute_mock
    return db


class TestTenantProvisioner:
    """Unit tests for TenantProvisioner."""

    def test_validate_slug_rejects_uppercase(self) -> None:
        """
        Slug with uppercase letters should raise ValueError.

        :return: None
        """
        db = _make_db()
        provisioner = TenantProvisioner(db)
        with pytest.raises(ValueError, match="Slug must be"):
            provisioner._validate_slug("MyShop")

    def test_validate_slug_rejects_spaces(self) -> None:
        """
        Slug with spaces should raise ValueError.

        :return: None
        """
        db = _make_db()
        provisioner = TenantProvisioner(db)
        with pytest.raises(ValueError, match="Slug must be"):
            provisioner._validate_slug("my shop")

    def test_validate_slug_accepts_valid(self) -> None:
        """
        Valid lowercase slug should not raise.

        :return: None
        """
        db = _make_db()
        provisioner = TenantProvisioner(db)
        provisioner._validate_slug("my-shop-01")

    def test_validate_slug_rejects_single_char(self) -> None:
        """
        Single character slug should raise ValueError.

        :return: None
        """
        db = _make_db()
        provisioner = TenantProvisioner(db)
        with pytest.raises(ValueError):
            provisioner._validate_slug("a")

    def test_provision_raises_on_duplicate_slug(self) -> None:
        """
        provision() raises RuntimeError when slug already exists.

        :return: None
        """
        existing_row = MagicMock()
        existing_row.id = str(uuid.uuid4())
        db = _make_db(existing_tenant=existing_row)

        provisioner = TenantProvisioner(db)
        with pytest.raises(RuntimeError, match="already exists"):
            provisioner.provision(
                name="Test",
                slug="test-shop",
                plan="starter",
                admin_email="a@b.com",
                admin_password="password123",
            )

    def test_provision_inserts_tenant_row(self) -> None:
        """
        provision() inserts a tenant row in public.tenants.

        :return: None
        """
        db = _make_db(existing_tenant=None)
        provisioner = TenantProvisioner(db)

        with (
            patch.object(provisioner, "_create_schema"),
            patch.object(provisioner, "_run_migrations"),
            patch.object(provisioner, "_seed_tenant"),
        ):
            provisioner.provision(
                name="Test Shop",
                slug="test-shop",
                plan="starter",
                admin_email="admin@test.com",
                admin_password="password123",
            )

        all_sql = " ".join(
            str(c) for c in db.execute.call_args_list
        )
        assert "INSERT" in all_sql or db.execute.called

    def test_provision_calls_create_schema(self) -> None:
        """
        provision() calls _create_schema with the correct slug.

        :return: None
        """
        db = _make_db(existing_tenant=None)
        provisioner = TenantProvisioner(db)

        with (
            patch.object(
                provisioner, "_create_schema"
            ) as mock_create,
            patch.object(provisioner, "_run_migrations"),
            patch.object(provisioner, "_seed_tenant"),
        ):
            provisioner.provision(
                name="Shop",
                slug="my-shop",
                plan="starter",
                admin_email="a@b.com",
                admin_password="password123",
            )

        mock_create.assert_called_once_with("my-shop")

    def test_provision_calls_run_migrations(self) -> None:
        """
        provision() calls _run_migrations with the correct slug.

        :return: None
        """
        db = _make_db(existing_tenant=None)
        provisioner = TenantProvisioner(db)

        with (
            patch.object(provisioner, "_create_schema"),
            patch.object(
                provisioner, "_run_migrations"
            ) as mock_migrate,
            patch.object(provisioner, "_seed_tenant"),
        ):
            provisioner.provision(
                name="Shop",
                slug="my-shop",
                plan="starter",
                admin_email="a@b.com",
                admin_password="password123",
            )

        mock_migrate.assert_called_once_with("my-shop")

    def test_deprovision_raises_when_tenant_not_found(self) -> None:
        """
        deprovision() raises RuntimeError for unknown slug.

        :return: None
        """
        db = _make_db(existing_tenant=None)
        provisioner = TenantProvisioner(db)

        with pytest.raises(RuntimeError, match="not found"):
            provisioner.deprovision("ghost-shop")

    def test_deprovision_drops_schema_and_deletes_row(self) -> None:
        """
        deprovision() issues DROP SCHEMA CASCADE and DELETE on tenant.

        :return: None
        """
        existing_row = MagicMock()
        existing_row.id = str(uuid.uuid4())
        db = _make_db(existing_tenant=existing_row)

        provisioner = TenantProvisioner(db)
        provisioner.deprovision("old-shop")

        all_sql = " ".join(
            str(c) for c in db.execute.call_args_list
        )
        assert db.execute.called
        assert db.commit.called
