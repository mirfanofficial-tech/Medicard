import uuid

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Patient


async def self_patient(session: AsyncSession, user_id: uuid.UUID) -> Patient:
    patient = (
        await session.execute(
            select(Patient).where(
                Patient.user_id == user_id, Patient.guardian_patient_id.is_(None)
            )
        )
    ).scalar_one_or_none()
    if patient is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Patient profile missing")
    return patient


async def resolve_patient(
    session: AsyncSession, user_id: uuid.UUID, patient_id: str | None
) -> Patient:
    """The signed-in patient, or one of their guardian-managed minors."""
    me = await self_patient(session, user_id)
    if patient_id is None or patient_id == str(me.id):
        return me
    try:
        pk = uuid.UUID(patient_id)
    except ValueError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unknown patient") from exc
    minor = await session.get(Patient, pk)
    if minor is None or minor.guardian_patient_id != me.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your profile")
    return minor
