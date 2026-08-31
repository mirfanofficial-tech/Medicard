import uuid
from dataclasses import dataclass

import jwt
from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.core.security import ACCESS, decode_token
from app.db import get_session
from app.models import Doctor, DoctorStatus, User, UserRole

_bearer = HTTPBearer(auto_error=True)
_settings = get_settings()


@dataclass
class Principal:
    user_id: uuid.UUID
    role: str


async def get_principal(
    creds: HTTPAuthorizationCredentials = Depends(_bearer),
) -> Principal:
    try:
        payload = decode_token(creds.credentials)
    except jwt.PyJWTError as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid token") from exc
    if payload.get("type") != ACCESS:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Wrong token type")
    return Principal(user_id=uuid.UUID(payload["sub"]), role=payload["role"])


async def require_patient(principal: Principal = Depends(get_principal)) -> Principal:
    if principal.role != UserRole.patient.value:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Patient role required")
    return principal


async def require_doctor(principal: Principal = Depends(get_principal)) -> Principal:
    if principal.role != UserRole.doctor.value:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Doctor role required")
    return principal


async def require_active_doctor(
    principal: Principal = Depends(require_doctor),
    session: AsyncSession = Depends(get_session),
) -> Doctor:
    doctor = (
        await session.execute(select(Doctor).where(Doctor.user_id == principal.user_id))
    ).scalar_one_or_none()
    if doctor is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Doctor profile missing")
    if doctor.status != DoctorStatus.active.value:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            "Your account is not verified yet. A reviewer must approve it before you can "
            "search patient records.",
        )
    return doctor


async def current_user(
    principal: Principal = Depends(get_principal),
    session: AsyncSession = Depends(get_session),
) -> User:
    user = await session.get(User, principal.user_id)
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Unknown user")
    return user


def require_admin(x_admin_key: str = Header(default="")) -> None:
    if not x_admin_key or x_admin_key != _settings.admin_api_key:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Admin key required")
