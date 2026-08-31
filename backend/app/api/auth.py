import uuid

import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.core.deps import Principal, get_principal
from app.core.security import (
    REFRESH,
    create_access_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.db import get_session
from app.models import Doctor, Patient, User, UserRole
from app.schemas.auth import (
    AccessTokenResult,
    DoctorAuthResult,
    DoctorLogin,
    DoctorRegister,
    MeResult,
    OtpRequest,
    OtpRequestResult,
    PatientAuthResult,
    PatientOtpVerify,
    PatientRecoverResult,
    PatientRecoverVerify,
    RefreshRequest,
)
from app.services import auth as auth_svc
from app.services.otp import issue_otp, verify_otp

router = APIRouter(prefix="/auth", tags=["auth"])
_settings = get_settings()
_dev = _settings.env == "dev"


@router.post("/patient/otp/request", response_model=OtpRequestResult)
async def patient_otp_request(
    body: OtpRequest, session: AsyncSession = Depends(get_session)
) -> OtpRequestResult:
    code = await issue_otp(session, body.phone, "login")
    await session.commit()
    return OtpRequestResult(dev_code=code if _dev else None)


@router.post("/patient/otp/verify", response_model=PatientAuthResult)
async def patient_otp_verify(
    body: PatientOtpVerify, session: AsyncSession = Depends(get_session)
) -> PatientAuthResult:
    await verify_otp(session, body.phone, body.code, "login")
    tokens, patient, is_new = await auth_svc.patient_login_or_register(
        session, phone=body.phone, name=body.name, dob=body.dob, cnic=body.cnic
    )
    await session.commit()
    return PatientAuthResult(
        tokens=tokens,
        patient_id=str(patient.id),
        medicard_code=patient.medicard_code,
        is_new=is_new,
    )


@router.post("/patient/recover/request", response_model=OtpRequestResult)
async def patient_recover_request(
    body: OtpRequest, session: AsyncSession = Depends(get_session)
) -> OtpRequestResult:
    code = await issue_otp(session, body.phone, "recover")
    await session.commit()
    return OtpRequestResult(dev_code=code if _dev else None)


@router.post("/patient/recover/verify", response_model=PatientRecoverResult)
async def patient_recover_verify(
    body: PatientRecoverVerify, session: AsyncSession = Depends(get_session)
) -> PatientRecoverResult:
    await verify_otp(session, body.phone, body.code, "recover")
    tokens, patient = await auth_svc.patient_recover(session, phone=body.phone, cnic=body.cnic)
    await session.commit()
    return PatientRecoverResult(
        tokens=tokens, patient_id=str(patient.id), medicard_code=patient.medicard_code
    )


@router.post(
    "/doctor/register",
    response_model=DoctorAuthResult,
    status_code=status.HTTP_201_CREATED,
)
async def doctor_register(
    body: DoctorRegister, session: AsyncSession = Depends(get_session)
) -> DoctorAuthResult:
    tokens, doctor = await auth_svc.doctor_register(
        session,
        name=body.name,
        email=body.email,
        password_hash=hash_password(body.password),
        licence_no=body.licence_no,
        specialty=body.specialty,
        hospital=body.hospital,
    )
    await session.commit()
    return DoctorAuthResult(tokens=tokens, doctor_id=str(doctor.id), status=doctor.status)


@router.post("/doctor/login", response_model=DoctorAuthResult)
async def doctor_login(
    body: DoctorLogin, session: AsyncSession = Depends(get_session)
) -> DoctorAuthResult:
    doctor = (
        await session.execute(select(Doctor).where(Doctor.email == body.email.lower()))
    ).scalar_one_or_none()
    if doctor is None or not verify_password(body.password, doctor.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Wrong email or password")
    user = await session.get(User, doctor.user_id)
    return DoctorAuthResult(
        tokens=auth_svc.tokens_for(user), doctor_id=str(doctor.id), status=doctor.status
    )


@router.post("/refresh", response_model=AccessTokenResult)
async def refresh(
    body: RefreshRequest, session: AsyncSession = Depends(get_session)
) -> AccessTokenResult:
    try:
        payload = decode_token(body.refresh_token)
    except jwt.PyJWTError as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid refresh token") from exc
    if payload.get("type") != REFRESH:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Not a refresh token")
    user = await session.get(User, uuid.UUID(payload["sub"]))
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Unknown user")
    return AccessTokenResult(access_token=create_access_token(str(user.id), user.role))


@router.get("/me", response_model=MeResult)
async def me(
    principal: Principal = Depends(get_principal),
    session: AsyncSession = Depends(get_session),
) -> MeResult:
    profile: dict = {}
    if principal.role == UserRole.patient.value:
        patient = (
            await session.execute(
                select(Patient).where(
                    Patient.user_id == principal.user_id,
                    Patient.guardian_patient_id.is_(None),
                )
            )
        ).scalar_one_or_none()
        if patient is not None:
            profile = {
                "patient_id": str(patient.id),
                "name": patient.name,
                "medicard_code": patient.medicard_code,
                "phone": patient.phone,
            }
    else:
        doctor = (
            await session.execute(select(Doctor).where(Doctor.user_id == principal.user_id))
        ).scalar_one_or_none()
        if doctor is not None:
            profile = {
                "doctor_id": str(doctor.id),
                "name": doctor.name,
                "email": doctor.email,
                "status": doctor.status,
                "specialty": doctor.specialty,
                "hospital": doctor.hospital,
            }
    return MeResult(user_id=str(principal.user_id), role=principal.role, profile=profile)
