import uuid
from datetime import date

from sqlalchemy import Date, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, uuid_pk


class Patient(Base, TimestampMixin):
    __tablename__ = "patients"

    id: Mapped[uuid.UUID] = uuid_pk()
    # Null for guardian-managed minor profiles (they have no login of their own).
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    dob: Mapped[date | None] = mapped_column(Date)
    phone: Mapped[str | None] = mapped_column(String(32), index=True)
    cnic_hash: Mapped[str | None] = mapped_column(String(64))
    gender: Mapped[str | None] = mapped_column(String(16))
    blood_group: Mapped[str | None] = mapped_column(String(8))
    address: Mapped[str | None] = mapped_column(String(300))
    medicard_code: Mapped[str] = mapped_column(String(16), unique=True, index=True, nullable=False)
    guardian_patient_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("patients.id", ondelete="SET NULL"), index=True
    )
