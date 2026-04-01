"""Pydantic schemas for authentication request/response models."""

import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, field_validator


class RegisterRequest(BaseModel):
    """
    Payload for registering a new tenant and admin user.

    :ivar shop_name: Display name for the tenant shop
    :ivar slug: URL-safe unique tenant identifier
    :ivar admin_name: Full name of the initial admin user
    :ivar email: Admin login email
    :ivar password: Plain-text password (hashed before storage)
    """

    shop_name: str
    slug: str
    admin_name: str
    email: EmailStr
    password: str

    @field_validator("slug")
    @classmethod
    def slug_lowercase_alphanumeric(cls, value: str) -> str:
        """
        Ensure slug contains only lowercase letters, digits, hyphens.

        :param value: Raw slug string
        :return: Validated slug
        :raises ValueError: If slug has invalid characters
        """
        import re
        if not re.match(r"^[a-z0-9-]+$", value):
            raise ValueError(
                "slug must contain only lowercase letters, "
                "digits, and hyphens"
            )
        return value

    @field_validator("password")
    @classmethod
    def password_min_length(cls, value: str) -> str:
        """
        Ensure password meets minimum length requirement.

        :param value: Raw password string
        :return: Validated password
        :raises ValueError: If password is shorter than 8 characters
        """
        if len(value) < 8:
            raise ValueError(
                "password must be at least 8 characters"
            )
        return value


class LoginRequest(BaseModel):
    """
    Payload for authenticating an existing user.

    :ivar email: User's registered email address
    :ivar password: Plain-text password for verification
    """

    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    """
    JWT token pair returned after successful authentication.

    :ivar access_token: Short-lived JWT for API access (15 min)
    :ivar refresh_token: Long-lived JWT for rotating tokens (7 days)
    :ivar token_type: Always 'bearer'
    """

    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshRequest(BaseModel):
    """
    Payload for rotating a token pair using a refresh token.

    :ivar refresh_token: Valid, unexpired refresh token
    """

    refresh_token: str


class LogoutRequest(BaseModel):
    """
    Payload for invalidating a refresh token on logout.

    :ivar refresh_token: Token to add to the blacklist
    """

    refresh_token: str


class CurrentUser(BaseModel):
    """
    Authenticated user context injected into protected endpoints.

    :ivar user_id: User's UUID primary key
    :ivar tenant_id: Tenant the user belongs to
    :ivar role: RBAC role (admin | manager | salesman)
    :ivar email: User's email address
    """

    user_id: uuid.UUID
    tenant_id: uuid.UUID
    role: str
    email: str


class UserResponse(BaseModel):
    """
    Public representation of a user, safe to return in API responses.

    :ivar id: User UUID
    :ivar tenant_id: Owning tenant UUID
    :ivar name: Display name
    :ivar email: Login email
    :ivar role: RBAC role
    :ivar is_active: Account active status
    :ivar created_at: Account creation timestamp
    """

    id: uuid.UUID
    tenant_id: uuid.UUID
    name: str
    email: str
    role: str
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}
