"""Auth router — register, login, refresh, and logout endpoints."""

import re
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.dependencies import get_current_user, get_db
from app.models.tenant import Tenant
from app.models.user import User
from app.schemas.auth import (
    CurrentUser,
    LoginRequest,
    LogoutRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
    UserResponse,
)
from app.services.auth import (
    PasswordService,
    TokenBlacklist,
    TokenService,
)

router = APIRouter(prefix="/auth", tags=["auth"])


def _slug_from_name(name: str) -> str:
    """
    Derive a URL-safe slug from a shop name.

    :param name: Raw shop name string
    :return: Lowercase, hyphenated slug
    """
    slug = name.lower().strip()
    slug = re.sub(r"[^a-z0-9]+", "-", slug)
    return slug.strip("-")


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
)
def register(
    body: RegisterRequest,
    db: Session = Depends(get_db),
) -> TokenResponse:
    """
    Register a new tenant and its initial admin user.

    Creates both a Tenant row and an admin User row in a single
    database transaction, then returns a JWT token pair.

    :param body: Registration payload with shop and admin details
    :param db: Database session
    :return: Access and refresh token pair
    :raises HTTPException: 409 if the slug is already taken
    :raises HTTPException: 409 if the email is already registered
    """
    existing_tenant = (
        db.query(Tenant)
        .filter(Tenant.slug == body.slug)
        .first()
    )
    if existing_tenant:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Tenant slug '{body.slug}' is already taken",
        )

    tenant = Tenant(
        id=uuid.uuid4(),
        name=body.shop_name,
        slug=body.slug,
        plan="starter",
        is_active=True,
    )
    db.add(tenant)
    db.flush()

    existing_user = (
        db.query(User)
        .filter(
            User.tenant_id == tenant.id,
            User.email == body.email,
        )
        .first()
    )
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email is already registered for this tenant",
        )

    admin = User(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        name=body.admin_name,
        email=body.email,
        password_hash=PasswordService.hash(body.password),
        role="admin",
        is_active=True,
    )
    db.add(admin)
    db.commit()
    db.refresh(admin)

    access_token = TokenService.create_access_token(
        user_id=admin.id,
        tenant_id=tenant.id,
        role=admin.role,
        email=admin.email,
    )
    refresh_token = TokenService.create_refresh_token(
        user_id=admin.id
    )
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
    )


@router.post("/login", response_model=TokenResponse)
def login(
    body: LoginRequest,
    db: Session = Depends(get_db),
) -> TokenResponse:
    """
    Authenticate a user and return a JWT token pair.

    Looks up the user by email across all tenants. If multiple users
    share the same email (different tenants), the first active match
    is used; in production, tenants would be scoped by subdomain.

    :param body: Login credentials
    :param db: Database session
    :return: Access and refresh token pair
    :raises HTTPException: 401 if credentials are invalid or account
                           is inactive
    """
    user = (
        db.query(User)
        .filter(User.email == body.email, User.is_active.is_(True))
        .first()
    )
    if user is None or not PasswordService.verify(
        body.password, user.password_hash
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = TokenService.create_access_token(
        user_id=user.id,
        tenant_id=user.tenant_id,
        role=user.role,
        email=user.email,
    )
    refresh_token = TokenService.create_refresh_token(
        user_id=user.id
    )
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh_tokens(
    body: RefreshRequest,
    db: Session = Depends(get_db),
) -> TokenResponse:
    """
    Rotate a token pair using a valid refresh token.

    The provided refresh token is blacklisted after use so it cannot
    be reused (token rotation).

    :param body: Refresh token payload
    :param db: Database session
    :return: New access and refresh token pair
    :raises HTTPException: 401 if the refresh token is invalid,
                           expired, or already blacklisted
    """
    if TokenBlacklist.is_blacklisted(body.refresh_token):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token has been revoked",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id_str = TokenService.decode_refresh_token(
        body.refresh_token
    )
    if user_id_str is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = (
        db.query(User)
        .filter(
            User.id == uuid.UUID(user_id_str),
            User.is_active.is_(True),
        )
        .first()
    )
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or deactivated",
            headers={"WWW-Authenticate": "Bearer"},
        )

    TokenBlacklist.add(body.refresh_token)

    access_token = TokenService.create_access_token(
        user_id=user.id,
        tenant_id=user.tenant_id,
        role=user.role,
        email=user.email,
    )
    new_refresh_token = TokenService.create_refresh_token(
        user_id=user.id
    )
    return TokenResponse(
        access_token=access_token,
        refresh_token=new_refresh_token,
    )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(body: LogoutRequest) -> None:
    """
    Invalidate a refresh token to log the user out.

    Adds the token to the in-memory blacklist. Logging out does not
    invalidate the short-lived access token — it expires on its own.

    :param body: Logout payload containing the refresh token
    :return: None (204 No Content)
    """
    TokenBlacklist.add(body.refresh_token)


@router.get("/me", response_model=UserResponse)
def get_me(
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserResponse:
    """
    Return the authenticated user's profile.

    :param current_user: Injected JWT context
    :param db: Database session
    :return: User profile data
    :raises HTTPException: 404 if user no longer exists
    """
    user = (
        db.query(User)
        .filter(User.id == current_user.user_id)
        .first()
    )
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    return UserResponse.model_validate(user)
