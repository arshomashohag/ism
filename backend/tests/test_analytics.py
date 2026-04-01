"""
Tests for analytics endpoints — permission and response shape.

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

TENANT_ID = uuid.uuid4()
USER_ID = uuid.uuid4()
SALESMAN_ID = uuid.uuid4()
PRODUCT_ID = uuid.uuid4()
WAREHOUSE_ID = uuid.uuid4()


def _admin_context() -> CurrentUser:
    """
    Return an admin CurrentUser fixture.

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
    Return a manager CurrentUser fixture.

    :return: CurrentUser with manager role
    """
    return CurrentUser(
        user_id=uuid.uuid4(),
        tenant_id=TENANT_ID,
        role="manager",
        email="manager@test.shop",
    )


def _make_line_item(
    product_id: uuid.UUID | None = None,
    qty: int = 2,
    line_total: float = 20.0,
    warehouse_id: uuid.UUID | None = None,
) -> MagicMock:
    """
    Build a mock SaleLineItem-like object.

    :param product_id: Product UUID for the line
    :param qty: Units sold
    :param line_total: Line revenue amount
    :param warehouse_id: Warehouse on the parent transaction
    :return: Mock SaleLineItem
    """
    li = MagicMock()
    li.id = uuid.uuid4()
    li.product_id = product_id or PRODUCT_ID
    li.product_name = "Test Product"
    li.qty = qty
    li.line_total = line_total
    li.transaction = MagicMock()
    li.transaction.warehouse_id = warehouse_id or WAREHOUSE_ID
    return li


def _make_sale(
    grand_total: float = 100.0,
    salesman_id: uuid.UUID | None = None,
    status: str = "completed",
) -> MagicMock:
    """
    Build a mock SalesTransaction-like object.

    :param grand_total: Transaction grand total
    :param salesman_id: Salesman UUID or None
    :param status: completed | voided
    :return: Mock SalesTransaction
    """
    s = MagicMock()
    s.id = uuid.uuid4()
    s.tenant_id = TENANT_ID
    s.grand_total = grand_total
    s.tax_total = 0.0
    s.discount = 0.0
    s.status = status
    s.salesman_id = salesman_id or SALESMAN_ID
    s.warehouse_id = WAREHOUSE_ID
    _ts = datetime(2026, 4, 1, 12, 0, tzinfo=timezone.utc)
    s.created_at = _ts
    s.line_items = [_make_line_item()]
    return s


def _make_inventory_entry() -> MagicMock:
    """
    Build a mock Inventory-like object.

    :return: Mock Inventory with product/warehouse stubs
    """
    inv = MagicMock()
    inv.id = uuid.uuid4()
    inv.product_id = PRODUCT_ID
    inv.warehouse_id = WAREHOUSE_ID
    inv.qty_on_hand = 50
    inv.qty_reserved = 0
    inv.reorder_point = 10
    inv.product = MagicMock()
    inv.product.name = "Test Product"
    inv.product.sku = "SKU-001"
    inv.warehouse = MagicMock()
    inv.warehouse.name = "Main Store"
    return inv


class FakeQuery:
    """
    Minimal SQLAlchemy query stub for analytics unit tests.

    :ivar _result: Value returned by first() / scalar()
    :ivar _all: Values returned by all()
    :ivar _count: Value returned by count()
    """

    def __init__(
        self,
        result: Any = None,
        all_results: list | None = None,
        count: int = 0,
    ) -> None:
        """
        Initialise with fixed return values.

        :param result: Value for first() and scalar()
        :param all_results: Values for all()
        :param count: Value for count()
        """
        self._result = result
        self._all = all_results or []
        self._count = count

    def filter(self, *_: Any) -> "FakeQuery":
        """
        Return self.

        :return: self
        """
        return self

    def join(self, *_: Any) -> "FakeQuery":
        """
        Return self.

        :return: self
        """
        return self

    def order_by(self, *_: Any) -> "FakeQuery":
        """
        Return self.

        :return: self
        """
        return self

    def offset(self, *_: Any) -> "FakeQuery":
        """
        Return self.

        :return: self
        """
        return self

    def limit(self, *_: Any) -> "FakeQuery":
        """
        Return self.

        :return: self
        """
        return self

    def first(self) -> Any:
        """
        Return mocked first result.

        :return: Mock result
        """
        return self._result

    def all(self) -> list:
        """
        Return mocked list results.

        :return: List of mock results
        """
        return self._all

    def count(self) -> int:
        """
        Return mocked count.

        :return: Mocked row count
        """
        return self._count

    def scalar(self) -> Any:
        """
        Return mocked scalar result.

        :return: Mocked scalar value
        """
        return self._result


def _build_db(
    all_results: list | None = None,
    count: int = 0,
    scalar_result: Any = None,
    get_result: Any = None,
) -> MagicMock:
    """
    Build a mock DB session for analytics tests.

    :param all_results: Values returned by all()
    :param count: Values returned by count()
    :param scalar_result: Value returned by scalar()
    :param get_result: Value returned by db.get()
    :return: Mock Session
    """
    db = MagicMock()
    fq = FakeQuery(
        result=scalar_result,
        all_results=all_results or [],
        count=count,
    )
    db.query.return_value = fq
    db.get.return_value = get_result
    db.execute = MagicMock()
    db.commit = MagicMock()
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
async def test_sales_summary_admin_200() -> None:
    """
    GET /analytics/sales-summary returns 200 for admin.

    :return: None
    """
    sale = _make_sale()
    db = _build_db(all_results=[sale], scalar_result=0)
    async with _make_client(db, _admin_context) as client:
        response = await client.get(
            "/analytics/sales-summary"
        )
    assert response.status_code == 200
    data = response.json()
    assert "total_revenue" in data
    assert "daily_trend" in data
    assert "top_products" in data


@pytest.mark.anyio
async def test_sales_summary_manager_403() -> None:
    """
    GET /analytics/sales-summary returns 403 for manager.

    :return: None
    """
    db = _build_db()
    async with _make_client(db, _manager_context) as client:
        response = await client.get(
            "/analytics/sales-summary"
        )
    assert response.status_code == 403


@pytest.mark.anyio
async def test_sales_summary_empty() -> None:
    """
    GET /analytics/sales-summary returns zeros when no sales.

    :return: None
    """
    db = _build_db(all_results=[], scalar_result=0)
    async with _make_client(db, _admin_context) as client:
        response = await client.get(
            "/analytics/sales-summary"
        )
    assert response.status_code == 200
    data = response.json()
    assert data["total_revenue"] == 0.0
    assert data["total_transactions"] == 0
    assert data["daily_trend"] == []
    assert data["top_products"] == []


@pytest.mark.anyio
async def test_sales_summary_growth_calc() -> None:
    """
    GET /analytics/sales-summary computes revenue growth %.

    Uses a custom date range so both current and previous
    period return known values.

    :return: None
    """
    sale_current = _make_sale(grand_total=200.0)
    sale_prev = _make_sale(grand_total=100.0)

    call_count = 0

    class _GrowthFakeQuery(FakeQuery):
        def all(self) -> list:
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                return [sale_current]
            if call_count == 2:
                return [sale_prev]
            return []

    db = MagicMock()
    db.query.return_value = _GrowthFakeQuery(
        result=0, all_results=[]
    )
    db.get.return_value = None

    async with _make_client(db, _admin_context) as client:
        response = await client.get(
            "/analytics/sales-summary",
            params={
                "date_from": "2026-03-01T00:00:00Z",
                "date_to": "2026-04-01T00:00:00Z",
            },
        )
    assert response.status_code == 200
    data = response.json()
    assert data["revenue_growth_pct"] == 100.0


@pytest.mark.anyio
async def test_salesman_kpi_admin_200() -> None:
    """
    GET /analytics/salesman-kpi returns 200 for admin.

    :return: None
    """
    sale = _make_sale()
    user = MagicMock()
    user.name = "Test Salesman"
    db = _build_db(all_results=[sale])
    db.get.return_value = user
    async with _make_client(db, _admin_context) as client:
        response = await client.get(
            "/analytics/salesman-kpi"
        )
    assert response.status_code == 200
    data = response.json()
    assert "rows" in data
    assert len(data["rows"]) == 1
    assert data["rows"][0]["total_sales"] == 1


@pytest.mark.anyio
async def test_salesman_kpi_manager_403() -> None:
    """
    GET /analytics/salesman-kpi returns 403 for manager.

    :return: None
    """
    db = _build_db()
    async with _make_client(db, _manager_context) as client:
        response = await client.get(
            "/analytics/salesman-kpi"
        )
    assert response.status_code == 403


@pytest.mark.anyio
async def test_inventory_health_admin_200() -> None:
    """
    GET /analytics/inventory-health returns 200 for admin.

    :return: None
    """
    inv = _make_inventory_entry()
    db = _build_db(all_results=[inv])
    async with _make_client(db, _admin_context) as client:
        response = await client.get(
            "/analytics/inventory-health"
        )
    assert response.status_code == 200
    data = response.json()
    assert "total_skus" in data
    assert "rows" in data
    assert data["total_skus"] == 1


@pytest.mark.anyio
async def test_inventory_health_manager_403() -> None:
    """
    GET /analytics/inventory-health returns 403 for manager.

    :return: None
    """
    db = _build_db()
    async with _make_client(db, _manager_context) as client:
        response = await client.get(
            "/analytics/inventory-health"
        )
    assert response.status_code == 403


@pytest.mark.anyio
async def test_refresh_admin_200() -> None:
    """
    POST /analytics/refresh returns 200 for admin.

    Patches the raw SQL execute so no real DB needed.

    :return: None
    """
    db = _build_db()
    async with _make_client(db, _admin_context) as client:
        response = await client.post(
            "/analytics/refresh"
        )
    assert response.status_code == 200
    data = response.json()
    assert "refreshed_at" in data
    assert "3 materialized views" in data["message"]


@pytest.mark.anyio
async def test_refresh_manager_403() -> None:
    """
    POST /analytics/refresh returns 403 for manager.

    :return: None
    """
    db = _build_db()
    async with _make_client(db, _manager_context) as client:
        response = await client.post(
            "/analytics/refresh"
        )
    assert response.status_code == 403
