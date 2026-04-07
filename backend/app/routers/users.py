"""Users router — admin-only CRUD for tenant users."""

import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.dependencies import get_tenant_db, require_role
from app.models.user import User
from app.schemas.auth import CurrentUser, UserResponse
from app.schemas.users import UserCreate, UserListResponse, UserUpdate
from app.services.audit import AuditService
from app.services.auth import PasswordService

router = APIRouter(prefix="/users", tags=["users"])


def _user_snapshot(user: User) -> dict[str, Any]:
    """
    Capture a serialisable snapshot of mutable user fields.

    :param user: SQLAlchemy User instance
    :return: Dict suitable for audit log JSON storage
    """
    return {
        "name": user.name,
        "email": user.email,
        "role": user.role,
        "is_active": user.is_active,
    }


@router.get("/", response_model=UserListResponse)
def list_users(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    current_user: CurrentUser = Depends(require_role("admin")),
    db: Session = Depends(get_tenant_db),
) -> UserListResponse:
    """
    Return a paginated list of all users for the tenant.

    Admins see all users including inactive ones.

    :param page: Page number, 1-based
    :param page_size: Items per page (max 100)
    :param current_user: Injected JWT context (admin only)
    :param db: Database session
    :return: Paginated UserListResponse
    """
    query = (
        db.query(User)
        .filter(User.tenant_id == current_user.tenant_id)
        .order_by(User.created_at.asc())
    )

    total = query.count()
    users = (
        query.offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )

    return UserListResponse(
        items=[
            UserResponse.model_validate(u) for u in users
        ],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.post(
    "/",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_user(
    body: UserCreate,
    current_user: CurrentUser = Depends(require_role("admin")),
    db: Session = Depends(get_tenant_db),
) -> UserResponse:
    """
    Create a new user within the tenant.

    :param body: User creation payload
    :param current_user: Injected JWT context (admin only)
    :param db: Database session
    :return: Created UserResponse
    :raises HTTPException: 409 if email already exists for tenant
    """
    existing = (
        db.query(User)
        .filter(
            User.tenant_id == current_user.tenant_id,
            User.email == body.email,
        )
        .first()
    )
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Email '{body.email}' already exists",
        )

    user = User(
        id=uuid.uuid4(),
        tenant_id=current_user.tenant_id,
        name=body.name,
        email=body.email,
        password_hash=PasswordService.hash(body.password),
        role=body.role,
        is_active=True,
    )
    db.add(user)
    db.flush()

    AuditService.log_create(
        db=db,
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        entity_type="users",
        entity_id=str(user.id),
        new_value=_user_snapshot(user),
    )

    db.commit()
    db.refresh(user)
    return UserResponse.model_validate(user)


@router.patch("/{user_id}", response_model=UserResponse)
def update_user(
    user_id: uuid.UUID,
    body: UserUpdate,
    current_user: CurrentUser = Depends(require_role("admin")),
    db: Session = Depends(get_tenant_db),
) -> UserResponse:
    """
    Partially update a user.

    :param user_id: User UUID from path
    :param body: Partial update payload
    :param current_user: Injected JWT context (admin only)
    :param db: Database session
    :return: Updated UserResponse
    :raises HTTPException: 404 if not found or wrong tenant
    """
    user = (
        db.query(User)
        .filter(
            User.id == user_id,
            User.tenant_id == current_user.tenant_id,
        )
        .first()
    )
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    updates = body.model_dump(exclude_unset=True)
    old_snapshot = _user_snapshot(user)

    for field, value in updates.items():
        setattr(user, field, value)

    AuditService.log_update(
        db=db,
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        entity_type="users",
        entity_id=str(user.id),
        old_value=old_snapshot,
        new_value=_user_snapshot(user),
    )

    db.commit()
    db.refresh(user)
    return UserResponse.model_validate(user)


@router.delete(
    "/{user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_user(
    user_id: uuid.UUID,
    current_user: CurrentUser = Depends(require_role("admin")),
    db: Session = Depends(get_tenant_db),
) -> None:
    """
    Soft-delete a user by setting is_active=False.

    :param user_id: User UUID from path
    :param current_user: Injected JWT context (admin only)
    :param db: Database session
    :return: None (204 No Content)
    :raises HTTPException: 404 if not found or wrong tenant
    :raises HTTPException: 409 if attempting to deactivate own account
    """
    user = (
        db.query(User)
        .filter(
            User.id == user_id,
            User.tenant_id == current_user.tenant_id,
        )
        .first()
    )
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    if user.id == current_user.user_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cannot deactivate your own account",
        )

    snapshot = _user_snapshot(user)
    user.is_active = False

    AuditService.log_delete(
        db=db,
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        entity_type="users",
        entity_id=str(user.id),
        old_value=snapshot,
    )

    db.commit()
