import enum
import uuid
from datetime import datetime

from sqlalchemy import JSON, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, uuid_pk


class AccessRequestStatus(enum.StrEnum):
    pending = "pending"
    approved = "approved"
    denied = "denied"
    expired = "expired"


class GrantScope(enum.StrEnum):
    full = "full"
    critical = "critical"


class GrantSource(enum.StrEnum):
    consent = "consent"
    break_glass = "break_glass"


class AuditAction(enum.StrEnum):
    request = "request"
    grant = "grant"
    deny = "deny"
    view = "view"
    break_glass = "break_glass"
    revoke = "revoke"
    end = "end"


class AccessRequest(Base, TimestampMixin):
    __tablename__ = "access_requests"

    id: Mapped[uuid.UUID] = uuid_pk()
    doctor_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("doctors.id", ondelete="CASCADE"), index=True, nullable=False
    )
    patient_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("patients.id", ondelete="CASCADE"), index=True, nullable=False
    )
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, default=AccessRequestStatus.pending.value
    )
    decided_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class AccessGrant(Base, TimestampMixin):
    __tablename__ = "access_grants"

    id: Mapped[uuid.UUID] = uuid_pk()
    request_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("access_requests.id", ondelete="SET NULL")
    )
    doctor_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("doctors.id", ondelete="CASCADE"), index=True, nullable=False
    )
    patient_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("patients.id", ondelete="CASCADE"), index=True, nullable=False
    )
    scope: Mapped[str] = mapped_column(String(16), nullable=False, default=GrantScope.full.value)
    source: Mapped[str] = mapped_column(
        String(16), nullable=False, default=GrantSource.consent.value
    )
    reason: Mapped[str | None] = mapped_column(String(500))
    granted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class AuditLog(Base, TimestampMixin):
    __tablename__ = "audit_log"

    id: Mapped[uuid.UUID] = uuid_pk()
    patient_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("patients.id", ondelete="CASCADE"), index=True, nullable=False
    )
    actor_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL")
    )
    actor_role: Mapped[str] = mapped_column(String(16), nullable=False)
    doctor_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("doctors.id", ondelete="SET NULL")
    )
    action: Mapped[str] = mapped_column(String(16), nullable=False)
    scope: Mapped[str | None] = mapped_column(String(16))
    at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    meta: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
