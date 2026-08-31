"""SQLAlchemy models. Import every model here so Alembic autogenerate sees them."""

from app.models.base import Base

__all__ = ["Base"]
