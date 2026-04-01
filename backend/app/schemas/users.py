"""Pydantic schemas for user management request/response models."""

from pydantic import BaseModel, EmailStr, field_validator

from app.schemas.auth import UserResponse

VALID_ROLES = ("admin", "manager", "salesman")


class UserCreate(BaseModel):
    """
    Payload for creating a new user within a tenant.

    :ivar name: Display name (max 255 characters)
    :ivar email: User login email
    :ivar password: Plain-text password (min 8 characters)
    :ivar role: RBAC role (admin, manager, or salesman)
    """

    name: str
    email: EmailStr
    password: str
    role: str = "salesman"

    @field_validator("name")
    @classmethod
    def name_max_length(cls, value: str) -> str:
        """
        Ensure name does not exceed 255 characters.

        :param value: Raw name string
        :return: Validated name
        :raises ValueError: If name exceeds 255 characters
        """
        if len(value) > 255:
            raise ValueError(
                "name must not exceed 255 characters"
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

    @field_validator("role")
    @classmethod
    def role_valid(cls, value: str) -> str:
        """
        Ensure role is one of the accepted values.

        :param value: Raw role string
        :return: Validated role
        :raises ValueError: If role is not in VALID_ROLES
        """
        if value not in VALID_ROLES:
            raise ValueError(
                f"role must be one of {VALID_ROLES}"
            )
        return value


class UserUpdate(BaseModel):
    """
    Payload for partially updating an existing user.

    :ivar name: Optional new display name
    :ivar role: Optional new RBAC role
    :ivar is_active: Optional account active status
    """

    name: str | None = None
    role: str | None = None
    is_active: bool | None = None

    @field_validator("role")
    @classmethod
    def role_valid(cls, value: str | None) -> str | None:
        """
        Ensure role is one of the accepted values when provided.

        :param value: Raw role string or None
        :return: Validated role or None
        :raises ValueError: If role is not in VALID_ROLES
        """
        if value is not None and value not in VALID_ROLES:
            raise ValueError(
                f"role must be one of {VALID_ROLES}"
            )
        return value


class UserListResponse(BaseModel):
    """
    Paginated list of users.

    :ivar items: Page of UserResponse objects
    :ivar total: Total matching record count
    :ivar page: Current page number (1-based)
    :ivar page_size: Items per page
    """

    items: list[UserResponse]
    total: int
    page: int
    page_size: int
