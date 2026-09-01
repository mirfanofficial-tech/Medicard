import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import require_active_doctor
from app.db import get_session
from app.models import (
    AccessGrant,
    AccessRequest,
    AuditAction,
    Doctor,
    Patient,
    Record,
)
from app.schemas.access import (
    AccessRequestCreate,
    AccessRequestView,
    BreakGlassCreate,
    CriticalView,
    DoctorGrantView,
    GrantView,
)
from app.schemas.ai import AiAnswer, AiAskRequest, AiSummary
from app.schemas.prescribe import (
    RxCandidate,
    RxCheck,
    RxCheckRequest,
    RxCheckResult,
    RxContext,
    RxCreateRequest,
    RxCreateResult,
)
from app.schemas.record import RecordData, RecordDetail, RecordSummary
from app.services import access as acc
from app.services import ai_summary as ai
from app.services import prescribe as rx
from app.services.notify import notify_patient

router = APIRouter(prefix="/doctor", tags=["doctor"])


def _grant_view(grant, doctor: Doctor) -> GrantView:
    return GrantView(
        grant_id=str(grant.id),
        doctor_name=doctor.name,
        hospital=doctor.hospital,
        scope=grant.scope,
        source=grant.source,
        granted_at=grant.granted_at,
        expires_at=grant.expires_at,
        ended_at=grant.ended_at,
    )


@router.post("/access-requests", response_model=AccessRequestView, status_code=201)
async def create_access_request(
    body: AccessRequestCreate,
    doctor: Doctor = Depends(require_active_doctor),
    session: AsyncSession = Depends(get_session),
) -> AccessRequestView:
    req, patient = await acc.create_request(session, doctor, body.medicard_code)
    await session.commit()
    await notify_patient(
        str(patient.id),
        "Access request",
        f"Dr {doctor.name}"
        + (f" at {doctor.hospital}" if doctor.hospital else "")
        + " wants to view this MediCard.",
    )
    return AccessRequestView(
        request_id=str(req.id),
        patient_name=patient.name.split(" ")[0],
        status=req.status,
        created_at=req.created_at,
    )


@router.get("/access-requests", response_model=list[AccessRequestView])
async def my_access_requests(
    doctor: Doctor = Depends(require_active_doctor),
    session: AsyncSession = Depends(get_session),
) -> list[AccessRequestView]:
    rows = (
        await session.execute(
            select(AccessRequest, Patient)
            .join(Patient, Patient.id == AccessRequest.patient_id)
            .where(AccessRequest.doctor_id == doctor.id)
            .order_by(AccessRequest.created_at.desc())
        )
    ).all()
    return [
        AccessRequestView(
            request_id=str(r.id),
            patient_name=p.name.split(" ")[0],
            status=r.status,
            created_at=r.created_at,
        )
        for r, p in rows
    ]


@router.get("/grants", response_model=list[DoctorGrantView])
async def my_active_grants(
    doctor: Doctor = Depends(require_active_doctor),
    session: AsyncSession = Depends(get_session),
) -> list[DoctorGrantView]:
    rows = (
        await session.execute(
            select(AccessGrant, Patient)
            .join(Patient, Patient.id == AccessGrant.patient_id)
            .where(AccessGrant.doctor_id == doctor.id, AccessGrant.ended_at.is_(None))
            .order_by(AccessGrant.granted_at.desc())
        )
    ).all()
    now = acc.utcnow()
    return [
        DoctorGrantView(
            grant_id=str(g.id),
            patient_id=str(p.id),
            patient_name=p.name,
            scope=g.scope,
            source=g.source,
            granted_at=g.granted_at,
            expires_at=g.expires_at,
        )
        for g, p in rows
        if acc.as_aware(g.expires_at) > now
    ]


@router.post("/break-glass", response_model=CriticalView, status_code=201)
async def break_glass(
    body: BreakGlassCreate,
    doctor: Doctor = Depends(require_active_doctor),
    session: AsyncSession = Depends(get_session),
) -> CriticalView:
    grant, patient = await acc.break_glass(session, doctor, body.medicard_code, body.reason)
    await session.commit()
    await notify_patient(
        str(patient.id),
        "Emergency access used",
        f"Dr {doctor.name} opened emergency (critical-only) access to your MediCard. "
        f"Reason: {body.reason.strip()}",
    )
    return await _critical_response(session, doctor, patient, grant)


async def _load_patient(session: AsyncSession, patient_id: str) -> Patient:
    try:
        pk = uuid.UUID(patient_id)
    except ValueError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unknown patient") from exc
    patient = await session.get(Patient, pk)
    if patient is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unknown patient")
    return patient


async def _critical_response(
    session: AsyncSession, doctor: Doctor, patient: Patient, grant
) -> CriticalView:
    records = (
        await session.execute(
            select(Record).where(Record.patient_id == patient.id, Record.verified.is_(True))
        )
    ).scalars().all()
    summary = acc.critical_summary(list(records))
    return CriticalView(
        patient_name=patient.name,
        allergies=summary["allergies"],
        current_medications=summary["current_medications"],
        conditions=summary["conditions"],
        note=summary["note"],
        grant=_grant_view(grant, doctor),
    )


@router.get("/patients/{patient_id}/critical", response_model=CriticalView)
async def patient_critical(
    patient_id: str,
    doctor: Doctor = Depends(require_active_doctor),
    session: AsyncSession = Depends(get_session),
) -> CriticalView:
    patient = await _load_patient(session, patient_id)
    grant = await acc.require_grant(session, doctor.id, patient.id, need_full=False)
    await acc.log(
        session,
        patient_id=patient.id,
        actor_id=None,
        actor_role="doctor",
        doctor_id=doctor.id,
        action=AuditAction.view.value,
        scope=grant.scope,
        meta={"view": "critical"},
    )
    await session.commit()
    return await _critical_response(session, doctor, patient, grant)


@router.get("/patients/{patient_id}/records", response_model=list[RecordSummary])
async def patient_records(
    patient_id: str,
    doctor: Doctor = Depends(require_active_doctor),
    session: AsyncSession = Depends(get_session),
) -> list[RecordSummary]:
    patient = await _load_patient(session, patient_id)
    grant = await acc.require_grant(session, doctor.id, patient.id, need_full=True)
    rows = (
        await session.execute(
            select(Record)
            .where(Record.patient_id == patient.id, Record.sensitive.is_(False))
            .order_by(Record.doc_date.is_(None), Record.doc_date.desc(), Record.created_at.desc())
        )
    ).scalars().all()
    await acc.log(
        session,
        patient_id=patient.id,
        actor_id=None,
        actor_role="doctor",
        doctor_id=doctor.id,
        action=AuditAction.view.value,
        scope=grant.scope,
        meta={"view": "timeline", "count": len(rows)},
    )
    await session.commit()
    return [
        RecordSummary(
            record_id=str(r.id),
            type=r.type,
            doc_date=r.doc_date,
            provider=r.provider,
            verified=r.verified,
            sensitive=r.sensitive,
            created_at=r.created_at,
        )
        for r in rows
    ]


@router.get("/patients/{patient_id}/records/{record_id}", response_model=RecordDetail)
async def patient_record_detail(
    patient_id: str,
    record_id: str,
    doctor: Doctor = Depends(require_active_doctor),
    session: AsyncSession = Depends(get_session),
) -> RecordDetail:
    patient = await _load_patient(session, patient_id)
    grant = await acc.require_grant(session, doctor.id, patient.id, need_full=True)
    try:
        rid = uuid.UUID(record_id)
    except ValueError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Record not found") from exc
    record = await session.get(Record, rid)
    if record is None or record.patient_id != patient.id or record.sensitive:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Record not found")
    await acc.log(
        session,
        patient_id=patient.id,
        actor_id=None,
        actor_role="doctor",
        doctor_id=doctor.id,
        action=AuditAction.view.value,
        scope=grant.scope,
        meta={"view": "record", "record_id": record_id},
    )
    await session.commit()
    return RecordDetail(
        record_id=str(record.id),
        type=record.type,
        doc_date=record.doc_date,
        provider=record.provider,
        verified=record.verified,
        sensitive=record.sensitive,
        created_at=record.created_at,
        data=RecordData.model_validate(record.data or {}),
        source_url=None,
        extraction=None,
    )


async def _shared_records(session: AsyncSession, patient_id) -> list[Record]:
    return list(
        (
            await session.execute(
                select(Record)
                .where(Record.patient_id == patient_id, Record.sensitive.is_(False))
                .order_by(Record.doc_date.is_(None), Record.doc_date.desc())
            )
        ).scalars().all()
    )


@router.get("/patients/{patient_id}/ai-summary", response_model=AiSummary)
async def ai_summary(
    patient_id: str,
    doctor: Doctor = Depends(require_active_doctor),
    session: AsyncSession = Depends(get_session),
) -> AiSummary:
    patient = await _load_patient(session, patient_id)
    grant = await acc.require_grant(session, doctor.id, patient.id, need_full=True)
    records = await _shared_records(session, patient.id)
    result = await ai.summarize(records)
    await acc.log(
        session,
        patient_id=patient.id,
        actor_id=None,
        actor_role="doctor",
        doctor_id=doctor.id,
        action=AuditAction.view.value,
        scope=grant.scope,
        meta={"view": "ai_summary", "model": result["model"]},
    )
    await session.commit()
    return AiSummary(**result)


@router.post("/patients/{patient_id}/ai-ask", response_model=AiAnswer)
async def ai_ask(
    patient_id: str,
    body: AiAskRequest,
    doctor: Doctor = Depends(require_active_doctor),
    session: AsyncSession = Depends(get_session),
) -> AiAnswer:
    patient = await _load_patient(session, patient_id)
    grant = await acc.require_grant(session, doctor.id, patient.id, need_full=True)
    records = await _shared_records(session, patient.id)
    result = await ai.ask(records, body.question)
    await acc.log(
        session,
        patient_id=patient.id,
        actor_id=None,
        actor_role="doctor",
        doctor_id=doctor.id,
        action=AuditAction.view.value,
        scope=grant.scope,
        meta={"view": "ai_ask", "model": result["model"], "question": body.question[:200]},
    )
    await session.commit()
    return AiAnswer(**result)


@router.get("/patients/{patient_id}/prescribe/context", response_model=RxContext)
async def prescribe_context(
    patient_id: str,
    doctor: Doctor = Depends(require_active_doctor),
    session: AsyncSession = Depends(get_session),
) -> RxContext:
    patient = await _load_patient(session, patient_id)
    await acc.require_grant(session, doctor.id, patient.id, need_full=True)
    records = await _shared_records(session, patient.id)
    return RxContext(
        patient_name=patient.name,
        candidates=[RxCandidate(**c) for c in rx.current_medications(records)],
        known_allergies=rx.known_allergies(records),
    )


@router.post("/patients/{patient_id}/prescribe/check", response_model=RxCheckResult)
async def prescribe_check(
    patient_id: str,
    body: RxCheckRequest,
    doctor: Doctor = Depends(require_active_doctor),
    session: AsyncSession = Depends(get_session),
) -> RxCheckResult:
    patient = await _load_patient(session, patient_id)
    await acc.require_grant(session, doctor.id, patient.id, need_full=True)
    records = await _shared_records(session, patient.id)
    draft = [m.model_dump() for m in body.medications]
    return RxCheckResult(checks=[RxCheck(**c) for c in rx.check(records, draft)])


@router.post("/patients/{patient_id}/prescribe", response_model=RxCreateResult, status_code=201)
async def prescribe_create(
    patient_id: str,
    body: RxCreateRequest,
    doctor: Doctor = Depends(require_active_doctor),
    session: AsyncSession = Depends(get_session),
) -> RxCreateResult:
    patient = await _load_patient(session, patient_id)
    grant = await acc.require_grant(session, doctor.id, patient.id, need_full=True)
    records = await _shared_records(session, patient.id)

    # Guardrail: a line marked as coming from history must actually be in the record.
    documented = rx.candidate_names(records)
    for m in body.medications:
        if m.origin == "history" and m.name.strip().lower() not in documented:
            raise HTTPException(
                422,
                f"'{m.name}' is marked as from the patient's record but is not documented there.",
            )

    meds = [
        {"name": m.name, "dose": m.dose, "route": m.route, "freq": m.freq}
        for m in body.medications
    ]
    checks = rx.check(records, meds)

    record = Record(
        patient_id=patient.id,
        type="prescription",
        doc_date=body.doc_date or datetime.now(UTC).date(),
        provider=f"Dr {doctor.name}"
        + (f", {doctor.hospital}" if doctor.hospital else ""),
        data={
            "diagnoses": [],
            "medications": meds,
            "lab_results": [],
            "allergies": [],
            "notes": body.notes,
        },
        verified=True,
        verified_by=doctor.user_id,
        verified_at=datetime.now(UTC),
        authored_by_doctor_id=doctor.id,
    )
    session.add(record)
    await acc.log(
        session,
        patient_id=patient.id,
        actor_id=doctor.user_id,
        actor_role="doctor",
        doctor_id=doctor.id,
        action=AuditAction.prescribe.value,
        scope=grant.scope,
        meta={
            "lines": len(meds),
            "from_history": sum(1 for m in body.medications if m.origin == "history"),
            "warnings": [c["severity"] for c in checks],
        },
    )
    await session.flush()
    await notify_patient(
        str(patient.id),
        "New prescription",
        f"Dr {doctor.name} added a prescription to your MediCard.",
    )
    await session.commit()

    detail = RecordDetail(
        record_id=str(record.id),
        type=record.type,
        doc_date=record.doc_date,
        provider=record.provider,
        verified=record.verified,
        sensitive=record.sensitive,
        created_at=record.created_at,
        data=RecordData.model_validate(record.data),
        source_url=None,
        extraction=None,
    )
    return RxCreateResult(record=detail, checks=[RxCheck(**c) for c in checks])


@router.post("/grants/{grant_id}/end", status_code=204)
async def end_my_grant(
    grant_id: str,
    doctor: Doctor = Depends(require_active_doctor),
    session: AsyncSession = Depends(get_session),
) -> None:
    try:
        gid = uuid.UUID(grant_id)
    except ValueError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Grant not found") from exc
    grant = await session.get(AccessGrant, gid)
    if grant is None or grant.doctor_id != doctor.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Grant not found")
    await acc.end_grant(session, grant, doctor.user_id, "doctor")
    await session.commit()
