import uuid
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import require_active_doctor
from app.db import get_session
from app.models import (
    AccessGrant,
    AccessRequest,
    AuditAction,
    AuditLog,
    CareLog,
    CarePlan,
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
from app.schemas.care import (
    AssistantAsk,
    DashActive,
    DashActivity,
    DashDay,
    DashPending,
    DashStats,
    DoctorDashboard,
    DoctorTip,
    HistoryAlert,
    LabRow,
    OverviewCounts,
    OverviewRecord,
    PatientOverview,
    Upcoming,
    VoiceParseRequest,
    VoiceParseResult,
)
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
from app.services import care, voice
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
        history_alerts=[HistoryAlert(**a) for a in care.history_alerts(records)],
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
    found = rx.check(records, draft) + care.reaction_checks(records, draft)
    return RxCheckResult(checks=[RxCheck(**c) for c in found])


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
        {"name": m.name, "dose": m.dose, "route": m.route, "freq": m.freq, "days": m.days}
        for m in body.medications
    ]
    checks = rx.check(records, meds) + care.reaction_checks(records, meds)

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
    await session.flush()

    plan_created = False
    adv = body.advice
    if adv and (adv.diet or adv.activity or adv.tests or adv.follow_up_days):
        today = care.local_now().date()
        for old in (
            await session.execute(
                select(CarePlan).where(CarePlan.patient_id == patient.id, CarePlan.active.is_(True))
            )
        ).scalars():
            old.active = False
        session.add(
            CarePlan(
                patient_id=patient.id,
                doctor_id=doctor.id,
                record_id=record.id,
                diet=adv.diet.model_dump() if adv.diet else {},
                activity=adv.activity,
                tests=[
                    {"name": t.name, "due": (today + timedelta(days=t.in_days)).isoformat()}
                    for t in adv.tests
                ],
                follow_up_date=(
                    today + timedelta(days=adv.follow_up_days) if adv.follow_up_days else None
                ),
                notes=body.notes,
                active=True,
            )
        )
        plan_created = True

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
            "care_plan": plan_created,
        },
    )
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
    return RxCreateResult(
        record=detail,
        checks=[RxCheck(**c) for c in checks],
        care_plan_created=plan_created,
    )


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


@router.post("/assistant/ask", response_model=AiAnswer)
async def assistant_ask(
    body: AssistantAsk,
    doctor: Doctor = Depends(require_active_doctor),
    session: AsyncSession = Depends(get_session),
) -> AiAnswer:
    """The doctor's chat assistant. About one patient (needs a live grant, grounded in their
    shared records, logged) — or, with no patient open, a pointer to open one."""
    if not body.patient_id:
        return AiAnswer(
            answer="Open a patient's record (enter their MediCard code) and I can answer from it, "
            "with sources.",
            source_record_ids=[],
            answered_from_records=False,
            model="none",
        )
    patient = await _load_patient(session, body.patient_id)
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


@router.post("/voice/parse", response_model=VoiceParseResult)
async def voice_parse(
    body: VoiceParseRequest,
    doctor: Doctor = Depends(require_active_doctor),
) -> VoiceParseResult:
    """Format dictated text into a visit note, medicine lines and patient advice.

    Deterministic: it only structures what the doctor said — it never adds a medicine,
    dose or advice that was not spoken. Nothing is saved here.
    """
    return VoiceParseResult.model_validate(voice.parse(body.text))


@router.get("/patients/{patient_id}/overview", response_model=PatientOverview)
async def patient_overview(
    patient_id: str,
    doctor: Doctor = Depends(require_active_doctor),
    session: AsyncSession = Depends(get_session),
) -> PatientOverview:
    patient = await _load_patient(session, patient_id)
    grant = await acc.require_grant(session, doctor.id, patient.id, need_full=True)
    records = [r for r in await _shared_records(session, patient.id) if r.verified]
    now = care.local_now()

    hidden = (
        await session.execute(
            select(func.count())
            .select_from(Record)
            .where(Record.patient_id == patient.id, Record.sensitive.is_(True))
        )
    ).scalar_one()
    plans = list(
        (await session.execute(select(CarePlan).where(CarePlan.patient_id == patient.id)))
        .scalars()
        .all()
    )
    plan = care.active_plan(plans)
    logs = list(
        (
            await session.execute(
                select(CareLog).where(
                    CareLog.patient_id == patient.id,
                    CareLog.log_date >= now.date() - timedelta(days=6),
                )
            )
        )
        .scalars()
        .all()
    )
    meds = rx.current_medications(records)
    age = None
    if patient.dob:
        age = now.year - patient.dob.year - (
            (now.month, now.day) < (patient.dob.month, patient.dob.day)
        )

    await acc.log(
        session,
        patient_id=patient.id,
        actor_id=None,
        actor_role="doctor",
        doctor_id=doctor.id,
        action=AuditAction.view.value,
        scope=grant.scope,
        meta={"view": "overview"},
    )
    await session.commit()

    return PatientOverview(
        patient_id=str(patient.id),
        name=patient.name,
        age=age,
        gender=patient.gender,
        blood_group=patient.blood_group,
        medicard_code=patient.medicard_code,
        address=patient.address,
        conditions=care.conditions(records),
        allergies=rx.known_allergies(records),
        grant_expires_at=grant.expires_at.isoformat(),
        history_alerts=[HistoryAlert(**a) for a in care.history_alerts(records)],
        trends=care.trends(records),
        records=[
            OverviewRecord(
                record_id=str(r.id),
                type=r.type,
                title=care.record_title(r),
                sub=" · ".join(
                    x for x in (r.doc_date.strftime("%d %b %Y") if r.doc_date else "", r.provider)
                    if x
                ),
                verified=r.verified,
                summary=care.record_summary(r),
                date=r.doc_date.isoformat() if r.doc_date else None,
            )
            for r in records
        ],
        phone=patient.phone,
        registered_on=patient.created_at.strftime("%d %b %Y") if patient.created_at else None,
        last_updated=(
            max(
                (r.updated_at or r.created_at for r in records if (r.updated_at or r.created_at)),
                default=None,
            ).strftime("%d %b %Y")
            if records
            else None
        ),
        counts=OverviewCounts(
            conditions=len(care.conditions(records)),
            medications=len(meds),
            allergies=len(rx.known_allergies(records)),
            documents=len(records),
            lab_tests=care.lab_test_count(records),
        ),
        latest_labs=[LabRow(**x) for x in care.lab_rows(records)],
        upcoming=(
            Upcoming(title="Follow-up", when=plan.follow_up_date.strftime("%d %b %Y"))
            if plan and plan.follow_up_date
            else None
        ),
        hidden_count=hidden,
        medications=meds,
        tips=care.doctor_tips(records, meds, now),
        adherence=care.adherence(meds, plan, logs),
        visits=care.visits(records),
    )


_ACTIVITY_TEXT = {
    "request": "Requested access",
    "grant": "Patient approved access",
    "deny": "Patient declined access",
    "break_glass": "Emergency access (critical info only)",
    "revoke": "Patient revoked access",
    "end": "You ended access",
    "prescribe": "Prescription saved",
}
_VIEW_TEXT = {
    "ai_summary": "Opened the AI summary",
    "ai_ask": "Asked the AI about the record",
    "overview": "Opened the patient overview",
    "critical": "Viewed critical info",
}


@router.get("/dashboard", response_model=DoctorDashboard)
async def dashboard(
    doctor: Doctor = Depends(require_active_doctor),
    session: AsyncSession = Depends(get_session),
) -> DoctorDashboard:
    now = acc.utcnow()
    since30 = now - timedelta(days=30)
    local = care.local_now()

    grants = (
        await session.execute(
            select(AccessGrant, Patient)
            .join(Patient, Patient.id == AccessGrant.patient_id)
            .where(AccessGrant.doctor_id == doctor.id, AccessGrant.ended_at.is_(None))
            .order_by(AccessGrant.granted_at.desc())
        )
    ).all()
    live = [(g, p) for g, p in grants if acc.as_aware(g.expires_at) > now]

    active: list[DashActive] = []
    for g, p in live[:8]:
        alerts: list[DoctorTip] = []
        if g.scope == "full":
            recs = [r for r in await _shared_records(session, p.id) if r.verified]
            for a in care.history_alerts(recs):
                if a["kind"] == "allergy":
                    alerts.append(DoctorTip(severity="urgent", text=f"Allergy: {a['title']}"))
            meds = rx.current_medications(recs)
            for t in care.doctor_tips(recs, meds, local):
                alerts.append(DoctorTip(**t))
        age = None
        if p.dob:
            age = local.year - p.dob.year - ((local.month, local.day) < (p.dob.month, p.dob.day))
        active.append(
            DashActive(
                grant_id=str(g.id),
                patient_id=str(p.id),
                patient_name=p.name,
                age=age,
                gender=p.gender,
                scope=g.scope,
                source=g.source,
                expires_at=acc.as_aware(g.expires_at).isoformat(),
                alerts=alerts[:3],
            )
        )

    pending_rows = (
        await session.execute(
            select(AccessRequest, Patient)
            .join(Patient, Patient.id == AccessRequest.patient_id)
            .where(AccessRequest.doctor_id == doctor.id, AccessRequest.status == "pending")
            .order_by(AccessRequest.created_at.desc())
        )
    ).all()

    logs = list(
        (
            await session.execute(
                select(AuditLog, Patient)
                .join(Patient, Patient.id == AuditLog.patient_id)
                .where(AuditLog.doctor_id == doctor.id, AuditLog.at >= since30)
                .order_by(AuditLog.at.desc())
            )
        ).all()
    )

    week_days = [(local.date() - timedelta(days=i)) for i in range(6, -1, -1)]
    buckets = {d: DashDay(day=d.strftime("%a")) for d in week_days}
    for lg, _ in logs:
        d = acc.as_aware(lg.at).astimezone(care.PKT).date()
        if d in buckets:
            if lg.action == AuditAction.view.value:
                buckets[d].views += 1
            elif lg.action == AuditAction.prescribe.value:
                buckets[d].prescriptions += 1

    activity = []
    for lg, p in logs[:8]:
        text = (
            _VIEW_TEXT.get((lg.meta or {}).get("view", ""), "Viewed the records")
            if lg.action == AuditAction.view.value
            else _ACTIVITY_TEXT.get(lg.action, lg.action.title())
        )
        activity.append(
            DashActivity(
                at=acc.as_aware(lg.at).isoformat(),
                action=lg.action,
                patient_name=p.name.split(" ")[0],
                text=text,
            )
        )

    return DoctorDashboard(
        name=doctor.name,
        specialty=doctor.specialty,
        hospital=doctor.hospital,
        stats=DashStats(
            active_access=len(live),
            pending_requests=len(pending_rows),
            prescriptions_30d=sum(1 for lg, _ in logs if lg.action == "prescribe"),
            patients_seen_30d=len(
                {lg.patient_id for lg, _ in logs if lg.action in ("view", "prescribe")}
            ),
            emergency_30d=sum(1 for lg, _ in logs if lg.action == "break_glass"),
        ),
        week=list(buckets.values()),
        active=active,
        pending=[
            DashPending(
                request_id=str(r.id),
                patient_name=p.name.split(" ")[0],
                created_at=acc.as_aware(r.created_at).isoformat(),
            )
            for r, p in pending_rows[:6]
        ],
        activity=activity,
    )
