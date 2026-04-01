"""Shared pytest fixtures for backend tests."""

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


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
