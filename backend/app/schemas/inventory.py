"""Pydantic schemas for inventory request/response models."""

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class WarehouseResponse(BaseModel):
    """
    Warehouse summary for embedding in inventory responses.

    :ivar id: Warehouse UUID
    :ivar name: Warehouse display name
    :ivar is_active: Whether the warehouse is active
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    is_active: bool


class InventoryResponse(BaseModel):
    """
    Stock level for one product at one warehouse.

    :ivar id: Inventory record UUID
    :ivar product_id: Associated product UUID
    :ivar product_name: Resolved product name
    :ivar product_sku: Resolved product SKU
    :ivar warehouse_id: Associated warehouse UUID
    :ivar warehouse_name: Resolved warehouse name
    :ivar qty_on_hand: Current available quantity
    :ivar qty_reserved: Quantity held for pending orders
    :ivar qty_available: qty_on_hand minus qty_reserved
    :ivar reorder_point: Low-stock alert threshold
    :ivar stock_status: Health label: ok, low, or out
    :ivar last_counted_at: Timestamp of last physical count
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    product_id: uuid.UUID
    product_name: str
    product_sku: str
    warehouse_id: uuid.UUID
    warehouse_name: str
    qty_on_hand: int
    qty_reserved: int
    qty_available: int
    reorder_point: int
    stock_status: Literal["ok", "low", "out"]
    last_counted_at: datetime | None = None


class InventoryListResponse(BaseModel):
    """
    Paginated inventory list response.

    :ivar items: Inventory entries on the current page
    :ivar total: Total matching entries
    :ivar page: Current page number (1-based)
    :ivar page_size: Items per page
    """

    items: list[InventoryResponse]
    total: int
    page: int
    page_size: int


class InventorySummaryItem(BaseModel):
    """
    Brief inventory snapshot for a single warehouse, embedded in product
    detail.

    :ivar warehouse_id: Warehouse UUID
    :ivar warehouse_name: Warehouse display name
    :ivar qty_on_hand: Current stock level
    :ivar qty_reserved: Reserved quantity
    :ivar qty_available: Available (on_hand - reserved)
    :ivar reorder_point: Low-stock threshold
    :ivar stock_status: Health label
    """

    warehouse_id: uuid.UUID
    warehouse_name: str
    qty_on_hand: int
    qty_reserved: int
    qty_available: int
    reorder_point: int
    stock_status: Literal["ok", "low", "out"]


class AdjustRequest(BaseModel):
    """
    Request body for a stock adjustment (delta-based).

    :ivar warehouse_id: Target warehouse UUID
    :ivar product_id: Target product UUID
    :ivar delta: Signed integer change (+add / -remove)
    :ivar reason: Human-readable reason for the adjustment
    """

    warehouse_id: uuid.UUID
    product_id: uuid.UUID
    delta: int = Field(..., ne=0)
    reason: str = Field(min_length=1, max_length=255)

    @field_validator("delta")
    @classmethod
    def delta_non_zero(cls, v: int) -> int:
        """
        Validate that delta is not zero.

        :param v: Delta value
        :return: Validated delta
        :raises ValueError: If delta is zero
        """
        if v == 0:
            raise ValueError("delta must not be zero")
        return v


class TransferRequest(BaseModel):
    """
    Request body for a stock transfer between warehouses.

    :ivar product_id: Product UUID to transfer
    :ivar from_warehouse_id: Source warehouse UUID
    :ivar to_warehouse_id: Destination warehouse UUID
    :ivar qty: Positive quantity to move
    :ivar reason: Human-readable reason for the transfer
    """

    product_id: uuid.UUID
    from_warehouse_id: uuid.UUID
    to_warehouse_id: uuid.UUID
    qty: int = Field(..., gt=0)
    reason: str = Field(min_length=1, max_length=255)

    @field_validator("to_warehouse_id")
    @classmethod
    def warehouses_differ(
        cls, v: uuid.UUID, info: object
    ) -> uuid.UUID:
        """
        Validate that source and destination warehouses differ.

        :param v: Destination warehouse UUID
        :param info: Pydantic validation info
        :return: Validated destination UUID
        :raises ValueError: If warehouses are the same
        """
        from_id = getattr(info, "data", {}).get(
            "from_warehouse_id"
        )
        if from_id is not None and v == from_id:
            raise ValueError(
                "from_warehouse_id and to_warehouse_id must differ"
            )
        return v


class CountRequest(BaseModel):
    """
    Request body for a physical stock count (sets absolute qty).

    :ivar warehouse_id: Target warehouse UUID
    :ivar product_id: Target product UUID
    :ivar counted_qty: Actual counted quantity (>= 0)
    :ivar notes: Optional count notes
    """

    warehouse_id: uuid.UUID
    product_id: uuid.UUID
    counted_qty: int = Field(..., ge=0)
    notes: str | None = Field(default=None, max_length=500)


class AlertResponse(BaseModel):
    """
    Low-stock or out-of-stock alert entry.

    :ivar product_id: Product UUID
    :ivar product_name: Product display name
    :ivar product_sku: Product SKU
    :ivar warehouse_id: Warehouse UUID
    :ivar warehouse_name: Warehouse display name
    :ivar qty_on_hand: Current stock level
    :ivar reorder_point: Configured threshold
    :ivar stock_status: low or out
    """

    product_id: uuid.UUID
    product_name: str
    product_sku: str
    warehouse_id: uuid.UUID
    warehouse_name: str
    qty_on_hand: int
    reorder_point: int
    stock_status: Literal["low", "out"]
