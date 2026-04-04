"""FastAPI application entrypoint."""

import logging
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.middleware.logging import RequestLoggingMiddleware
from app.routers import admin as admin_router
from app.routers import analytics as analytics_router
from app.routers import auth as auth_router
from app.routers import categories as categories_router
from app.routers import inventory as inventory_router
from app.routers import products as products_router
from app.routers import sales as sales_router
from app.routers import users as users_router

logger = logging.getLogger("ims.main")


@asynccontextmanager
async def lifespan(application: FastAPI) -> AsyncGenerator:
    """
    Manage application startup and shutdown lifecycle.

    :param application: FastAPI application instance
    :return: Async context manager
    """
    logger.info(
        "IMS backend starting",
        extra={
            "version": settings.app_version,
            "environment": settings.environment,
        },
    )
    yield


app = FastAPI(
    title="IMS Backend",
    version=settings.app_version,
    description="Inventory Management System API",
    lifespan=lifespan,
)

app.add_middleware(RequestLoggingMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(admin_router.router)
app.include_router(analytics_router.router)
app.include_router(auth_router.router)
app.include_router(categories_router.router)
app.include_router(products_router.router)
app.include_router(inventory_router.router)
app.include_router(sales_router.router)
app.include_router(users_router.router)


@app.get("/health")
async def health_check() -> dict:
    """
    Return application health status.

    :return: Health status payload with version and environment
    """
    return {
        "status": "ok",
        "version": settings.app_version,
        "environment": settings.environment,
    }
