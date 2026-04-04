"""Authentication services: password hashing and JWT token management."""

import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

import redis as redis_lib
from jose import JWTError, jwt
from passlib.context import CryptContext

from app.config import settings

ALGORITHM = "RS256"

_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class PasswordService:
    """
    Handles bcrypt password hashing and verification.

    Uses passlib's CryptContext for bcrypt with automatic
    rehashing of deprecated schemes.
    """

    @staticmethod
    def hash(plain_password: str) -> str:
        """
        Hash a plain-text password with bcrypt.

        :param plain_password: Raw password from registration form
        :return: bcrypt hash suitable for database storage
        """
        return _pwd_context.hash(plain_password)

    @staticmethod
    def verify(plain_password: str, hashed_password: str) -> bool:
        """
        Verify a plain-text password against a stored hash.

        :param plain_password: Raw password from login form
        :param hashed_password: Stored bcrypt hash from database
        :return: True if password matches, False otherwise
        """
        return _pwd_context.verify(plain_password, hashed_password)


class TokenService:
    """
    Issues and validates RS256-signed JWT access and refresh tokens.

    Access tokens carry user_id, tenant_id, role, and email with a
    15-minute expiry. Refresh tokens carry only user_id with a 7-day
    expiry to minimise privilege exposure.
    """

    @staticmethod
    def create_access_token(
        user_id: uuid.UUID,
        tenant_id: uuid.UUID,
        role: str,
        email: str,
    ) -> str:
        """
        Issue a short-lived RS256 access token.

        :param user_id: User's primary key UUID
        :param tenant_id: Tenant UUID for multi-tenant scoping
        :param role: RBAC role string (admin | manager | salesman)
        :param email: User's email address
        :return: Signed JWT access token string
        """
        expire = datetime.now(timezone.utc) + timedelta(
            minutes=settings.access_token_expire_minutes
        )
        payload = {
            "sub": str(user_id),
            "tenant_id": str(tenant_id),
            "role": role,
            "email": email,
            "type": "access",
            "exp": expire,
        }
        return jwt.encode(
            payload,
            settings.jwt_private_key,
            algorithm=ALGORITHM,
        )

    @staticmethod
    def create_refresh_token(user_id: uuid.UUID) -> str:
        """
        Issue a long-lived RS256 refresh token.

        Contains only user_id to minimise privilege exposure if
        the token is intercepted.

        :param user_id: User's primary key UUID
        :return: Signed JWT refresh token string
        """
        expire = datetime.now(timezone.utc) + timedelta(
            days=settings.refresh_token_expire_days
        )
        payload = {
            "sub": str(user_id),
            "type": "refresh",
            "exp": expire,
        }
        return jwt.encode(
            payload,
            settings.jwt_private_key,
            algorithm=ALGORITHM,
        )

    @staticmethod
    def decode_access_token(token: str) -> Optional[dict]:
        """
        Decode and validate an access token.

        :param token: Raw JWT string from Authorization header
        :return: Decoded payload dict, or None if invalid/expired
        """
        try:
            payload = jwt.decode(
                token,
                settings.jwt_public_key,
                algorithms=[ALGORITHM],
            )
            if payload.get("type") != "access":
                return None
            return payload
        except JWTError:
            return None

    @staticmethod
    def decode_refresh_token(token: str) -> Optional[str]:
        """
        Decode and validate a refresh token.

        :param token: Raw JWT refresh token string
        :return: user_id string if valid, None if invalid/expired
        """
        try:
            payload = jwt.decode(
                token,
                settings.jwt_public_key,
                algorithms=[ALGORITHM],
            )
            if payload.get("type") != "refresh":
                return None
            return payload.get("sub")
        except JWTError:
            return None


def _make_redis_client() -> redis_lib.Redis:
    """
    Create a Redis client from the configured URL.

    :return: Connected Redis client instance
    """
    return redis_lib.from_url(
        settings.redis_url,
        decode_responses=True,
    )


_redis_client: Optional[redis_lib.Redis] = None


def _get_redis() -> redis_lib.Redis:
    """
    Return the module-level Redis client, creating it on first call.

    :return: Redis client instance
    """
    global _redis_client
    if _redis_client is None:
        _redis_client = _make_redis_client()
    return _redis_client


_BLACKLIST_TTL = 60 * 60 * 24 * 8


class TokenBlacklist:
    """
    Redis-backed refresh token blacklist.

    Stores invalidated refresh tokens with a TTL slightly longer
    than the refresh token lifetime so entries expire automatically.
    """

    @staticmethod
    def add(token: str) -> None:
        """
        Add a refresh token to the Redis blacklist.

        The key expires after 8 days (refresh token lifetime + 1 day).

        :param token: Refresh token to invalidate
        :return: None
        """
        try:
            _get_redis().setex(
                f"blacklist:{token}", _BLACKLIST_TTL, "1"
            )
        except redis_lib.RedisError:
            pass

    @staticmethod
    def is_blacklisted(token: str) -> bool:
        """
        Check whether a refresh token has been invalidated.

        Returns False on Redis connection errors to avoid blocking
        legitimate logins when Redis is temporarily unavailable.

        :param token: Refresh token to check
        :return: True if token is blacklisted
        """
        try:
            return _get_redis().exists(f"blacklist:{token}") == 1
        except redis_lib.RedisError:
            return False
