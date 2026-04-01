"""
Tests for user management endpoints — permission matrix.

Uses a fake in-memory DB session (no PostgreSQL required) so the
full test suite runs locally without Docker.
"""

import uuid
from datetime import datetime, timezone
from typing import Any
from unittest.mock import MagicMock

import pytest
from httpx import ASGITransport, AsyncClient

from app.dependencies import get_current_user, get_db
from app.main import app
from app.schemas.auth import CurrentUser

TENANT_ID = uuid.uuid4()
USER_ID = uuid.uuid4()
OTHER_USER_ID = uuid.uuid4()


def _admin_context() -> CurrentUser:
    """
    Return an admin CurrentUser fixture for dependency override.

    :return: CurrentUser with admin role
    """
    return CurrentUser(
        user_id=USER_ID,
        tenant_id=TENANT_ID,
        role="admin",
        email="admin@test.shop",
    )


def _manager_context() -> CurrentUser:
    """
    Return a manager CurrentUser fixture for dependency override.

    :return: CurrentUser with manager role
    """
    return CurrentUser(
        user_id=uuid.uuid4(),
        tenant_id=TENANT_ID,
        role="manager",
        email="manager@test.shop",
    )


def _salesman_context() -> CurrentUser:
    """
    Return a salesman CurrentUser fixture for dependency override.

    :return: CurrentUser with salesman role
    """
    return CurrentUser(
        user_id=uuid.uuid4(),
        tenant_id=TENANT_ID,
        role="salesman",
        email="salesman@test.shop",
    )


def _make_user(
    user_id: uuid.UUID | None = None,
    tenant_id: uuid.UUID | None = None,
) -> MagicMock:
    """
    Build a mock User-like object.

    :param user_id: User UUID (defaults to OTHER_USER_ID)
    :param tenant_id: Tenant UUID (defaults to module-level)
    :return: Mock user object
    """
    u = MagicMock()
    u.id = user_id or OTHER_USER_ID
    u.tenant_id = tenant_id or TENANT_ID
    u.name = "Test User"
    u.email = "test@test.shop"
    u.role = "salesman"
    u.is_active = True
    _ts = datetime(2026, 1, 1, tzinfo=timezone.utc)
    u.created_at = _ts
    u.updated_at = _ts
    return u


class FakeQuery:
    """
    Minimal SQLAlchemy query stub for unit testing.

    :ivar _result: Value to return from first()
    :ivar _all: Value to return from all()
    :ivar _count: Value to return from count()
    """

    def __init__(
        self,
        result: Any = None,
        all_results: list | None = None,
        count: int = 0,
    ) -> None:
        """
        Initialise with fixed return values.

        :param result: Value to return from first()
        :param all_results: Values to return from all()
        :param count: Value to return from count()
        """
        self._result = result
        self._all = all_results or []
        self._count = count

    def filter(self, *_: Any) -> "FakeQuery":
        """
        Return self to support chained filter calls.

        :return: self
        """
        return self

    def order_by(self, *_: Any) -> "FakeQuery":
        """
        Return self to support chained order_by calls.

        :return: self
        """
        return self

    def offset(self, *_: Any) -> "FakeQuery":
        """
        Return self to support chained offset calls.

        :return: self
        """
        return self

    def limit(self, *_: Any) -> "FakeQuery":
        """
        Return self to support chained limit calls.

        :return: self
        """
        return self

    def first(self) -> Any:
        """
        Return the mocked first result.

        :return: Mock result
        """
        return self._result

    def all(self) -> list:
        """
        Return the mocked list of results.

        :return: List of mock results
        """
        return self._all

    def count(self) -> int:
        """
        Return the mocked count.

        :return: Mocked row count
        """
        return self._count


def _build_db(
    query_result: Any = None,
    all_results: list | None = None,
    count: int = 0,
) -> MagicMock:
    """
    Build a mock DB session with query stubs.

    :param query_result: Value for first()
    :param all_results: Values for all()
    :param count: Value for count()
    :return: Mock Session
    """
    db = MagicMock()
    fq = FakeQuery(query_result, all_results, count)
    db.query.return_value = fq
    db.add = MagicMock()
    db.flush = MagicMock()
    db.commit = MagicMock()
    db.refresh = MagicMock()
    return db


def _make_client(
    db: MagicMock,
    context_fn: Any,
) -> AsyncClient:
    """
    Build an async test client with DB and auth overrides.

    :param db: Mock database session
    :param context_fn: Callable returning CurrentUser
    :return: AsyncClient wired to the FastAPI app
    """
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = context_fn
    transport = ASGITransport(app=app)
    return AsyncClient(transport=transport, base_url="http://test")


@pytest.mark.anyio
async def test_list_users_admin_200() -> None:
    """
    GET /users returns 200 for admin role.

    :return: None
    """
    db = _build_db(all_results=[], count=0)
    async with _make_client(db, _admin_context) as client:
        response = await client.get("/users/")
    assert response.status_code == 200
    assert response.json()["total"] == 0


@pytest.mark.anyio
async def test_list_users_manager_403() -> None:
    """
    GET /users returns 403 for manager role.

    :return: None
    """
    db = _build_db()
    async with _make_client(db, _manager_context) as client:
        response = await client.get("/users/")
    assert response.status_code == 403


@pytest.mark.anyio
async def test_list_users_salesman_403() -> None:
    """
    GET /users returns 403 for salesman role.

    :return: None
    """
    db = _build_db()
    async with _make_client(db, _salesman_context) as client:
        response = await client.get("/users/")
    assert response.status_code == 403


@pytest.mark.anyio
async def test_create_user_admin_201() -> None:
    """
    POST /users creates a user and returns 201 for admin.

    :return: None
    """
    _ts = datetime(2026, 1, 1, tzinfo=timezone.utc)

    def _fake_refresh(obj: Any) -> None:
        """
        Simulate server-side timestamp population on refresh.

        :param obj: ORM object being refreshed
        :return: None
        """
        if not getattr(obj, "created_at", None):
            obj.created_at = _ts
        if not getattr(obj, "updated_at", None):
            obj.updated_at = _ts

    db = _build_db(query_result=None)
    db.refresh.side_effect = _fake_refresh

    async with _make_client(db, _admin_context) as client:
        response = await client.post(
            "/users/",
            json={
                "name": "New User",
                "email": "new@test.shop",
                "password": "password123",
                "role": "salesman",
            },
        )
    assert response.status_code == 201


@pytest.mark.anyio
async def test_create_user_duplicate_email_409() -> None:
    """
    POST /users returns 409 when email already exists.

    :return: None
    """
    existing = _make_user()
    db = _build_db(query_result=existing)
    async with _make_client(db, _admin_context) as client:
        response = await client.post(
            "/users/",
            json={
                "name": "Dupe",
                "email": "test@test.shop",
                "password": "password123",
                "role": "salesman",
            },
        )
    assert response.status_code == 409


@pytest.mark.anyio
async def test_create_user_manager_403() -> None:
    """
    POST /users returns 403 for manager role.

    :return: None
    """
    db = _build_db()
    async with _make_client(db, _manager_context) as client:
        response = await client.post(
            "/users/",
            json={
                "name": "X",
                "email": "x@test.shop",
                "password": "password123",
            },
        )
    assert response.status_code == 403


@pytest.mark.anyio
async def test_create_user_salesman_403() -> None:
    """
    POST /users returns 403 for salesman role.

    :return: None
    """
    db = _build_db()
    async with _make_client(db, _salesman_context) as client:
        response = await client.post(
            "/users/",
            json={
                "name": "X",
                "email": "x@test.shop",
                "password": "password123",
            },
        )
    assert response.status_code == 403


@pytest.mark.anyio
async def test_patch_user_admin_200() -> None:
    """
    PATCH /users/{id} returns 200 for admin.

    :return: None
    """
    user = _make_user()
    db = _build_db(query_result=user)
    async with _make_client(db, _admin_context) as client:
        response = await client.patch(
            f"/users/{OTHER_USER_ID}",
            json={"name": "Updated Name"},
        )
    assert response.status_code == 200


@pytest.mark.anyio
async def test_patch_user_not_found_404() -> None:
    """
    PATCH /users/{id} returns 404 when user absent.

    :return: None
    """
    db = _build_db(query_result=None)
    async with _make_client(db, _admin_context) as client:
        response = await client.patch(
            f"/users/{uuid.uuid4()}",
            json={"name": "X"},
        )
    assert response.status_code == 404


@pytest.mark.anyio
async def test_patch_user_manager_403() -> None:
    """
    PATCH /users/{id} returns 403 for manager role.

    :return: None
    """
    db = _build_db()
    async with _make_client(db, _manager_context) as client:
        response = await client.patch(
            f"/users/{OTHER_USER_ID}",
            json={"name": "X"},
        )
    assert response.status_code == 403


@pytest.mark.anyio
async def test_patch_user_salesman_403() -> None:
    """
    PATCH /users/{id} returns 403 for salesman role.

    :return: None
    """
    db = _build_db()
    async with _make_client(db, _salesman_context) as client:
        response = await client.patch(
            f"/users/{OTHER_USER_ID}",
            json={"name": "X"},
        )
    assert response.status_code == 403


@pytest.mark.anyio
async def test_delete_user_admin_204() -> None:
    """
    DELETE /users/{id} soft-deletes and returns 204.

    :return: None
    """
    user = _make_user()
    db = _build_db(query_result=user)
    async with _make_client(db, _admin_context) as client:
        response = await client.delete(
            f"/users/{OTHER_USER_ID}"
        )
    assert response.status_code == 204
    assert user.is_active is False


@pytest.mark.anyio
async def test_delete_self_admin_409() -> None:
    """
    DELETE /users/{id} returns 409 when deactivating own account.

    :return: None
    """
    self_user = _make_user(user_id=USER_ID)
    db = _build_db(query_result=self_user)
    async with _make_client(db, _admin_context) as client:
        response = await client.delete(f"/users/{USER_ID}")
    assert response.status_code == 409


@pytest.mark.anyio
async def test_delete_user_not_found_404() -> None:
    """
    DELETE /users/{id} returns 404 when user absent.

    :return: None
    """
    db = _build_db(query_result=None)
    async with _make_client(db, _admin_context) as client:
        response = await client.delete(
            f"/users/{uuid.uuid4()}"
        )
    assert response.status_code == 404


@pytest.mark.anyio
async def test_delete_user_manager_403() -> None:
    """
    DELETE /users/{id} returns 403 for manager role.

    :return: None
    """
    db = _build_db()
    async with _make_client(db, _manager_context) as client:
        response = await client.delete(
            f"/users/{OTHER_USER_ID}"
        )
    assert response.status_code == 403
