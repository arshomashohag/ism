"""FastAPI dependency injection — DB session and auth dependencies."""

import uuid
from typing import Generator

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.config import settings
from app.schemas.auth import CurrentUser
from app.services.auth import TokenService

engine = create_engine(
    settings.database_url,
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


def get_db() -> Generator[Session, None, None]:
    """
    Yield a scoped SQLAlchemy session for a single request.

    The session is automatically closed after the request
    regardless of whether an exception was raised.

    :return: SQLAlchemy Session generator
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


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
