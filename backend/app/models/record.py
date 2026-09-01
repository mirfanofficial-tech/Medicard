import enum
import uuid
from datetime import date, datetime

from sqlalchemy import JSON, Boolean, Date, DateTime, ForeignKey, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, uuid_pk


class RecordType(enum.StrEnum):
    prescription = "prescription"
    lab = "lab"
    imaging = "imaging"
    note = "note"


class ExtractionStatus(enum.StrEnum):
    running = "running"
    needs_review = "needs_review"
    confirmed = "confirmed"
    failed = "failed"


class Record(Base, TimestampMixin):
    __tablename__ = "records"

    id: Mapped[uuid.UUID] = uuid_pk()
    patient_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("patients.id", ondelete="CASCADE"), index=True, nullable=False
    )
    type: Mapped[str] = mapped_column(String(16), nullable=False, default=RecordType.note.value)
    doc_date: Mapped[date | None] = mapped_column(Date)
    provider: Mapped[str | None] = mapped_column(String(200))
    # {diagnoses[], medications[], lab_results[], allergies[], notes}
    data: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    source_object_key: Mapped[str | None] = mapped_column(String(300))

    verified: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    verified_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL")
    )
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    sensitive: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    # Points at the latest ExtractionJob; no FK to avoid a records<->jobs cycle.
    extraction_job_id: Mapped[uuid.UUID | None] = mapped_column(Uuid)


class ExtractionJob(Base, TimestampMixin):
    __tablename__ = "extraction_jobs"

    id: Mapped[uuid.UUID] = uuid_pk()
    patient_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("patients.id", ondelete="CASCADE"), index=True, nullable=False
    )
    record_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("records.id", ondelete="CASCADE"), index=True, nullable=False
    )
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, default=ExtractionStatus.running.value
    )
    raw_model_output: Mapped[dict | None] = mapped_column(JSON)
    confidence_by_field: Mapped[dict | None] = mapped_column(JSON)
    error: Mapped[str | None] = mapped_column(String(500))
