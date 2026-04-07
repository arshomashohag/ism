"""Tests for the /admin/* tenant management endpoints."""

import uuid
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from app.config import settings
from app.dependencies import get_admin_db
from app.main import app
from app.models.tenant import Tenant

_ADMIN_KEY = settings.admin_api_key
_HEADERS = {"X-Admin-Key": _ADMIN_KEY}
_BAD_HEADERS = {"X-Admin-Key": "wrong-key"}


def _make_tenant(
    slug: str = "test-shop",
    plan: str = "starter",
    is_active: bool = True,
) -> MagicMock:
    """
    Build a mock Tenant ORM object.

    :param slug: Tenant slug
    :param plan: Subscription plan
    :param is_active: Active status
    :return: MagicMock shaped like a Tenant
    """
    t = MagicMock(spec=Tenant)
    t.id = uuid.uuid4()
    t.name = "Test Shop"
    t.slug = slug
    t.plan = plan
    t.is_active = is_active
    t.schema_name = slug
    t.created_at = datetime(2026, 1, 1, tzinfo=timezone.utc)
    return t


def _make_db(query_result=None, count_result: int = 0) -> MagicMock:
    """
    Build a mock SQLAlchemy session for admin router tests.

    :param query_result: Value to return from .first() or .all()
    :param count_result: Value to return from .scalar()
    :return: Configured MagicMock session
    """
    db = MagicMock()
    q = db.query.return_value
    q.filter.return_value.first.return_value = query_result
    q.filter.return_value.all.return_value = (
        [query_result] if query_result else []
    )
    q.scalar.return_value = count_result
    q.order_by.return_value.offset.return_value\
        .limit.return_value.all.return_value = (
        [query_result] if query_result else []
    )
    return db


@pytest.mark.asyncio
async def test_provision_tenant_requires_admin_key() -> None:
    """
    POST /admin/tenants returns 403 without a valid X-Admin-Key.

    :return: None
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        response = await client.post(
            "/admin/tenants",
            json={
                "name": "Shop",
                "slug": "shop01",
                "admin_email": "a@b.com",
                "admin_password": "password123",
            },
            headers=_BAD_HEADERS,
        )

    assert response.status_code == 403


@pytest.mark.asyncio
async def test_list_tenants_requires_admin_key() -> None:
    """
    GET /admin/tenants returns 403 without a valid X-Admin-Key.

    :return: None
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        response = await client.get(
            "/admin/tenants", headers=_BAD_HEADERS
        )

    assert response.status_code == 403


@pytest.mark.asyncio
async def test_get_tenant_not_found() -> None:
    """
    GET /admin/tenants/{slug} returns 404 for unknown slug.

    :return: None
    """
    db = _make_db(query_result=None)
    app.dependency_overrides[get_admin_db] = lambda: db

    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        response = await client.get(
            "/admin/tenants/ghost", headers=_HEADERS
        )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_get_tenant_returns_tenant() -> None:
    """
    GET /admin/tenants/{slug} returns the tenant record.

    :return: None
    """
    tenant = _make_tenant(slug="found-shop")
    db = _make_db(query_result=tenant)
    app.dependency_overrides[get_admin_db] = lambda: db

    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        response = await client.get(
            "/admin/tenants/found-shop", headers=_HEADERS
        )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 200
    assert response.json()["slug"] == "found-shop"


@pytest.mark.asyncio
async def test_update_tenant_not_found() -> None:
    """
    PATCH /admin/tenants/{slug} returns 404 for unknown slug.

    :return: None
    """
    db = _make_db(query_result=None)
    app.dependency_overrides[get_admin_db] = lambda: db

    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        response = await client.patch(
            "/admin/tenants/ghost",
            json={"is_active": False},
            headers=_HEADERS,
        )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_update_tenant_suspend() -> None:
    """
    PATCH /admin/tenants/{slug} can suspend a tenant.

    :return: None
    """
    tenant = _make_tenant(is_active=True)
    db = _make_db(query_result=tenant)
    app.dependency_overrides[get_admin_db] = lambda: db

    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        response = await client.patch(
            "/admin/tenants/test-shop",
            json={"is_active": False},
            headers=_HEADERS,
        )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_migrate_tenant_not_found() -> None:
    """
    POST /admin/tenants/{slug}/migrate returns 404 for unknown slug.

    :return: None
    """
    db = _make_db(query_result=None)
    app.dependency_overrides[get_admin_db] = lambda: db

    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        response = await client.post(
            "/admin/tenants/ghost/migrate",
            headers=_HEADERS,
        )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_provision_duplicate_slug_returns_409() -> None:
    """
    POST /admin/tenants returns 409 when slug is already taken.

    :return: None
    """
    tenant = _make_tenant(slug="dup-shop")
    db = _make_db(query_result=tenant)
    app.dependency_overrides[get_admin_db] = lambda: db

    with patch(
        "app.routers.admin.TenantProvisioner"
    ) as MockProvisioner:
        instance = MockProvisioner.return_value
        instance.provision.side_effect = RuntimeError(
            "already exists"
        )

        transport = ASGITransport(app=app)
        async with AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            response = await client.post(
                "/admin/tenants",
                json={
                    "name": "Dup",
                    "slug": "dup-shop",
                    "admin_email": "a@b.com",
                    "admin_password": "password123",
                },
                headers=_HEADERS,
            )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 409


@pytest.mark.asyncio
async def test_provision_tenant_success() -> None:
    """
    POST /admin/tenants returns 201 with tenant data on success.

    :return: None
    """
    tenant = _make_tenant(slug="new-shop")
    db = _make_db(query_result=tenant)
    app.dependency_overrides[get_admin_db] = lambda: db

    with patch(
        "app.routers.admin.TenantProvisioner"
    ) as MockProvisioner:
        instance = MockProvisioner.return_value
        instance.provision.return_value = tenant.id

        transport = ASGITransport(app=app)
        async with AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            response = await client.post(
                "/admin/tenants",
                json={
                    "name": "New Shop",
                    "slug": "new-shop",
                    "admin_email": "admin@new.com",
                    "admin_password": "password123",
                },
                headers=_HEADERS,
            )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 201
    assert response.json()["slug"] == "new-shop"


@pytest.mark.asyncio
async def test_list_tenants_returns_paginated_response() -> None:
    """
    GET /admin/tenants returns items, total, page, page_size.

    :return: None
    """
    tenants = [_make_tenant(slug=f"shop-{i}") for i in range(3)]
    db = MagicMock()
    db.query.return_value.scalar.return_value = 3
    db.query.return_value.order_by.return_value\
        .offset.return_value.limit.return_value.all.return_value = tenants
    app.dependency_overrides[get_admin_db] = lambda: db

    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        response = await client.get(
            "/admin/tenants", headers=_HEADERS
        )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 3
    assert body["page"] == 1
    assert "items" in body


@pytest.mark.asyncio
async def test_migrate_tenant_success() -> None:
    """
    POST /admin/tenants/{slug}/migrate returns 200 on success.

    :return: None
    """
    tenant = _make_tenant()
    db = _make_db(query_result=tenant)
    app.dependency_overrides[get_admin_db] = lambda: db

    with patch(
        "app.routers.admin.TenantProvisioner"
    ) as MockProvisioner:
        instance = MockProvisioner.return_value

        transport = ASGITransport(app=app)
        async with AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            response = await client.post(
                "/admin/tenants/test-shop/migrate",
                headers=_HEADERS,
            )

        instance._run_migrations.assert_called_once_with(
            tenant.slug
        )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 200
