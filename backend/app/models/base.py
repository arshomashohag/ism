"""Declarative base for all SQLAlchemy models."""

from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    """
    Shared declarative base for all ORM models.

    All models inherit from this class so that
    ``Base.metadata`` collects every table definition.
    """
