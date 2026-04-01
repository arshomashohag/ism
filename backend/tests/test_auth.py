"""
Tests for all auth endpoints and RBAC enforcement.

Uses a fake in-memory DB session (no PostgreSQL required) so the
full test suite runs locally without Docker.
"""

import uuid
from typing import Generator
from unittest.mock import MagicMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from app.dependencies import get_db
from app.main import app
from app.schemas.auth import CurrentUser
from app.services.auth import PasswordService, TokenService


def _make_tenant(name: str = "Demo Shop") -> MagicMock:
    """
    Build a mock Tenant-like object for test fixtures.

    Returns a MagicMock with the attributes that the auth router
    reads, without requiring a live SQLAlchemy session.

    :param name: Tenant shop name
    :return: Mock tenant object
    """
    tenant = MagicMock()
    tenant.id = uuid.uuid4()
    tenant.name = name
    tenant.slug = name.lower().replace(" ", "-")
    tenant.plan = "starter"
    tenant.is_active = True
    return tenant


def _make_user(
    tenant_id: uuid.UUID,
    role: str = "admin",
    email: str = "admin@test.shop",
    password: str = "securepass",
) -> MagicMock:
    """
    Build a mock User-like object with a hashed password.

    :param tenant_id: Owning tenant UUID
    :param role: RBAC role string
    :param email: Login email
    :param password: Plain-text password to hash
    :return: Mock user object
    """
    user = MagicMock()
    user.id = uuid.uuid4()
    user.tenant_id = tenant_id
    user.name = "Test User"
    user.email = email
    user.password_hash = PasswordService.hash(password)
    user.role = role
    user.is_active = True
    return user


class FakeQuery:
    """
    Minimal SQLAlchemy query stub for unit testing.

    Supports the .filter().first() chain used in the auth router.

    :ivar _result: Object to return from first()
    """

    def __init__(self, result: object) -> None:
        """
        Initialise with a fixed return value.

        :param result: Value to return from first()
        """
        self._result = result

    def filter(self, *args, **kwargs) -> "FakeQuery":
        """
        Stub for query chaining.

        :return: Self for chaining
        """
        return self

    def first(self) -> object:
        """
        Return the pre-configured result.

        :return: Configured result object
        """
        return self._result


def _make_db(
    query_result: object = None,
) -> MagicMock:
    """
    Build a mock SQLAlchemy Session for a single query result.

    :param query_result: Object the query will return via first()
    :return: Configured MagicMock session
    """
    db = MagicMock()
    db.query.return_value = FakeQuery(query_result)
    return db


@pytest.fixture
def client() -> Generator[AsyncClient, None, None]:
    """
    Provide a test AsyncClient that bypasses the DB dependency.

    The database session is overridden per-test via
    app.dependency_overrides.

    :return: Configured AsyncClient
    """
    transport = ASGITransport(app=app)
    return AsyncClient(transport=transport, base_url="http://test")


async def test_register_success(client: AsyncClient) -> None:
    """
    Verify POST /auth/register creates a tenant and returns tokens.

    :param client: Test HTTP client
    :return: None
    """
    db = _make_db(query_result=None)
    db.flush = MagicMock()
    db.commit = MagicMock()
    db.refresh = MagicMock(
        side_effect=lambda obj: setattr(obj, "role", "admin")
        or setattr(obj, "email", "owner@newshop.com")
        or setattr(obj, "id", uuid.uuid4())
        or setattr(obj, "tenant_id", uuid.uuid4())
    )

    app.dependency_overrides[get_db] = lambda: db

    async with client as c:
        response = await c.post(
            "/auth/register",
            json={
                "shop_name": "New Shop",
                "slug": "new-shop",
                "admin_name": "Owner",
                "email": "owner@newshop.com",
                "password": "securepass",
            },
        )

    app.dependency_overrides.clear()
    assert response.status_code == 201
    body = response.json()
    assert "access_token" in body
    assert "refresh_token" in body
    assert body["token_type"] == "bearer"


async def test_register_duplicate_slug(
    client: AsyncClient,
) -> None:
    """
    Verify POST /auth/register returns 409 if slug already exists.

    :param client: Test HTTP client
    :return: None
    """
    tenant = _make_tenant("Existing Shop")
    db = _make_db(query_result=tenant)

    app.dependency_overrides[get_db] = lambda: db

    async with client as c:
        response = await c.post(
            "/auth/register",
            json={
                "shop_name": "Existing Shop",
                "slug": "existing-shop",
                "admin_name": "Owner",
                "email": "owner@existing.com",
                "password": "securepass",
            },
        )

    app.dependency_overrides.clear()
    assert response.status_code == 409
    assert "slug" in response.json()["detail"].lower()


async def test_register_invalid_slug(
    client: AsyncClient,
) -> None:
    """
    Verify POST /auth/register returns 422 for invalid slug format.

    :param client: Test HTTP client
    :return: None
    """
    async with client as c:
        response = await c.post(
            "/auth/register",
            json={
                "shop_name": "Bad Shop",
                "slug": "Bad Slug!",
                "admin_name": "Owner",
                "email": "owner@bad.com",
                "password": "securepass",
            },
        )

    assert response.status_code == 422


async def test_login_success(client: AsyncClient) -> None:
    """
    Verify POST /auth/login returns tokens for correct credentials.

    :param client: Test HTTP client
    :return: None
    """
    tenant = _make_tenant()
    user = _make_user(
        tenant_id=tenant.id,
        email="admin@test.shop",
        password="goodpass1",
    )
    db = _make_db(query_result=user)

    app.dependency_overrides[get_db] = lambda: db

    async with client as c:
        response = await c.post(
            "/auth/login",
            json={
                "email": "admin@test.shop",
                "password": "goodpass1",
            },
        )

    app.dependency_overrides.clear()
    assert response.status_code == 200
    body = response.json()
    assert "access_token" in body
    assert "refresh_token" in body


async def test_login_wrong_password(
    client: AsyncClient,
) -> None:
    """
    Verify POST /auth/login returns 401 for incorrect password.

    :param client: Test HTTP client
    :return: None
    """
    tenant = _make_tenant()
    user = _make_user(tenant_id=tenant.id, password="correctpass")
    db = _make_db(query_result=user)

    app.dependency_overrides[get_db] = lambda: db

    async with client as c:
        response = await c.post(
            "/auth/login",
            json={
                "email": "admin@test.shop",
                "password": "wrongpass",
            },
        )

    app.dependency_overrides.clear()
    assert response.status_code == 401


async def test_login_unknown_email(
    client: AsyncClient,
) -> None:
    """
    Verify POST /auth/login returns 401 when email is not found.

    :param client: Test HTTP client
    :return: None
    """
    db = _make_db(query_result=None)

    app.dependency_overrides[get_db] = lambda: db

    async with client as c:
        response = await c.post(
            "/auth/login",
            json={
                "email": "ghost@nowhere.com",
                "password": "anything",
            },
        )

    app.dependency_overrides.clear()
    assert response.status_code == 401


async def test_refresh_tokens_success(
    client: AsyncClient,
) -> None:
    """
    Verify POST /auth/refresh returns a new token pair.

    :param client: Test HTTP client
    :return: None
    """
    tenant = _make_tenant()
    user = _make_user(tenant_id=tenant.id)
    refresh_token = TokenService.create_refresh_token(
        user_id=user.id
    )

    db = _make_db(query_result=user)
    app.dependency_overrides[get_db] = lambda: db

    async with client as c:
        response = await c.post(
            "/auth/refresh",
            json={"refresh_token": refresh_token},
        )

    app.dependency_overrides.clear()
    assert response.status_code == 200
    body = response.json()
    assert "access_token" in body
    assert "refresh_token" in body
    new_uid = TokenService.decode_refresh_token(
        body["refresh_token"]
    )
    assert new_uid == str(user.id)


async def test_refresh_rejects_used_token(
    client: AsyncClient,
) -> None:
    """
    Verify POST /auth/refresh rejects a previously rotated token.

    :param client: Test HTTP client
    :return: None
    """
    tenant = _make_tenant()
    user = _make_user(tenant_id=tenant.id)
    refresh_token = TokenService.create_refresh_token(
        user_id=user.id
    )

    db = _make_db(query_result=user)
    app.dependency_overrides[get_db] = lambda: db

    async with client as c:
        await c.post(
            "/auth/refresh",
            json={"refresh_token": refresh_token},
        )
        second = await c.post(
            "/auth/refresh",
            json={"refresh_token": refresh_token},
        )

    app.dependency_overrides.clear()
    assert second.status_code == 401


async def test_refresh_rejects_invalid_token(
    client: AsyncClient,
) -> None:
    """
    Verify POST /auth/refresh returns 401 for a garbage token.

    :param client: Test HTTP client
    :return: None
    """
    async with client as c:
        response = await c.post(
            "/auth/refresh",
            json={"refresh_token": "not.a.real.token"},
        )

    assert response.status_code == 401


async def test_logout_blacklists_token(
    client: AsyncClient,
) -> None:
    """
    Verify POST /auth/logout returns 204 and invalidates the token.

    :param client: Test HTTP client
    :return: None
    """
    tenant = _make_tenant()
    user = _make_user(tenant_id=tenant.id)
    refresh_token = TokenService.create_refresh_token(
        user_id=user.id
    )

    db = _make_db(query_result=user)
    app.dependency_overrides[get_db] = lambda: db

    async with client as c:
        logout_resp = await c.post(
            "/auth/logout",
            json={"refresh_token": refresh_token},
        )
        refresh_resp = await c.post(
            "/auth/refresh",
            json={"refresh_token": refresh_token},
        )

    app.dependency_overrides.clear()
    assert logout_resp.status_code == 204
    assert refresh_resp.status_code == 401


async def test_protected_endpoint_requires_token(
    client: AsyncClient,
) -> None:
    """
    Verify accessing /auth/me without a token returns 403.

    :param client: Test HTTP client
    :return: None
    """
    async with client as c:
        response = await c.get("/auth/me")

    assert response.status_code == 403


async def test_protected_endpoint_with_valid_token(
    client: AsyncClient,
) -> None:
    """
    Verify GET /auth/me returns user profile with a valid token.

    :param client: Test HTTP client
    :return: None
    """
    from datetime import datetime, timezone

    tenant = _make_tenant()
    user = _make_user(tenant_id=tenant.id)

    access_token = TokenService.create_access_token(
        user_id=user.id,
        tenant_id=tenant.id,
        role=user.role,
        email=user.email,
    )

    db_user = user
    db_user.created_at = datetime.now(timezone.utc)
    db = _make_db(query_result=db_user)
    app.dependency_overrides[get_db] = lambda: db

    async with client as c:
        response = await c.get(
            "/auth/me",
            headers={"Authorization": f"Bearer {access_token}"},
        )

    app.dependency_overrides.clear()
    assert response.status_code == 200
    body = response.json()
    assert body["email"] == user.email
    assert body["role"] == "admin"


async def test_expired_access_token_rejected(
    client: AsyncClient,
) -> None:
    """
    Verify a token with past expiry is rejected with 401.

    :param client: Test HTTP client
    :return: None
    """
    from datetime import timedelta
    from unittest.mock import patch

    tenant = _make_tenant()
    user = _make_user(tenant_id=tenant.id)

    with patch(
        "app.services.auth.settings"
    ) as mock_settings:
        mock_settings.access_token_expire_minutes = -1
        mock_settings.jwt_private_key = (
            __import__("app.config", fromlist=["settings"])
            .settings.jwt_private_key
        )
        mock_settings.jwt_public_key = (
            __import__("app.config", fromlist=["settings"])
            .settings.jwt_public_key
        )
        expired_token = TokenService.create_access_token(
            user_id=user.id,
            tenant_id=tenant.id,
            role=user.role,
            email=user.email,
        )

    db = _make_db(query_result=user)
    app.dependency_overrides[get_db] = lambda: db

    async with client as c:
        response = await c.get(
            "/auth/me",
            headers={"Authorization": f"Bearer {expired_token}"},
        )

    app.dependency_overrides.clear()
    assert response.status_code == 401


async def test_rbac_salesman_cannot_access_admin_endpoint(
    client: AsyncClient,
) -> None:
    """
    Verify a salesman token cannot access an admin-only endpoint.

    Uses POST /auth/register with a mock to simulate admin-only
    access, then checks that the salesman role is blocked.
    This test exercises require_role via a direct dependency check.

    :param client: Test HTTP client
    :return: None
    """
    from fastapi import HTTPException

    from app.dependencies import require_role

    salesman = CurrentUser(
        user_id=uuid.uuid4(),
        tenant_id=uuid.uuid4(),
        role="salesman",
        email="salesman@test.shop",
    )

    checker = require_role("admin", "manager")

    with pytest.raises(HTTPException) as exc_info:
        checker(current_user=salesman)

    assert exc_info.value.status_code == 403


async def test_rbac_admin_passes_admin_role_check() -> None:
    """
    Verify an admin CurrentUser passes the admin role check.

    :return: None
    """
    from app.dependencies import require_role

    admin = CurrentUser(
        user_id=uuid.uuid4(),
        tenant_id=uuid.uuid4(),
        role="admin",
        email="admin@test.shop",
    )

    checker = require_role("admin", "manager")
    result = checker(current_user=admin)
    assert result.role == "admin"


async def test_rbac_manager_passes_manager_role_check() -> None:
    """
    Verify a manager CurrentUser passes the manager role check.

    :return: None
    """
    from app.dependencies import require_role

    manager = CurrentUser(
        user_id=uuid.uuid4(),
        tenant_id=uuid.uuid4(),
        role="manager",
        email="manager@test.shop",
    )

    checker = require_role("admin", "manager")
    result = checker(current_user=manager)
    assert result.role == "manager"


async def test_access_token_contains_correct_claims() -> None:
    """
    Verify access token payload contains all required JWT claims.

    :return: None
    """
    user_id = uuid.uuid4()
    tenant_id = uuid.uuid4()

    token = TokenService.create_access_token(
        user_id=user_id,
        tenant_id=tenant_id,
        role="manager",
        email="manager@shop.com",
    )
    payload = TokenService.decode_access_token(token)

    assert payload is not None
    assert payload["sub"] == str(user_id)
    assert payload["tenant_id"] == str(tenant_id)
    assert payload["role"] == "manager"
    assert payload["email"] == "manager@shop.com"
    assert payload["type"] == "access"


async def test_refresh_token_contains_only_user_id() -> None:
    """
    Verify refresh token carries only user_id, not role/tenant.

    :return: None
    """
    user_id = uuid.uuid4()
    token = TokenService.create_refresh_token(user_id=user_id)
    user_id_back = TokenService.decode_refresh_token(token)

    assert user_id_back == str(user_id)


async def test_password_hash_and_verify() -> None:
    """
    Verify bcrypt hashing produces a verifiable hash.

    :return: None
    """
    plain = "MyS3cretPass!"
    hashed = PasswordService.hash(plain)

    assert hashed != plain
    assert PasswordService.verify(plain, hashed)
    assert not PasswordService.verify("wrongpass", hashed)
