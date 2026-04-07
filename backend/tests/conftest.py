"""Shared pytest fixtures for backend tests."""

from unittest.mock import MagicMock

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.fixture(autouse=True)
def mock_redis(monkeypatch):
    """
    Replace the Redis client with an in-memory dict for all tests.

    Prevents test failures when Redis is not running locally.

    :param monkeypatch: pytest monkeypatch fixture
    :return: None
    """
    store: dict = {}

    fake = MagicMock()
    fake.setex.side_effect = lambda key, ttl, val: store.__setitem__(
        key, val
    )
    fake.exists.side_effect = lambda key: 1 if key in store else 0

    import app.services.auth as auth_mod

    monkeypatch.setattr(auth_mod, "_redis_client", fake)


@pytest.fixture
async def async_client() -> AsyncClient:
    """
    Provide an async HTTP client wired to the FastAPI app.

    :return: Configured AsyncClient instance
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport, base_url="http://test"
    ) as client:
        yield client
