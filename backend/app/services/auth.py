from datetime import date

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import (
    create_access_token,
    create_refresh_token,
    hmac_sha256,
)
from app.models import Doctor, DoctorStatus, Patient, User, UserRole
from app.schemas.auth import TokenPair
from app.services.medicard_code import generate_unique_code


def tokens_for(user: User) -> TokenPair:
    return TokenPair(
        access_token=create_access_token(str(user.id), user.role),
        refresh_token=create_refresh_token(str(user.id)),
    )


async def patient_login_or_register(
    session: AsyncSession,
    *,
    phone: str,
    name: str | None,
    dob: date | None,
    cnic: str | None,
) -> tuple[TokenPair, Patient, bool]:
    patient = (
        await session.execute(
            select(Patient).where(Patient.phone == phone, Patient.guardian_patient_id.is_(None))
        )
    ).scalar_one_or_none()

    if patient is not None:
        user = await session.get(User, patient.user_id)
        return tokens_for(user), patient, False

    user = User(role=UserRole.patient.value)
    session.add(user)
    await session.flush()

    patient = Patient(
        user_id=user.id,
        name=(name or "Unnamed patient").strip(),
        dob=dob,
        phone=phone,
        cnic_hash=hmac_sha256(cnic) if cnic else None,
        medicard_code=await generate_unique_code(session),
    )
    session.add(patient)
    await session.flush()
    return tokens_for(user), patient, True


async def patient_recover(
    session: AsyncSession, *, phone: str, cnic: str | None
) -> tuple[TokenPair, Patient]:
    """OTP already verified by the caller. Reissue the code on the SAME profile."""
    patient = (
        await session.execute(
            select(Patient).where(Patient.phone == phone, Patient.guardian_patient_id.is_(None))
        )
    ).scalar_one_or_none()
    if patient is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No MediCard is registered to that number")

    if patient.cnic_hash and cnic and patient.cnic_hash != hmac_sha256(cnic):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "CNIC does not match our records")

    patient.medicard_code = await generate_unique_code(session)
    await session.flush()
    user = await session.get(User, patient.user_id)
    return tokens_for(user), patient


async def doctor_register(
    session: AsyncSession,
    *,
    name: str,
    email: str,
    password_hash: str,
    licence_no: str,
    specialty: str | None,
    hospital: str | None,
) -> tuple[TokenPair, Doctor]:
    existing = (
        await session.execute(select(Doctor.id).where(Doctor.email == email.lower()))
    ).first()
    if existing is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "An account with that email already exists")

    user = User(role=UserRole.doctor.value)
    session.add(user)
    await session.flush()

    doctor = Doctor(
        user_id=user.id,
        name=name.strip(),
        email=email.lower(),
        password_hash=password_hash,
        licence_no=licence_no.strip(),
        specialty=specialty,
        hospital=hospital,
        status=DoctorStatus.pending_verification.value,
    )
    session.add(doctor)
    await session.flush()
    return tokens_for(user), doctor
