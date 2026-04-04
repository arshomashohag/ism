"""FastAPI dependency injection — DB session and auth dependencies."""

import uuid
from functools import lru_cache
from typing import Generator

from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session, sessionmaker

from app.config import settings
from app.schemas.auth import CurrentUser
from app.services.auth import TokenService

_db_url = (
    settings.pgbouncer_url
    if settings.pgbouncer_url
    else settings.database_url
)

engine = create_engine(
    _db_url,
    pool_pre_ping=True,
    pool_size=5,
    max_overflow=10,
)

SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
)

_bearer_scheme = HTTPBearer()


@lru_cache(maxsize=256)
def _resolve_schema(tenant_id: str) -> str:
    """
    Resolve the PostgreSQL schema name for a tenant.

    Queries public.tenants once per unique tenant_id and caches
    the result in an LRU cache to avoid repeated DB round-trips.

    :param tenant_id: Tenant UUID as string
    :return: Schema name (slug) for the tenant
    :raises HTTPException: 403 if tenant not found or inactive
    """
    db = SessionLocal()
    try:
        row = db.execute(
            text(
                "SELECT slug, is_active FROM tenants "
                "WHERE id = :tid"
            ),
            {"tid": tenant_id},
        ).fetchone()
    finally:
        db.close()

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tenant not found",
        )
    if not row.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tenant account is suspended",
        )
    return row.slug


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(
        _bearer_scheme
    ),
) -> CurrentUser:
    """
    Extract and validate the JWT access token from the request.

    Decodes the Bearer token from the Authorization header and
    returns the authenticated user context.

    :param credentials: HTTP Bearer credentials from Authorization header
    :return: CurrentUser with user_id, tenant_id, role, email
    :raises HTTPException: 401 if token is missing, invalid, or expired
    """
    token = credentials.credentials
    payload = TokenService.decode_access_token(token)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return CurrentUser(
        user_id=uuid.UUID(payload["sub"]),
        tenant_id=uuid.UUID(payload["tenant_id"]),
        role=payload["role"],
        email=payload["email"],
    )


def get_tenant_db(
    current_user: CurrentUser = Depends(get_current_user),
) -> Generator[Session, None, None]:
    """
    Yield a SQLAlchemy session scoped to the current tenant's schema.

    Sets the PostgreSQL search_path to the tenant's schema for the
    duration of the request, ensuring schema-level isolation between
    tenants.

    :param current_user: Authenticated user with tenant_id
    :return: SQLAlchemy Session generator
    :raises HTTPException: 403 if tenant is unknown or suspended
    """
    schema = _resolve_schema(str(current_user.tenant_id))
    db = SessionLocal()
    try:
        db.execute(
            text(f"SET LOCAL search_path TO {schema}, public")
        )
        yield db
    finally:
        db.close()


def get_admin_db() -> Generator[Session, None, None]:
    """
    Yield an unscoped SQLAlchemy session for the public schema.

    Used by admin and auth endpoints that query public.tenants and
    public.users directly without tenant-level isolation.

    :return: SQLAlchemy Session generator
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def require_role(*allowed_roles: str):
    """
    Return a FastAPI dependency that enforces RBAC role restrictions.

    Usage::

        @router.delete(
            "/{id}",
            dependencies=[Depends(require_role("admin"))],
        )

    :param allowed_roles: One or more role strings permitted to access
                          the endpoint
    :return: FastAPI Depends-compatible callable
    :raises HTTPException: 403 if the current user's role is not in
                           the allowed set
    """

    def _check_role(
        current_user: CurrentUser = Depends(get_current_user),
    ) -> CurrentUser:
        """
        Validate that the current user holds an allowed role.

        :param current_user: Injected authenticated user context
        :return: CurrentUser if role is allowed
        :raises HTTPException: 403 Forbidden if role not permitted
        """
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    f"Role '{current_user.role}' is not authorised "
                    f"for this action"
                ),
            )
        return current_user

    return _check_role


def require_admin_key(
    x_admin_key: str = Header(alias="X-Admin-Key"),
) -> None:
    """
    Validate the static X-Admin-Key header for admin endpoints.

    :param x_admin_key: Value of the X-Admin-Key request header
    :return: None
    :raises HTTPException: 403 if the key does not match settings
    """
    if x_admin_key != settings.admin_api_key:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid admin API key",
        )
