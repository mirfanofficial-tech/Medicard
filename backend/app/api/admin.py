import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import require_admin
from app.db import get_session
from app.models import Doctor, DoctorStatus
from app.schemas.admin import DoctorDecision, DoctorReviewRow

router = APIRouter(prefix="/admin", tags=["admin"], dependencies=[Depends(require_admin)])


@router.get("/doctors", response_model=list[DoctorReviewRow])
async def list_doctors(
    status_filter: str = DoctorStatus.pending_verification.value,
    session: AsyncSession = Depends(get_session),
) -> list[DoctorReviewRow]:
    rows = (
        await session.execute(
            select(Doctor).where(Doctor.status == status_filter).order_by(Doctor.created_at)
        )
    ).scalars().all()
    return [
        DoctorReviewRow(
            doctor_id=str(d.id),
            name=d.name,
            email=d.email,
            licence_no=d.licence_no,
            specialty=d.specialty,
            hospital=d.hospital,
            status=d.status,
            registered_at=d.created_at,
        )
        for d in rows
    ]


@router.post("/doctors/{doctor_id}/review", response_model=DoctorReviewRow)
async def review_doctor(
    doctor_id: str,
    body: DoctorDecision,
    session: AsyncSession = Depends(get_session),
) -> DoctorReviewRow:
    try:
        pk = uuid.UUID(doctor_id)
    except ValueError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Doctor not found") from exc
    doctor = await session.get(Doctor, pk)
    if doctor is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Doctor not found")
    doctor.status = (
        DoctorStatus.active.value if body.decision == "active" else DoctorStatus.rejected.value
    )
    doctor.reviewed_at = datetime.now(UTC)
    doctor.reviewed_note = body.note
    await session.commit()
    return DoctorReviewRow(
        doctor_id=str(doctor.id),
        name=doctor.name,
        email=doctor.email,
        licence_no=doctor.licence_no,
        specialty=doctor.specialty,
        hospital=doctor.hospital,
        status=doctor.status,
        registered_at=doctor.created_at,
    )
