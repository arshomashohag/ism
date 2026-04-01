"""Categories router — list and create product categories."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.dependencies import get_current_user, get_db, require_role
from app.models.category import Category
from app.schemas.auth import CurrentUser
from app.schemas.products import CategoryCreate, CategoryResponse
from app.services.audit import AuditService

router = APIRouter(prefix="/categories", tags=["categories"])


def _build_category_tree(
    categories: list[Category],
) -> list[CategoryResponse]:
    """
    Convert a flat list of Category rows into a nested tree.

    :param categories: All categories for a tenant
    :return: List of root CategoryResponse objects with children
    """
    by_id: dict[uuid.UUID, CategoryResponse] = {}
    for cat in categories:
        by_id[cat.id] = CategoryResponse(
            id=cat.id,
            tenant_id=cat.tenant_id,
            parent_id=cat.parent_id,
            name=cat.name,
            children=[],
        )

    roots: list[CategoryResponse] = []
    for cat in categories:
        node = by_id[cat.id]
        if cat.parent_id is None:
            roots.append(node)
        elif cat.parent_id in by_id:
            by_id[cat.parent_id].children.append(node)

    return roots


@router.get("/", response_model=list[CategoryResponse])
def list_categories(
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[CategoryResponse]:
    """
    Return all categories for the tenant as a nested tree.

    :param current_user: Injected JWT context
    :param db: Database session
    :return: Nested list of CategoryResponse trees
    """
    categories = (
        db.query(Category)
        .filter(Category.tenant_id == current_user.tenant_id)
        .all()
    )
    return _build_category_tree(categories)


@router.post(
    "/",
    response_model=CategoryResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_category(
    body: CategoryCreate,
    current_user: CurrentUser = Depends(
        require_role("admin", "manager")
    ),
    db: Session = Depends(get_db),
) -> CategoryResponse:
    """
    Create a new product category.

    :param body: Category creation payload
    :param current_user: Injected JWT context (admin/manager only)
    :param db: Database session
    :return: Created CategoryResponse
    :raises HTTPException: 404 if parent_id does not exist
    """
    if body.parent_id is not None:
        parent = (
            db.query(Category)
            .filter(
                Category.id == body.parent_id,
                Category.tenant_id == current_user.tenant_id,
            )
            .first()
        )
        if parent is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Parent category not found",
            )

    category = Category(
        id=uuid.uuid4(),
        tenant_id=current_user.tenant_id,
        parent_id=body.parent_id,
        name=body.name,
    )
    db.add(category)
    db.flush()

    AuditService.log_create(
        db=db,
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        entity_type="categories",
        entity_id=str(category.id),
        new_value={"name": category.name},
    )

    db.commit()
    db.refresh(category)

    return CategoryResponse(
        id=category.id,
        tenant_id=category.tenant_id,
        parent_id=category.parent_id,
        name=category.name,
        children=[],
    )
