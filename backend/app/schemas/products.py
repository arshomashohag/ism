"""Pydantic schemas for product and category request/response models."""

import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.inventory import InventorySummaryItem


class CategoryResponse(BaseModel):
    """
    Category response schema with nested children.

    :ivar id: Category primary key
    :ivar tenant_id: Owning tenant
    :ivar parent_id: Parent category id if nested
    :ivar name: Category display name
    :ivar children: Nested subcategories
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    tenant_id: uuid.UUID
    parent_id: uuid.UUID | None = None
    name: str
    children: list["CategoryResponse"] = Field(default_factory=list)


CategoryResponse.model_rebuild()


class CategoryCreate(BaseModel):
    """
    Request body for creating a category.

    :ivar name: Category display name
    :ivar parent_id: Optional parent category UUID
    """

    name: str = Field(min_length=1, max_length=100)
    parent_id: uuid.UUID | None = None


class ProductCreate(BaseModel):
    """
    Request body for creating a product.

    :ivar sku: Stock-keeping unit, unique within tenant
    :ivar name: Product name
    :ivar barcode: Optional barcode string
    :ivar category_id: Optional category UUID
    :ivar unit_price: Selling price, must be > 0
    :ivar cost_price: Optional purchase cost, must be >= 0
    :ivar tax_rate: VAT/GST rate between 0.0 and 1.0
    :ivar metadata: Flexible JSONB attributes
    """

    sku: str = Field(min_length=1, max_length=50)
    name: str = Field(min_length=1, max_length=255)
    barcode: str | None = Field(default=None, max_length=100)
    category_id: uuid.UUID | None = None
    unit_price: float
    cost_price: float | None = None
    tax_rate: float = 0.0
    metadata: dict[str, Any] = Field(default_factory=dict)

    @field_validator("unit_price")
    @classmethod
    def unit_price_positive(cls, v: float) -> float:
        """
        Validate that unit_price is greater than zero.

        :param v: The unit price value
        :return: Validated unit price
        :raises ValueError: If unit price is not positive
        """
        if v <= 0:
            raise ValueError("unit_price must be greater than 0")
        return v

    @field_validator("cost_price")
    @classmethod
    def cost_price_non_negative(
        cls, v: float | None
    ) -> float | None:
        """
        Validate that cost_price is non-negative when provided.

        :param v: The cost price value or None
        :return: Validated cost price
        :raises ValueError: If cost price is negative
        """
        if v is not None and v < 0:
            raise ValueError("cost_price must be >= 0")
        return v

    @field_validator("tax_rate")
    @classmethod
    def tax_rate_in_range(cls, v: float) -> float:
        """
        Validate that tax_rate is between 0.0 and 1.0.

        :param v: The tax rate value
        :return: Validated tax rate
        :raises ValueError: If tax rate is outside [0.0, 1.0]
        """
        if not 0.0 <= v <= 1.0:
            raise ValueError("tax_rate must be between 0.0 and 1.0")
        return v


class ProductUpdate(BaseModel):
    """
    Request body for partially updating a product.

    All fields are optional; only provided fields are updated.

    :ivar sku: Stock-keeping unit
    :ivar name: Product name
    :ivar barcode: Barcode string
    :ivar category_id: Category UUID
    :ivar unit_price: Selling price, must be > 0
    :ivar cost_price: Purchase cost, must be >= 0
    :ivar tax_rate: VAT/GST rate between 0.0 and 1.0
    :ivar metadata: Flexible JSONB attributes
    """

    sku: str | None = Field(
        default=None, min_length=1, max_length=50
    )
    name: str | None = Field(
        default=None, min_length=1, max_length=255
    )
    barcode: str | None = Field(default=None, max_length=100)
    category_id: uuid.UUID | None = None
    unit_price: float | None = None
    cost_price: float | None = None
    tax_rate: float | None = None
    metadata: dict[str, Any] | None = None

    @field_validator("unit_price")
    @classmethod
    def unit_price_positive(cls, v: float | None) -> float | None:
        """
        Validate unit_price is positive when provided.

        :param v: The unit price value or None
        :return: Validated unit price
        :raises ValueError: If unit price is not positive
        """
        if v is not None and v <= 0:
            raise ValueError("unit_price must be greater than 0")
        return v

    @field_validator("cost_price")
    @classmethod
    def cost_price_non_negative(
        cls, v: float | None
    ) -> float | None:
        """
        Validate cost_price is non-negative when provided.

        :param v: The cost price value or None
        :return: Validated cost price
        :raises ValueError: If cost price is negative
        """
        if v is not None and v < 0:
            raise ValueError("cost_price must be >= 0")
        return v

    @field_validator("tax_rate")
    @classmethod
    def tax_rate_in_range(cls, v: float | None) -> float | None:
        """
        Validate tax_rate is in [0.0, 1.0] when provided.

        :param v: The tax rate value or None
        :return: Validated tax rate
        :raises ValueError: If tax rate is outside [0.0, 1.0]
        """
        if v is not None and not 0.0 <= v <= 1.0:
            raise ValueError(
                "tax_rate must be between 0.0 and 1.0"
            )
        return v


class ProductResponse(BaseModel):
    """
    Full product response schema.

    :ivar id: Product primary key
    :ivar tenant_id: Owning tenant
    :ivar sku: Stock-keeping unit
    :ivar name: Product name
    :ivar barcode: Optional barcode
    :ivar category_id: Optional category UUID
    :ivar category_name: Optional resolved category name
    :ivar unit_price: Selling price
    :ivar cost_price: Optional purchase cost
    :ivar tax_rate: VAT/GST rate
    :ivar metadata: Flexible JSONB attributes
    :ivar is_active: Soft-delete flag
    :ivar created_at: Record creation timestamp
    :ivar updated_at: Last update timestamp
    """

    model_config = ConfigDict(
        from_attributes=True, populate_by_name=True
    )

    id: uuid.UUID
    tenant_id: uuid.UUID
    sku: str
    name: str
    barcode: str | None = None
    category_id: uuid.UUID | None = None
    category_name: str | None = None
    unit_price: float
    cost_price: float | None = None
    tax_rate: float
    metadata: dict[str, Any] = Field(
        alias="metadata_", default_factory=dict
    )
    is_active: bool
    created_at: datetime
    updated_at: datetime
    inventory_summary: list[InventorySummaryItem] = Field(
        default_factory=list
    )


class ProductListResponse(BaseModel):
    """
    Paginated product list response.

    :ivar items: List of products on the current page
    :ivar total: Total number of matching products
    :ivar page: Current page number (1-based)
    :ivar page_size: Number of items per page
    """

    items: list[ProductResponse]
    total: int
    page: int
    page_size: int
