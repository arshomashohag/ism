"""
Tests for product and category endpoints.

Uses a fake in-memory DB session (no PostgreSQL required) so the
full test suite runs locally without Docker.
"""

import uuid
from datetime import datetime, timezone
from typing import Any
from unittest.mock import MagicMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from app.dependencies import get_current_user, get_db
from app.main import app
from app.schemas.auth import CurrentUser
from app.services.auth import TokenService

TENANT_ID = uuid.uuid4()
USER_ID = uuid.uuid4()
PRODUCT_ID = uuid.uuid4()
CATEGORY_ID = uuid.uuid4()


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


def _make_product(
    product_id: uuid.UUID | None = None,
    tenant_id: uuid.UUID | None = None,
) -> MagicMock:
    """
    Build a mock Product-like object.

    :param product_id: Product UUID (defaults to module-level)
    :param tenant_id: Tenant UUID (defaults to module-level)
    :return: Mock product object
    """
    p = MagicMock()
    p.id = product_id or PRODUCT_ID
    p.tenant_id = tenant_id or TENANT_ID
    p.sku = "SKU-001"
    p.name = "Test Product"
    p.barcode = None
    p.category_id = None
    p.unit_price = 10.00
    p.cost_price = None
    p.tax_rate = 0.0
    p.metadata_ = {}
    p.is_active = True
    _ts = datetime(2026, 1, 1, tzinfo=timezone.utc)
    p.created_at = _ts
    p.updated_at = _ts
    return p


def _make_category(
    category_id: uuid.UUID | None = None,
    parent_id: uuid.UUID | None = None,
) -> MagicMock:
    """
    Build a mock Category-like object.

    :param category_id: Category UUID (defaults to module-level)
    :param parent_id: Optional parent UUID
    :return: Mock category object
    """
    c = MagicMock()
    c.id = category_id or CATEGORY_ID
    c.tenant_id = TENANT_ID
    c.parent_id = parent_id
    c.name = "Electronics"
    return c


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

    def join(self, *_: Any) -> "FakeQuery":
        """
        Return self to support chained join calls.

        :return: self
        """
        return self

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
    get_result: Any = None,
) -> MagicMock:
    """
    Build a mock DB session with query/get stubs.

    :param query_result: Value for first()
    :param all_results: Values for all()
    :param count: Value for count()
    :param get_result: Value for db.get()
    :return: Mock Session
    """
    db = MagicMock()
    fq = FakeQuery(query_result, all_results, count)
    empty_fq = FakeQuery()

    def _query_side_effect(model: Any, *_: Any) -> FakeQuery:
        from app.models.inventory import Inventory as Inv

        return empty_fq if model is Inv else fq

    db.query.side_effect = _query_side_effect
    db.get.return_value = get_result
    db.add = MagicMock()
    db.flush = MagicMock()
    db.commit = MagicMock()
    db.refresh = MagicMock()
    return db


def _make_client(db: MagicMock) -> AsyncClient:
    """
    Build an async test client with DB and auth overrides.

    :param db: Mock database session
    :return: AsyncClient wired to the FastAPI app
    """
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[get_current_user] = _admin_context
    transport = ASGITransport(app=app)
    return AsyncClient(transport=transport, base_url="http://test")


@pytest.mark.anyio
async def test_list_products_empty() -> None:
    """
    GET /products returns an empty paginated list.

    :return: None
    """
    db = _build_db(all_results=[], count=0)
    async with _make_client(db) as client:
        response = await client.get("/products/")
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 0
    assert data["items"] == []
    assert data["page"] == 1


@pytest.mark.anyio
async def test_list_products_returns_items() -> None:
    """
    GET /products returns products in paginated response.

    :return: None
    """
    product = _make_product()
    db = _build_db(all_results=[product], count=1)
    async with _make_client(db) as client:
        response = await client.get("/products/")
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 1
    assert len(data["items"]) == 1
    assert data["items"][0]["sku"] == "SKU-001"


@pytest.mark.anyio
async def test_create_product_success() -> None:
    """
    POST /products creates a product and returns 201.

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

    async with _make_client(db) as client:
        response = await client.post(
            "/products/",
            json={
                "sku": "NEW-001",
                "name": "New Product",
                "unit_price": 25.0,
            },
        )
    assert response.status_code == 201


@pytest.mark.anyio
async def test_create_product_conflict_sku() -> None:
    """
    POST /products returns 409 when SKU already exists.

    :return: None
    """
    existing = _make_product()
    db = _build_db(query_result=existing)
    async with _make_client(db) as client:
        response = await client.post(
            "/products/",
            json={
                "sku": "SKU-001",
                "name": "Dupe",
                "unit_price": 10.0,
            },
        )
    assert response.status_code == 409


@pytest.mark.anyio
async def test_create_product_invalid_price() -> None:
    """
    POST /products returns 422 when unit_price <= 0.

    :return: None
    """
    db = _build_db()
    async with _make_client(db) as client:
        response = await client.post(
            "/products/",
            json={
                "sku": "BAD-001",
                "name": "Bad",
                "unit_price": -5.0,
            },
        )
    assert response.status_code == 422


@pytest.mark.anyio
async def test_get_product_success() -> None:
    """
    GET /products/{id} returns product data.

    :return: None
    """
    product = _make_product()
    db = _build_db(query_result=product)
    async with _make_client(db) as client:
        response = await client.get(f"/products/{PRODUCT_ID}")
    assert response.status_code == 200
    assert response.json()["sku"] == "SKU-001"


@pytest.mark.anyio
async def test_get_product_not_found() -> None:
    """
    GET /products/{id} returns 404 when product absent.

    :return: None
    """
    db = _build_db(query_result=None)
    async with _make_client(db) as client:
        response = await client.get(f"/products/{uuid.uuid4()}")
    assert response.status_code == 404


@pytest.mark.anyio
async def test_patch_product_success() -> None:
    """
    PATCH /products/{id} updates and returns product.

    :return: None
    """
    product = _make_product()
    db = _build_db(query_result=product)
    async with _make_client(db) as client:
        response = await client.patch(
            f"/products/{PRODUCT_ID}",
            json={"name": "Updated Name"},
        )
    assert response.status_code == 200


@pytest.mark.anyio
async def test_patch_product_not_found() -> None:
    """
    PATCH /products/{id} returns 404 when product absent.

    :return: None
    """
    db = _build_db(query_result=None)
    async with _make_client(db) as client:
        response = await client.patch(
            f"/products/{uuid.uuid4()}",
            json={"name": "X"},
        )
    assert response.status_code == 404


@pytest.mark.anyio
async def test_delete_product_success() -> None:
    """
    DELETE /products/{id} soft-deletes and returns 204.

    :return: None
    """
    product = _make_product()
    db = _build_db(query_result=product)
    async with _make_client(db) as client:
        response = await client.delete(
            f"/products/{PRODUCT_ID}"
        )
    assert response.status_code == 204
    assert product.is_active is False


@pytest.mark.anyio
async def test_delete_product_not_found() -> None:
    """
    DELETE /products/{id} returns 404 when product absent.

    :return: None
    """
    db = _build_db(query_result=None)
    async with _make_client(db) as client:
        response = await client.delete(
            f"/products/{uuid.uuid4()}"
        )
    assert response.status_code == 404


@pytest.mark.anyio
async def test_list_categories_empty() -> None:
    """
    GET /categories returns an empty list.

    :return: None
    """
    db = _build_db(all_results=[])
    async with _make_client(db) as client:
        response = await client.get("/categories/")
    assert response.status_code == 200
    assert response.json() == []


@pytest.mark.anyio
async def test_list_categories_tree() -> None:
    """
    GET /categories returns tree with root and child.

    :return: None
    """
    root = _make_category()
    child = _make_category(
        category_id=uuid.uuid4(), parent_id=root.id
    )
    db = _build_db(all_results=[root, child])
    async with _make_client(db) as client:
        response = await client.get("/categories/")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["name"] == "Electronics"
    assert len(data[0]["children"]) == 1


@pytest.mark.anyio
async def test_create_category_success() -> None:
    """
    POST /categories creates a category and returns 201.

    :return: None
    """
    db = _build_db(query_result=None)
    db.refresh = MagicMock()
    async with _make_client(db) as client:
        response = await client.post(
            "/categories/",
            json={"name": "New Category"},
        )
    assert response.status_code == 201
    assert response.json()["name"] == "New Category"


@pytest.mark.anyio
async def test_create_category_parent_not_found() -> None:
    """
    POST /categories returns 404 if parent_id not found.

    :return: None
    """
    db = _build_db(query_result=None)
    async with _make_client(db) as client:
        response = await client.post(
            "/categories/",
            json={
                "name": "Sub",
                "parent_id": str(uuid.uuid4()),
            },
        )
    assert response.status_code == 404
