"""Tests for the /sadmin/* super admin endpoints."""

import uuid
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from app.dependencies import get_admin_db
from app.main import app
from app.models.super_admin import SuperAdmin
from app.models.tenant import Tenant
from app.routers.super_admin import _issue_super_admin_token


def _make_super_admin(
    email: str = "superadmin@ims.dev",
    has_credential: bool = True,
) -> MagicMock:
    """
    Build a mock SuperAdmin ORM object.

    :param email: Super admin email
    :param has_credential: Whether the mock has a stored credential
    :return: MagicMock shaped like a SuperAdmin
    """
    admin = MagicMock(spec=SuperAdmin)
    admin.id = uuid.uuid4()
    admin.email = email
    admin.is_active = True
    admin.last_login = None
    admin.webauthn_credential = (
        {
            "credential_id": "dGVzdC1jcmVk",
            "public_key": "dGVzdC1rZXk=",
            "sign_count": 0,
        }
        if has_credential
        else None
    )
    return admin


def _make_tenant(
    slug: str = "test-shop",
    plan: str = "starter",
    is_active: bool = True,
) -> MagicMock:
    """
    Build a mock Tenant ORM object.

    :param slug: Tenant slug
    :param plan: Subscription plan
    :param is_active: Active status flag
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


def _make_db(
    admin_result=None,
    tenant_result=None,
    count_result: int = 0,
) -> MagicMock:
    """
    Build a mock SQLAlchemy session for super admin tests.

    :param admin_result: Value returned by .first() for SuperAdmin
    :param tenant_result: Value returned by .first() for Tenant
    :param count_result: Value returned by .scalar()
    :return: Configured MagicMock session
    """
    db = MagicMock()

    call_count = {"n": 0}

    def query_side_effect(model):
        q = MagicMock()
        q.filter.return_value = q
        q.with_entities.return_value = q
        q.order_by.return_value = q
        q.offset.return_value = q
        q.limit.return_value = q
        q.scalar.return_value = count_result

        if model is SuperAdmin:
            q.first.return_value = admin_result
            q.all.return_value = (
                [admin_result] if admin_result else []
            )
        elif model is Tenant:
            q.first.return_value = tenant_result
            q.all.return_value = (
                [tenant_result] if tenant_result else []
            )
        else:
            q.first.return_value = None
            q.all.return_value = []

        return q

    db.query.side_effect = query_side_effect
    return db


def _valid_token() -> str:
    """
    Return a valid super admin JWT for use in test request headers.

    :return: Signed JWT string with role=super_admin
    """
    return _issue_super_admin_token("superadmin@ims.dev")


_AUTH_HEADERS = property(lambda _: {
    "Authorization": f"Bearer {_valid_token()}"
})


@pytest.mark.asyncio
async def test_register_key_creates_admin_when_not_exists() -> None:
    """
    POST /sadmin/auth/register-key creates a SuperAdmin record
    if one does not exist and returns registration options.

    :return: None
    """
    db = _make_db(admin_result=None)
    app.dependency_overrides[get_admin_db] = lambda: db

    with patch(
        "app.routers.super_admin._webauthn"
    ) as mock_webauthn:
        mock_webauthn.generate_registration_options.return_value = (
            {"type": "webauthn.create"},
            "dGVzdC1jaGFsbGVuZ2U=",
        )

        transport = ASGITransport(app=app)
        async with AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            response = await client.post(
                "/sadmin/auth/register-key",
                json={"email": "newadmin@ims.dev"},
            )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 200
    body = response.json()
    assert "options" in body
    assert "challenge" in body


@pytest.mark.asyncio
async def test_register_key_skips_creation_if_exists() -> None:
    """
    POST /sadmin/auth/register-key skips record creation when the
    super admin already exists.

    :return: None
    """
    admin = _make_super_admin()
    db = _make_db(admin_result=admin)
    app.dependency_overrides[get_admin_db] = lambda: db

    with patch(
        "app.routers.super_admin._webauthn"
    ) as mock_webauthn:
        mock_webauthn.generate_registration_options.return_value = (
            {"type": "webauthn.create"},
            "dGVzdC1jaGFsbGVuZ2U=",
        )
        transport = ASGITransport(app=app)
        async with AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            response = await client.post(
                "/sadmin/auth/register-key",
                json={"email": admin.email},
            )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 200
    db.add.assert_not_called()


@pytest.mark.asyncio
async def test_verify_registration_returns_token_on_success() -> None:
    """
    POST /sadmin/auth/verify-registration returns a JWT when
    WebAuthn verification succeeds.

    :return: None
    """
    admin = _make_super_admin(has_credential=False)
    db = _make_db(admin_result=admin)
    app.dependency_overrides[get_admin_db] = lambda: db

    with patch(
        "app.routers.super_admin._webauthn"
    ) as mock_webauthn:
        mock_webauthn.verify_registration.return_value = {
            "credential_id": "dGVzdA==",
            "public_key": "a2V5",
            "sign_count": 0,
        }
        transport = ASGITransport(app=app)
        async with AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            response = await client.post(
                "/sadmin/auth/verify-registration",
                json={
                    "email": admin.email,
                    "credential": {"id": "test"},
                    "challenge": "dGVzdA==",
                    "origin": "https://localhost",
                },
            )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 200
    assert "access_token" in response.json()


@pytest.mark.asyncio
async def test_verify_registration_returns_400_on_failure() -> None:
    """
    POST /sadmin/auth/verify-registration returns 400 when
    WebAuthn verification raises ValueError.

    :return: None
    """
    admin = _make_super_admin(has_credential=False)
    db = _make_db(admin_result=admin)
    app.dependency_overrides[get_admin_db] = lambda: db

    with patch(
        "app.routers.super_admin._webauthn"
    ) as mock_webauthn:
        mock_webauthn.verify_registration.side_effect = ValueError(
            "bad signature"
        )
        transport = ASGITransport(app=app)
        async with AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            response = await client.post(
                "/sadmin/auth/verify-registration",
                json={
                    "email": admin.email,
                    "credential": {"id": "bad"},
                    "challenge": "dGVzdA==",
                    "origin": "https://localhost",
                },
            )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_auth_initiate_returns_challenge() -> None:
    """
    POST /sadmin/auth/authenticate returns WebAuthn options when
    the admin has a registered credential.

    :return: None
    """
    admin = _make_super_admin()
    db = _make_db(admin_result=admin)
    app.dependency_overrides[get_admin_db] = lambda: db

    with patch(
        "app.routers.super_admin._webauthn"
    ) as mock_webauthn:
        mock_webauthn.generate_authentication_options.return_value = (
            {"type": "webauthn.get"},
            "dGVzdC1jaGFsbGVuZ2U=",
        )
        transport = ASGITransport(app=app)
        async with AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            response = await client.post(
                "/sadmin/auth/authenticate",
                json={"email": admin.email},
            )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 200
    body = response.json()
    assert "options" in body
    assert "challenge" in body


@pytest.mark.asyncio
async def test_auth_initiate_returns_400_if_no_credential() -> None:
    """
    POST /sadmin/auth/authenticate returns 400 when the admin has no
    registered hardware key.

    :return: None
    """
    admin = _make_super_admin(has_credential=False)
    db = _make_db(admin_result=admin)
    app.dependency_overrides[get_admin_db] = lambda: db

    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        response = await client.post(
            "/sadmin/auth/authenticate",
            json={"email": admin.email},
        )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_verify_auth_returns_token_on_success() -> None:
    """
    POST /sadmin/auth/verify-authentication returns a JWT on success.

    :return: None
    """
    admin = _make_super_admin()
    db = _make_db(admin_result=admin)
    app.dependency_overrides[get_admin_db] = lambda: db

    with patch(
        "app.routers.super_admin._webauthn"
    ) as mock_webauthn:
        mock_webauthn.verify_authentication.return_value = 1
        transport = ASGITransport(app=app)
        async with AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            response = await client.post(
                "/sadmin/auth/verify-authentication",
                json={
                    "email": admin.email,
                    "credential": {"id": "test"},
                    "challenge": "dGVzdA==",
                    "origin": "https://localhost",
                },
            )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 200
    assert "access_token" in response.json()


@pytest.mark.asyncio
async def test_health_requires_auth() -> None:
    """
    GET /sadmin/health returns 403 without a valid super admin JWT.

    :return: None
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        response = await client.get("/sadmin/health")

    assert response.status_code == 403


@pytest.mark.asyncio
async def test_health_returns_metrics_with_valid_token() -> None:
    """
    GET /sadmin/health returns ECS and RDS metrics with a valid token.

    :return: None
    """
    token = _valid_token()
    headers = {"Authorization": f"Bearer {token}"}

    with patch("app.routers.super_admin.boto3") as mock_boto3:
        mock_ecs = MagicMock()
        mock_ecs.list_tasks.return_value = {"taskArns": []}
        mock_cw = MagicMock()
        mock_cw.get_metric_statistics.return_value = {
            "Datapoints": []
        }
        mock_boto3.client.side_effect = (
            lambda service, **_: mock_ecs
            if service == "ecs"
            else mock_cw
        )

        transport = ASGITransport(app=app)
        async with AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            response = await client.get(
                "/sadmin/health", headers=headers
            )

    assert response.status_code == 200
    body = response.json()
    assert "ecs_running_tasks" in body
    assert "rds_connections" in body


@pytest.mark.asyncio
async def test_list_tenants_requires_auth() -> None:
    """
    GET /sadmin/tenants returns 403 without a super admin token.

    :return: None
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        response = await client.get("/sadmin/tenants")

    assert response.status_code == 403


@pytest.mark.asyncio
async def test_list_tenants_returns_paginated_list() -> None:
    """
    GET /sadmin/tenants returns paginated tenant data with a valid token.

    :return: None
    """
    tenants = [_make_tenant(slug=f"shop-{i}") for i in range(2)]
    db = MagicMock()
    count_q = MagicMock()
    count_q.scalar.return_value = 2
    list_q = MagicMock()
    list_q.order_by.return_value.offset.return_value\
        .limit.return_value.all.return_value = tenants

    call_n = {"n": 0}

    def _query(model):
        call_n["n"] += 1
        if call_n["n"] == 1:
            return count_q
        return list_q

    db.query.side_effect = _query
    app.dependency_overrides[get_admin_db] = lambda: db
    token = _valid_token()
    headers = {"Authorization": f"Bearer {token}"}

    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        response = await client.get(
            "/sadmin/tenants", headers=headers
        )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 2
    assert len(body["items"]) == 2


@pytest.mark.asyncio
async def test_update_tenant_not_found() -> None:
    """
    PATCH /sadmin/tenants/{slug} returns 404 for an unknown slug.

    :return: None
    """
    db = _make_db(tenant_result=None)
    app.dependency_overrides[get_admin_db] = lambda: db
    token = _valid_token()
    headers = {"Authorization": f"Bearer {token}"}

    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        response = await client.patch(
            "/sadmin/tenants/ghost",
            json={"is_active": False},
            headers=headers,
        )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_update_tenant_suspends_shop() -> None:
    """
    PATCH /sadmin/tenants/{slug} can suspend a tenant.

    :return: None
    """
    tenant = _make_tenant(is_active=True)
    db = _make_db(tenant_result=tenant)
    app.dependency_overrides[get_admin_db] = lambda: db
    token = _valid_token()
    headers = {"Authorization": f"Bearer {token}"}

    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        response = await client.patch(
            "/sadmin/tenants/test-shop",
            json={"is_active": False},
            headers=headers,
        )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_provision_tenant_success() -> None:
    """
    POST /sadmin/tenants returns 201 with tenant data on success.

    :return: None
    """
    tenant = _make_tenant(slug="new-shop")
    db = _make_db(tenant_result=tenant)
    app.dependency_overrides[get_admin_db] = lambda: db
    token = _valid_token()
    headers = {"Authorization": f"Bearer {token}"}

    with patch(
        "app.routers.super_admin.TenantProvisioner"
    ) as MockProvisioner:
        instance = MockProvisioner.return_value
        instance.provision.return_value = tenant.id

        transport = ASGITransport(app=app)
        async with AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            response = await client.post(
                "/sadmin/tenants",
                json={
                    "name": "New Shop",
                    "slug": "new-shop",
                    "plan": "starter",
                    "admin_email": "admin@new.com",
                    "admin_password": "password123",
                },
                headers=headers,
            )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 201
    assert response.json()["slug"] == "new-shop"


@pytest.mark.asyncio
async def test_migrate_tenant_not_found() -> None:
    """
    POST /sadmin/tenants/{slug}/migrate returns 404 for unknown slug.

    :return: None
    """
    db = _make_db(tenant_result=None)
    app.dependency_overrides[get_admin_db] = lambda: db
    token = _valid_token()
    headers = {"Authorization": f"Bearer {token}"}

    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        response = await client.post(
            "/sadmin/tenants/ghost/migrate",
            headers=headers,
        )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_audit_log_requires_auth() -> None:
    """
    GET /sadmin/audit-log returns 403 without a super admin token.

    :return: None
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        response = await client.get("/sadmin/audit-log")

    assert response.status_code == 403


@pytest.mark.asyncio
async def test_audit_log_returns_paginated_entries() -> None:
    """
    GET /sadmin/audit-log returns paginated audit entries.

    :return: None
    """
    db = MagicMock()
    q = MagicMock()
    q.filter.return_value = q
    q.with_entities.return_value = q
    q.scalar.return_value = 0
    q.order_by.return_value.offset.return_value\
        .limit.return_value.all.return_value = []
    db.query.return_value = q
    app.dependency_overrides[get_admin_db] = lambda: db
    token = _valid_token()
    headers = {"Authorization": f"Bearer {token}"}

    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        response = await client.get(
            "/sadmin/audit-log", headers=headers
        )

    app.dependency_overrides.pop(get_admin_db, None)
    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 0
    assert body["items"] == []
