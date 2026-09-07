from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models import (
    AccessGrant,
    AccessRequest,
    AccessRequestStatus,
    AuditAction,
    AuditLog,
    Doctor,
    GrantScope,
    GrantSource,
    Patient,
    Record,
)
from app.services.medicard_code import normalise

_settings = get_settings()


def _now() -> datetime:
    return datetime.now(UTC)


def _aware(dt: datetime) -> datetime:
    return dt if dt.tzinfo else dt.replace(tzinfo=UTC)


# public aliases for callers that need the same clock / tz handling
utcnow = _now
as_aware = _aware


async def log(
    session: AsyncSession,
    *,
    patient_id: uuid.UUID,
    actor_id: uuid.UUID | None,
    actor_role: str,
    action: str,
    doctor_id: uuid.UUID | None = None,
    scope: str | None = None,
    meta: dict | None = None,
) -> None:
    session.add(
        AuditLog(
            patient_id=patient_id,
            actor_id=actor_id,
            actor_role=actor_role,
            doctor_id=doctor_id,
            action=action,
            scope=scope,
            at=_now(),
            meta=meta or {},
        )
    )


async def patient_by_code(session: AsyncSession, code: str) -> Patient:
    patient = (
        await session.execute(
            select(Patient).where(Patient.medicard_code == normalise(code))
        )
    ).scalar_one_or_none()
    if patient is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No MediCard matches that code")
    return patient


async def create_request(
    session: AsyncSession, doctor: Doctor, code: str
) -> tuple[AccessRequest, Patient]:
    patient = await patient_by_code(session, code)

    existing = (
        await session.execute(
            select(AccessRequest).where(
                AccessRequest.doctor_id == doctor.id,
                AccessRequest.patient_id == patient.id,
                AccessRequest.status == AccessRequestStatus.pending.value,
            )
        )
    ).scalar_one_or_none()
    if existing is not None:
        return existing, patient

    req = AccessRequest(
        doctor_id=doctor.id,
        patient_id=patient.id,
        status=AccessRequestStatus.pending.value,
    )
    session.add(req)
    await log(
        session,
        patient_id=patient.id,
        actor_id=None,
        actor_role="doctor",
        doctor_id=doctor.id,
        action=AuditAction.request.value,
        meta={"doctor_name": doctor.name, "hospital": doctor.hospital},
    )
    await session.flush()
    return req, patient


async def approve_request(
    session: AsyncSession, request: AccessRequest, approver_user_id: uuid.UUID
) -> AccessGrant:
    if request.status != AccessRequestStatus.pending.value:
        raise HTTPException(status.HTTP_409_CONFLICT, "This request was already decided")
    request.status = AccessRequestStatus.approved.value
    request.decided_at = _now()

    grant = AccessGrant(
        request_id=request.id,
        doctor_id=request.doctor_id,
        patient_id=request.patient_id,
        scope=GrantScope.full.value,
        source=GrantSource.consent.value,
        granted_at=_now(),
        expires_at=_now() + timedelta(hours=_settings.grant_ttl_hours),
    )
    session.add(grant)
    await log(
        session,
        patient_id=request.patient_id,
        actor_id=approver_user_id,
        actor_role="patient",
        doctor_id=request.doctor_id,
        action=AuditAction.grant.value,
        scope=GrantScope.full.value,
        meta={"expires_at": grant.expires_at.isoformat()},
    )
    await session.flush()
    return grant


async def deny_request(
    session: AsyncSession, request: AccessRequest, actor_user_id: uuid.UUID
) -> None:
    if request.status != AccessRequestStatus.pending.value:
        raise HTTPException(status.HTTP_409_CONFLICT, "This request was already decided")
    request.status = AccessRequestStatus.denied.value
    request.decided_at = _now()
    await log(
        session,
        patient_id=request.patient_id,
        actor_id=actor_user_id,
        actor_role="patient",
        doctor_id=request.doctor_id,
        action=AuditAction.deny.value,
    )
    await session.flush()


async def break_glass(
    session: AsyncSession, doctor: Doctor, code: str, reason: str
) -> tuple[AccessGrant, Patient]:
    if not reason or len(reason.strip()) < 4:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, "A reason is required for emergency access"
        )
    patient = await patient_by_code(session, code)
    grant = AccessGrant(
        request_id=None,
        doctor_id=doctor.id,
        patient_id=patient.id,
        scope=GrantScope.critical.value,
        source=GrantSource.break_glass.value,
        reason=reason.strip(),
        granted_at=_now(),
        expires_at=_now() + timedelta(minutes=_settings.break_glass_ttl_minutes),
    )
    session.add(grant)
    await log(
        session,
        patient_id=patient.id,
        actor_id=None,
        actor_role="doctor",
        doctor_id=doctor.id,
        action=AuditAction.break_glass.value,
        scope=GrantScope.critical.value,
        meta={"reason": reason.strip(), "doctor_name": doctor.name, "hospital": doctor.hospital},
    )
    await session.flush()
    return grant, patient


async def active_grant(
    session: AsyncSession, doctor_id: uuid.UUID, patient_id: uuid.UUID
) -> AccessGrant | None:
    rows = (
        await session.execute(
            select(AccessGrant)
            .where(
                AccessGrant.doctor_id == doctor_id,
                AccessGrant.patient_id == patient_id,
                AccessGrant.ended_at.is_(None),
            )
            .order_by(AccessGrant.granted_at.desc())
        )
    ).scalars().all()
    for g in rows:
        if _aware(g.expires_at) > _now():
            return g
    return None


async def require_grant(
    session: AsyncSession, doctor_id: uuid.UUID, patient_id: uuid.UUID, *, need_full: bool
) -> AccessGrant:
    grant = await active_grant(session, doctor_id, patient_id)
    if grant is None:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            "No active access. Ask the patient to approve your request, or use emergency access.",
        )
    if need_full and grant.scope != GrantScope.full.value:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            "Emergency access is limited to critical information only.",
        )
    return grant


async def end_grant(
    session: AsyncSession, grant: AccessGrant, actor_user_id: uuid.UUID, actor_role: str
) -> None:
    if grant.ended_at is not None:
        return
    grant.ended_at = _now()
    await log(
        session,
        patient_id=grant.patient_id,
        actor_id=actor_user_id,
        actor_role=actor_role,
        doctor_id=grant.doctor_id,
        action=AuditAction.revoke.value if actor_role == "patient" else AuditAction.end.value,
        scope=grant.scope,
    )
    await session.flush()


def critical_summary(records: list[Record]) -> dict:
    """Union of the life-threatening essentials across a patient's verified records."""
    allergies: set[str] = set()
    medications: list[dict] = []
    conditions: set[str] = set()
    seen_meds: set[str] = set()
    for r in records:
        data = r.data or {}
        for a in data.get("allergies", []) or []:
            allergies.add(str(a))
        for d in data.get("diagnoses", []) or []:
            conditions.add(str(d))
        if r.type == "prescription":
            for m in data.get("medications", []) or []:
                key = f"{m.get('name')}|{m.get('dose')}"
                if key not in seen_meds:
                    seen_meds.add(key)
                    medications.append(m)
    return {
        "allergies": sorted(allergies),
        "current_medications": medications,
        "conditions": sorted(conditions),
        "note": "Emergency view — critical fields only, aggregated from confirmed records.",
    }
