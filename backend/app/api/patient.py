import uuid
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal, require_patient
from app.db import get_session
from app.models import (
    AccessGrant,
    AccessRequest,
    AccessRequestStatus,
    AuditLog,
    CareLog,
    CarePlan,
    Doctor,
    Patient,
    Record,
)
from app.schemas.access import AuditEntryView, GrantView, PendingRequestView
from app.schemas.ai import AiSummary
from app.schemas.auth import MinorCreate, PatientSummary
from app.schemas.care import (
    CareLogRequest,
    CarePlanView,
    FollowUp,
    NextMedicine,
    PatientAnswer,
    PatientAskRequest,
    PatientHome,
    ReportView,
    SummaryView,
    TipView,
    TodayView,
)
from app.schemas.patient import (
    AllergyItem,
    DerivedMedication,
    PatientMe,
    PatientMeUpdate,
    PatientOverview,
    RecentRecord,
)
from app.services import access as acc
from app.services import ai_summary as ai
from app.services import care
from app.services import prescribe as rx
from app.services.medicard_code import generate_unique_code
from app.services.patients import self_patient as _self_patient

router = APIRouter(prefix="/patient", tags=["patient"])


async def _my_patient_ids(session: AsyncSession, user_id: uuid.UUID) -> tuple[Patient, dict]:
    """Return (self, {patient_id: name}) covering self + guardian-managed minors."""
    me = await _self_patient(session, user_id)
    minors = (
        await session.execute(select(Patient).where(Patient.guardian_patient_id == me.id))
    ).scalars().all()
    names = {me.id: me.name, **{m.id: m.name for m in minors}}
    return me, names


@router.get("/profiles", response_model=list[PatientSummary])
async def list_profiles(
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> list[PatientSummary]:
    """The signed-in patient plus any guardian-managed minor profiles."""
    me = await _self_patient(session, principal.user_id)
    minors = (
        await session.execute(select(Patient).where(Patient.guardian_patient_id == me.id))
    ).scalars().all()
    rows = [me, *minors]
    return [
        PatientSummary(
            patient_id=str(p.id),
            name=p.name,
            medicard_code=p.medicard_code,
            is_minor=p.guardian_patient_id is not None,
        )
        for p in rows
    ]


@router.post("/minors", response_model=PatientSummary, status_code=status.HTTP_201_CREATED)
async def create_minor(
    body: MinorCreate,
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> PatientSummary:
    guardian = await _self_patient(session, principal.user_id)
    minor = Patient(
        user_id=None,
        name=body.name.strip(),
        dob=body.dob,
        guardian_patient_id=guardian.id,
        medicard_code=await generate_unique_code(session),
    )
    session.add(minor)
    await session.commit()
    return PatientSummary(
        patient_id=str(minor.id),
        name=minor.name,
        medicard_code=minor.medicard_code,
        is_minor=True,
    )


# ---- consent: pending requests, approve / deny ----


@router.get("/access-requests", response_model=list[PendingRequestView])
async def pending_requests(
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> list[PendingRequestView]:
    _, names = await _my_patient_ids(session, principal.user_id)
    rows = (
        await session.execute(
            select(AccessRequest, Doctor)
            .join(Doctor, Doctor.id == AccessRequest.doctor_id)
            .where(
                AccessRequest.patient_id.in_(list(names.keys())),
                AccessRequest.status == AccessRequestStatus.pending.value,
            )
            .order_by(AccessRequest.created_at.desc())
        )
    ).all()
    return [
        PendingRequestView(
            request_id=str(r.id),
            doctor_name=d.name,
            hospital=d.hospital,
            specialty=d.specialty,
            for_patient=names[r.patient_id],
            created_at=r.created_at,
        )
        for r, d in rows
    ]


async def _owned_request(session: AsyncSession, principal: Principal, request_id: str):
    _, names = await _my_patient_ids(session, principal.user_id)
    try:
        rid = uuid.UUID(request_id)
    except ValueError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Request not found") from exc
    req = await session.get(AccessRequest, rid)
    if req is None or req.patient_id not in names:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Request not found")
    return req


@router.post("/access-requests/{request_id}/approve", response_model=GrantView)
async def approve(
    request_id: str,
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> GrantView:
    req = await _owned_request(session, principal, request_id)
    grant = await acc.approve_request(session, req, principal.user_id)
    doctor = await session.get(Doctor, grant.doctor_id)
    await session.commit()
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


@router.post("/access-requests/{request_id}/deny", status_code=204)
async def deny(
    request_id: str,
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> None:
    req = await _owned_request(session, principal, request_id)
    await acc.deny_request(session, req, principal.user_id)
    await session.commit()


# ---- active grants + revoke ----


@router.get("/grants", response_model=list[GrantView])
async def my_grants(
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> list[GrantView]:
    _, names = await _my_patient_ids(session, principal.user_id)
    rows = (
        await session.execute(
            select(AccessGrant, Doctor)
            .join(Doctor, Doctor.id == AccessGrant.doctor_id)
            .where(AccessGrant.patient_id.in_(list(names.keys())))
            .order_by(AccessGrant.granted_at.desc())
        )
    ).all()
    return [
        GrantView(
            grant_id=str(g.id),
            doctor_name=d.name,
            hospital=d.hospital,
            scope=g.scope,
            source=g.source,
            granted_at=g.granted_at,
            expires_at=g.expires_at,
            ended_at=g.ended_at,
        )
        for g, d in rows
    ]


@router.post("/grants/{grant_id}/revoke", status_code=204)
async def revoke_grant(
    grant_id: str,
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> None:
    _, names = await _my_patient_ids(session, principal.user_id)
    try:
        gid = uuid.UUID(grant_id)
    except ValueError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Grant not found") from exc
    grant = await session.get(AccessGrant, gid)
    if grant is None or grant.patient_id not in names:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Grant not found")
    await acc.end_grant(session, grant, principal.user_id, "patient")
    await session.commit()


# ---- access history ----


@router.get("/access-history", response_model=list[AuditEntryView])
async def access_history(
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> list[AuditEntryView]:
    _, names = await _my_patient_ids(session, principal.user_id)
    rows = (
        await session.execute(
            select(AuditLog, Doctor)
            .join(Doctor, Doctor.id == AuditLog.doctor_id, isouter=True)
            .where(AuditLog.patient_id.in_(list(names.keys())))
            .order_by(AuditLog.at.desc())
        )
    ).all()
    out: list[AuditEntryView] = []
    for entry, doctor in rows:
        out.append(
            AuditEntryView(
                at=entry.at,
                action=entry.action,
                scope=entry.scope,
                doctor_name=doctor.name if doctor else entry.meta.get("doctor_name"),
                hospital=doctor.hospital if doctor else entry.meta.get("hospital"),
                reason=entry.meta.get("reason"),
                for_patient=names.get(entry.patient_id, "—"),
            )
        )
    return out


# ---- profile: me / update ----


def _me_view(p: Patient) -> PatientMe:
    return PatientMe(
        patient_id=str(p.id),
        name=p.name,
        medicard_code=p.medicard_code,
        phone=p.phone,
        dob=p.dob,
        gender=p.gender,
        blood_group=p.blood_group,
        address=p.address,
    )


@router.get("/me", response_model=PatientMe)
async def get_me(
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> PatientMe:
    return _me_view(await _self_patient(session, principal.user_id))


@router.patch("/me", response_model=PatientMe)
async def update_me(
    body: PatientMeUpdate,
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> PatientMe:
    me = await _self_patient(session, principal.user_id)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(me, field, value.strip() if isinstance(value, str) else value)
    await session.commit()
    return _me_view(me)


# ---- home overview + derived health lists ----


async def _own_records(session: AsyncSession, patient_id: uuid.UUID) -> list[Record]:
    return list(
        (
            await session.execute(
                select(Record)
                .where(Record.patient_id == patient_id)
                .order_by(
                    Record.doc_date.is_(None),
                    Record.doc_date.desc(),
                    Record.created_at.desc(),
                )
            )
        ).scalars().all()
    )


@router.get("/overview", response_model=PatientOverview)
async def overview(
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> PatientOverview:
    me = await _self_patient(session, principal.user_id)
    records = await _own_records(session, me.id)
    by_type = {t: 0 for t in ("lab", "prescription", "imaging", "note")}
    for r in records:
        by_type[r.type] = by_type.get(r.type, 0) + 1
    return PatientOverview(
        name=me.name,
        records=len(records),
        lab_reports=by_type["lab"],
        prescriptions=by_type["prescription"],
        imaging=by_type["imaging"],
        medications=len(rx.current_medications(records)),
        allergies=len(rx.known_allergies(records)),
        recent=[
            RecentRecord(
                record_id=str(r.id),
                type=r.type,
                provider=r.provider,
                doc_date=r.doc_date,
                verified=r.verified,
                created_at=r.created_at,
            )
            for r in records[:5]
        ],
    )


@router.get("/medications", response_model=list[DerivedMedication])
async def medications(
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> list[DerivedMedication]:
    me = await _self_patient(session, principal.user_id)
    records = await _own_records(session, me.id)
    return [DerivedMedication(**m) for m in rx.current_medications(records)]


@router.get("/allergies", response_model=list[AllergyItem])
async def allergies(
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> list[AllergyItem]:
    me = await _self_patient(session, principal.user_id)
    records = await _own_records(session, me.id)
    by_name: dict[str, list[str]] = {}
    for r in records:
        for a in (r.data or {}).get("allergies", []) or []:
            by_name.setdefault(str(a), []).append(str(r.id))
    return [AllergyItem(name=n, source_record_ids=ids) for n, ids in sorted(by_name.items())]


@router.get("/ai-summary", response_model=AiSummary)
async def my_ai_summary(
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> AiSummary:
    """Advisory summary of the patient's own records. Same guardrails as the
    doctor-facing summary — it never recommends a treatment or a prescription."""
    me = await _self_patient(session, principal.user_id)
    records = await _own_records(session, me.id)
    return AiSummary(**await ai.summarize(records))


# ---- the simple front page: next medicine, today's care, summary, reports, tips ----


async def _plan_and_logs(
    session: AsyncSession, patient_id: uuid.UUID, days: int = 1
) -> tuple[CarePlan | None, list[CareLog]]:
    plans = list(
        (await session.execute(select(CarePlan).where(CarePlan.patient_id == patient_id)))
        .scalars()
        .all()
    )
    since = care.local_now().date() - timedelta(days=days - 1)
    logs = list(
        (
            await session.execute(
                select(CareLog).where(CareLog.patient_id == patient_id, CareLog.log_date >= since)
            )
        )
        .scalars()
        .all()
    )
    return care.active_plan(plans), logs


def _today_view(meds, plan, logs, today) -> TodayView:
    done_keys = {lg.item_key for lg in logs if lg.log_date == today and lg.done}
    items = care.today_items(meds, plan, done_keys)
    return TodayView(done=sum(1 for i in items if i["done"]), total=len(items), items=items)


async def _follow_up(session: AsyncSession, plan: CarePlan | None) -> FollowUp | None:
    if plan is None or plan.follow_up_date is None:
        return None
    doc = await session.get(Doctor, plan.doctor_id) if plan.doctor_id else None
    return FollowUp(
        date=plan.follow_up_date.isoformat(),
        when=plan.follow_up_date.strftime("%a %d %b"),
        with_doctor=f"Dr {doc.name}" if doc else None,
    )


@router.get("/home", response_model=PatientHome)
async def home(
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> PatientHome:
    me = await _self_patient(session, principal.user_id)
    records = [r for r in await _own_records(session, me.id) if r.verified]
    plan, logs = await _plan_and_logs(session, me.id)
    now = care.local_now()
    meds = rx.current_medications(records)
    today = _today_view(meds, plan, logs, now.date())
    nxt = care.next_medicine([i.model_dump() for i in today.items], now)
    pending = (
        await session.execute(
            select(func.count())
            .select_from(AccessRequest)
            .where(
                AccessRequest.patient_id == me.id,
                AccessRequest.status == AccessRequestStatus.pending.value,
            )
        )
    ).scalar_one()
    labs = [r for r in records if r.type == "lab"]
    return PatientHome(
        name=me.name,
        next_medicine=NextMedicine(**nxt) if nxt else None,
        today=today,
        summary=SummaryView(**care.plain_summary(records, plan)),
        reports=[ReportView(**x) for x in care.reports(records, 2)],
        more_reports=len(labs) > 2,
        tips=[TipView(**t) for t in care.tips(records, plan)],
        asks=care.ASKS,
        follow_up=await _follow_up(session, plan),
        pending_requests=pending,
    )


@router.get("/care-plan", response_model=CarePlanView)
async def care_plan(
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> CarePlanView:
    me = await _self_patient(session, principal.user_id)
    records = [r for r in await _own_records(session, me.id) if r.verified]
    plan, logs = await _plan_and_logs(session, me.id)
    now = care.local_now()
    today = _today_view(rx.current_medications(records), plan, logs, now.date())
    view = care.plan_view(plan, now)
    if view is None:
        return CarePlanView(has_plan=False, today=today)
    doc = await session.get(Doctor, plan.doctor_id) if plan.doctor_id else None
    return CarePlanView(
        has_plan=True,
        issued_by=f"Dr {doc.name}" if doc else None,
        issued_on=view["issued_on"],
        week=view["week"],
        of=view["of"],
        percent=view["percent"],
        today=today,
        diet=view["diet"],
        activity=view["activity"],
        events=view["events"],
        follow_up=await _follow_up(session, plan),
    )


@router.post("/care/log", response_model=TodayView)
async def log_care(
    body: CareLogRequest,
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> TodayView:
    if not body.item_key.startswith(("med:", "act:", "diet:")):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Unknown care item")
    me = await _self_patient(session, principal.user_id)
    today = care.local_now().date()
    row = (
        await session.execute(
            select(CareLog).where(
                CareLog.patient_id == me.id,
                CareLog.item_key == body.item_key,
                CareLog.log_date == today,
            )
        )
    ).scalar_one_or_none()
    if row is None:
        session.add(CareLog(patient_id=me.id, item_key=body.item_key, log_date=today, done=body.done))
    else:
        row.done = body.done
    await session.commit()
    records = [r for r in await _own_records(session, me.id) if r.verified]
    plan, logs = await _plan_and_logs(session, me.id)
    return _today_view(rx.current_medications(records), plan, logs, today)


@router.post("/ask", response_model=PatientAnswer)
async def ask_my_records(
    body: PatientAskRequest,
    principal: Principal = Depends(require_patient),
    session: AsyncSession = Depends(get_session),
) -> PatientAnswer:
    """Plain-language Q&A grounded only in the patient's own confirmed records."""
    me = await _self_patient(session, principal.user_id)
    records = [r for r in await _own_records(session, me.id) if r.verified]
    plan, _ = await _plan_and_logs(session, me.id)
    if ai._use_stub():
        result = care.answer_patient(records, plan, body.question)
    else:
        raw = await ai.ask(records, body.question, audience="patient")
        result = {
            "answer": raw["answer"],
            "answered_from_records": raw["answered_from_records"],
            "source_record_ids": raw["source_record_ids"],
        }
    return PatientAnswer(**result)
