"""Pydantic schemas for sales request/response models."""

import uuid
from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator


class SaleLineItemCreate(BaseModel):
    """
    One product line in a sale creation request.

    :ivar product_id: Product UUID
    :ivar qty: Units to sell (>= 1)
    :ivar unit_price: Override price; if omitted backend uses
        catalogue price
    """

    product_id: uuid.UUID
    qty: int = Field(..., ge=1)
    unit_price: float | None = Field(default=None, gt=0)


class SaleCreate(BaseModel):
    """
    Request body for creating a new sale.

    :ivar warehouse_id: Source warehouse for stock deduction
    :ivar line_items: One or more product lines
    :ivar payment_method: cash | card | mobile
    :ivar amount_tendered: Amount given by the customer
    :ivar discount: Optional transaction-level discount (>= 0)
    :ivar device_id: Client device identifier
    :ivar reference: Optional payment reference (card / mobile)
    """

    warehouse_id: uuid.UUID
    line_items: list[SaleLineItemCreate] = Field(min_length=1)
    payment_method: Literal["cash", "card", "mobile"]
    amount_tendered: float = Field(..., gt=0)
    discount: float = Field(default=0.0, ge=0)
    device_id: str = Field(default="web", max_length=100)
    reference: str | None = Field(default=None, max_length=100)

    @field_validator("line_items")
    @classmethod
    def no_duplicate_products(
        cls, v: list[SaleLineItemCreate],
    ) -> list[SaleLineItemCreate]:
        """
        Validate that each product appears at most once.

        :param v: Line items list
        :return: Validated line items
        :raises ValueError: If any product_id is duplicated
        """
        ids = [item.product_id for item in v]
        if len(ids) != len(set(ids)):
            raise ValueError(
                "Each product may appear only once per sale"
            )
        return v


class SaleLineItemResponse(BaseModel):
    """
    One product line in a sale response.

    :ivar id: Line item UUID
    :ivar product_id: Product UUID (nullable if product deleted)
    :ivar product_name: Snapshot name at time of sale
    :ivar qty: Units sold
    :ivar unit_price: Price per unit at time of sale
    :ivar tax_rate: Tax rate applied
    :ivar line_total: qty * unit_price
    :ivar line_tax: Tax amount for this line
    """

    id: uuid.UUID
    product_id: uuid.UUID | None
    product_name: str
    qty: int
    unit_price: float
    tax_rate: float
    line_total: float
    line_tax: float


class PaymentResponse(BaseModel):
    """
    Payment record attached to a sale.

    :ivar id: Payment UUID
    :ivar method: cash | card | mobile
    :ivar amount_tendered: Amount given by the customer
    :ivar change_given: Change returned
    :ivar reference: Optional terminal reference
    :ivar paid_at: Payment timestamp
    """

    id: uuid.UUID
    method: str
    amount_tendered: float
    change_given: float
    reference: str | None
    paid_at: datetime


class SaleResponse(BaseModel):
    """
    Full sale response including line items and payment.

    :ivar id: Transaction UUID
    :ivar invoice_number: Human-readable invoice number
    :ivar salesman_id: Staff UUID who made the sale
    :ivar salesman_name: Resolved staff name
    :ivar warehouse_id: Source warehouse UUID
    :ivar warehouse_name: Resolved warehouse name
    :ivar subtotal: Sum of line totals before tax/discount
    :ivar tax_total: Total tax
    :ivar discount: Transaction-level discount
    :ivar grand_total: Final amount charged
    :ivar status: completed | voided
    :ivar line_items: Individual product lines
    :ivar payment: Payment record
    :ivar created_at: Sale timestamp
    """

    id: uuid.UUID
    invoice_number: str
    salesman_id: uuid.UUID | None
    salesman_name: str | None
    warehouse_id: uuid.UUID | None
    warehouse_name: str | None
    subtotal: float
    tax_total: float
    discount: float
    grand_total: float
    status: str
    line_items: list[SaleLineItemResponse]
    payment: PaymentResponse | None
    created_at: datetime


class SaleListItem(BaseModel):
    """
    Compact sale entry for list responses.

    :ivar id: Transaction UUID
    :ivar invoice_number: Human-readable invoice number
    :ivar salesman_name: Resolved staff name
    :ivar warehouse_name: Resolved warehouse name
    :ivar grand_total: Final amount charged
    :ivar status: completed | voided
    :ivar item_count: Number of distinct product lines
    :ivar created_at: Sale timestamp
    """

    id: uuid.UUID
    invoice_number: str
    salesman_name: str | None
    warehouse_name: str | None
    grand_total: float
    status: str
    item_count: int
    created_at: datetime


class SaleListResponse(BaseModel):
    """
    Paginated sales list.

    :ivar items: Sales on the current page
    :ivar total: Total matching sales
    :ivar page: Current page (1-based)
    :ivar page_size: Items per page
    """

    items: list[SaleListItem]
    total: int
    page: int
    page_size: int


class TopProduct(BaseModel):
    """
    Top-selling product entry in the summary.

    :ivar product_id: Product UUID
    :ivar product_name: Product display name
    :ivar qty_sold: Total units sold
    :ivar revenue: Total revenue from this product
    """

    product_id: uuid.UUID | None
    product_name: str
    qty_sold: int
    revenue: float


class SalesSummary(BaseModel):
    """
    Aggregated sales summary for a date range.

    :ivar date_from: Start of range (inclusive)
    :ivar date_to: End of range (inclusive)
    :ivar total_sales: Number of completed transactions
    :ivar total_revenue: Sum of grand_totals for completed sales
    :ivar total_tax: Sum of tax_totals for completed sales
    :ivar total_discount: Sum of discounts for completed sales
    :ivar voided_count: Number of voided transactions
    :ivar top_products: Up to 5 best-selling products by qty
    """

    date_from: datetime
    date_to: datetime
    total_sales: int
    total_revenue: float
    total_tax: float
    total_discount: float
    voided_count: int
    top_products: list[TopProduct]
