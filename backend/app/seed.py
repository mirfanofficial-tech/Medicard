"""Seed a realistic demo patient + doctor.

    uv run python -m app.seed

Idempotent: it deletes the demo doctor and demo patient (by the known email /
phone) and recreates them, then prints the credentials.
"""

import asyncio
from datetime import UTC, date, datetime, timedelta

from sqlalchemy import delete, select

from app.core.security import hash_password
from app.db import SessionLocal
from app.models import (
    AccessGrant,
    AccessRequest,
    AuditLog,
    CareLog,
    CarePlan,
    Doctor,
    DoctorStatus,
    ExtractionJob,
    Patient,
    Record,
    User,
    UserRole,
)
from app.services.medicard_code import generate_unique_code

DOCTOR_EMAIL = "sara.ahmed@medicard-demo.com"
DOCTOR_PASSWORD = "demodemo123"
PATIENT_PHONE = "+923001112222"
SECOND_PHONE = "+923002223333"


async def _wipe(session) -> None:
    doc = (
        await session.execute(select(Doctor).where(Doctor.email == DOCTOR_EMAIL))
    ).scalar_one_or_none()
    pat = (
        await session.execute(
            select(Patient).where(Patient.phone == PATIENT_PHONE)
        )
    ).scalar_one_or_none()

    pids = [pat.id] if pat else []
    pat2 = (
        await session.execute(select(Patient).where(Patient.phone == SECOND_PHONE))
    ).scalar_one_or_none()
    if pat2:
        pids.append(pat2.id)
    if pat:
        minors = (
            await session.execute(
                select(Patient.id).where(Patient.guardian_patient_id == pat.id)
            )
        ).scalars().all()
        pids.extend(minors)

    if pids:
        await session.execute(delete(AuditLog).where(AuditLog.patient_id.in_(pids)))
        await session.execute(delete(AccessGrant).where(AccessGrant.patient_id.in_(pids)))
        await session.execute(delete(AccessRequest).where(AccessRequest.patient_id.in_(pids)))
        await session.execute(delete(CareLog).where(CareLog.patient_id.in_(pids)))
        await session.execute(delete(CarePlan).where(CarePlan.patient_id.in_(pids)))
        await session.execute(delete(ExtractionJob).where(ExtractionJob.patient_id.in_(pids)))
        await session.execute(delete(Record).where(Record.patient_id.in_(pids)))

    if doc:
        await session.execute(delete(AuditLog).where(AuditLog.doctor_id == doc.id))
        await session.execute(delete(AccessGrant).where(AccessGrant.doctor_id == doc.id))
        await session.execute(delete(AccessRequest).where(AccessRequest.doctor_id == doc.id))
        doc_user_id = doc.user_id
        await session.execute(delete(Doctor).where(Doctor.id == doc.id))
        await session.execute(delete(User).where(User.id == doc_user_id))

    for pid in pids:
        p = await session.get(Patient, pid)
        uid = p.user_id if p else None
        await session.execute(delete(Patient).where(Patient.id == pid))
        if uid:
            await session.execute(delete(User).where(User.id == uid))

    await session.flush()


def _rec(patient_id, rtype, doc_date, provider, data) -> Record:
    return Record(
        patient_id=patient_id,
        type=rtype,
        doc_date=doc_date,
        provider=provider,
        data=data,
        verified=True,
        sensitive=False,
    )


async def seed() -> None:
    async with SessionLocal() as session:
        await _wipe(session)

        du = User(role=UserRole.doctor.value)
        session.add(du)
        await session.flush()
        doctor = Doctor(
                user_id=du.id,
                name="Sara Ahmed",
                email=DOCTOR_EMAIL,
                password_hash=hash_password(DOCTOR_PASSWORD),
                licence_no="PMDC-DEMO-4471",
                specialty="Internal Medicine",
                hospital="City Hospital, Lahore",
                status=DoctorStatus.active.value,
        )
        session.add(doctor)

        pu = User(role=UserRole.patient.value)
        session.add(pu)
        await session.flush()
        patient = Patient(
            user_id=pu.id,
            name="Ayesha Khan",
            dob=date(1979, 4, 12),
            phone=PATIENT_PHONE,
            gender="Female",
            blood_group="O+",
            address="12 Jail Road, Lahore",
            medicard_code=await generate_unique_code(session),
        )
        session.add(patient)
        await session.flush()

        session.add_all(
            [
                _rec(
                    patient.id, "prescription", date(2026, 2, 10), "City Clinic",
                    {
                        "diagnoses": ["Type 2 diabetes mellitus", "Essential hypertension"],
                        "medications": [
                            {"name": "Metformin", "dose": "500 mg", "route": "oral",
                             "freq": "twice daily"},
                            {"name": "Ramipril", "dose": "5 mg", "route": "oral",
                             "freq": "once daily, at night"},
                        ],
                        "lab_results": [],
                        "allergies": ["Penicillin"],
                        "notes": "Lifestyle advice given.",
                    },
                ),
                _rec(
                    patient.id, "lab", date(2026, 2, 10), "City Clinic Lab",
                    {"diagnoses": [], "medications": [], "allergies": [],
                     "lab_results": [{"name": "HbA1c", "value": "7.4", "unit": "%",
                                      "ref_range": "<7"}],
                     "notes": None},
                ),
                _rec(
                    patient.id, "lab", date(2026, 5, 12), "City Clinic Lab",
                    {"diagnoses": [], "medications": [], "allergies": [],
                     "lab_results": [{"name": "HbA1c", "value": "8.1", "unit": "%",
                                      "ref_range": "<7"}],
                     "notes": None},
                ),
                _rec(
                    patient.id, "lab", date(2026, 8, 20), "City Clinic Lab",
                    {"diagnoses": [], "medications": [], "allergies": [],
                     "lab_results": [{"name": "HbA1c", "value": "8.6", "unit": "%",
                                      "ref_range": "<7"}],
                     "notes": None},
                ),
                _rec(
                    patient.id, "prescription", date(2026, 8, 20), "City Clinic",
                    {
                        "diagnoses": ["Type 2 diabetes mellitus", "Osteoarthritis (knee)"],
                        "medications": [
                            {"name": "Metformin", "dose": "500 mg", "route": "oral",
                             "freq": "twice daily"},
                            {"name": "Ramipril", "dose": "5 mg", "route": "oral",
                             "freq": "once daily, at night"},
                            {"name": "Ibuprofen", "dose": "400 mg", "route": "oral",
                             "freq": "as needed"},
                        ],
                        "lab_results": [],
                        "allergies": ["Penicillin"],
                        "notes": "Knee pain; NSAID started.",
                    },
                ),
            ]
        )

        session.add_all(
            [
                _rec(
                    patient.id, "lab", date(2026, 2, 10), "City Clinic Lab",
                    {"diagnoses": [], "medications": [], "allergies": [],
                     "lab_results": [{"name": "Creatinine", "value": "0.9", "unit": "mg/dL",
                                      "ref_range": "0.6-1.1"}],
                     "notes": None},
                ),
                _rec(
                    patient.id, "lab", date(2026, 8, 20), "City Clinic Lab",
                    {"diagnoses": [], "medications": [], "allergies": [],
                     "lab_results": [{"name": "Creatinine", "value": "0.9", "unit": "mg/dL",
                                      "ref_range": "0.6-1.1"}],
                     "notes": None},
                ),
                _rec(
                    patient.id, "lab", date(2026, 9, 28), "City Clinic Lab",
                    {"diagnoses": [], "medications": [], "allergies": [],
                     "lab_results": [{"name": "Total cholesterol", "value": "182",
                                      "unit": "mg/dL", "ref_range": "<200"}],
                     "notes": None},
                ),
                _rec(
                    patient.id, "note", date(2026, 9, 14), "Dr Sara Ahmed",
                    {
                        "diagnoses": ["Type 2 diabetes mellitus", "Essential hypertension",
                                      "High cholesterol"],
                        "medications": [], "lab_results": [], "allergies": ["Penicillin"],
                        "reactions": [
                            {"drug": "Metformin",
                             "effect": "Nausea at 1000 mg; dose reduced to 500 mg",
                             "date": "Jun 2026"},
                            {"drug": "Ibuprofen",
                             "effect": "Stomach pain and a rise in creatinine",
                             "date": "Aug 2025"},
                        ],
                        "stopped": [
                            {"name": "Amlodipine",
                             "reason": "Ankle swelling; switched to ramipril", "date": "2025"},
                        ],
                        "notes": "Review. Metformin reduced after nausea.",
                    },
                ),
            ]
        )

        # A care plan written by Dr Sara nine days ago, with a week of patient ticks.
        issued = datetime.now(UTC) - timedelta(days=9)
        await session.flush()
        session.add(
            CarePlan(
                patient_id=patient.id,
                doctor_id=doctor.id,
                diet={
                    "note": "Low-sugar diet",
                    "more": ["Daal and sabzi", "Salad", "Daliya", "Plain yogurt"],
                    "less": ["Sugar in chai", "Mithai", "Fried food", "Cold drinks"],
                },
                activity=["Walk 20 minutes"],
                tests=[{"name": "HbA1c test",
                        "due": (date.today() + timedelta(days=9)).isoformat()}],
                follow_up_date=date.today() + timedelta(days=14),
                notes="Low sugar diet, walking, review in two weeks.",
                active=True,
                created_at=issued,
            )
        )
        for back in range(1, 7):
            day = date.today() - timedelta(days=back)
            keys = ["med:metformin:08:00", "med:metformin:20:00", "med:ramipril:20:00",
                    "diet:0"]
            if back in (1, 4):
                keys.append("act:0")
            for k in keys:
                if back == 3 and k.startswith("med:metformin:20"):
                    continue  # one missed evening dose
                session.add(CareLog(patient_id=patient.id, item_key=k, log_date=day, done=True))
        # today: morning metformin already taken
        session.add(
            CareLog(patient_id=patient.id, item_key="med:metformin:08:00",
                    log_date=date.today(), done=True)
        )

        # --- a second patient, a live grant, a pending request and a week of activity ---
        zu = User(role=UserRole.patient.value)
        session.add(zu)
        await session.flush()
        zain = Patient(
            user_id=zu.id,
            name="Zain Malik",
            dob=date(1988, 9, 3),
            phone=SECOND_PHONE,
            gender="Male",
            blood_group="A+",
            medicard_code=await generate_unique_code(session),
        )
        session.add(zain)
        await session.flush()
        session.add(
            _rec(
                zain.id, "prescription", date(2026, 10, 1), "Services Hospital",
                {"diagnoses": ["Asthma"],
                 "medications": [{"name": "Salbutamol", "dose": "100 mcg", "route": "inhaled",
                                  "freq": "as needed"}],
                 "lab_results": [], "allergies": [], "notes": None},
            )
        )

        now = datetime.now(UTC)
        req = AccessRequest(
            doctor_id=doctor.id, patient_id=patient.id, status="approved", decided_at=now
        )
        session.add(req)
        await session.flush()
        session.add(
            AccessGrant(
                request_id=req.id, doctor_id=doctor.id, patient_id=patient.id, scope="full",
                source="consent", granted_at=now - timedelta(hours=1),
                expires_at=now + timedelta(hours=11),
            )
        )
        session.add(
            AccessRequest(doctor_id=doctor.id, patient_id=zain.id, status="pending")
        )

        def _log(days_ago: int, hours_ago: int, action: str, meta: dict | None = None):
            session.add(
                AuditLog(
                    patient_id=patient.id, actor_id=None, actor_role="doctor",
                    doctor_id=doctor.id, action=action, scope="full",
                    at=now - timedelta(days=days_ago, hours=hours_ago), meta=meta or {},
                )
            )

        _log(0, 1, "grant")
        _log(0, 1, "view", {"view": "overview"})
        _log(0, 0, "view", {"view": "ai_summary"})
        _log(1, 3, "view", {"view": "overview"})
        _log(1, 2, "prescribe")
        _log(2, 5, "view", {"view": "overview"})
        _log(3, 4, "view", {"view": "ai_summary"})
        _log(3, 3, "view", {"view": "overview"})
        _log(4, 6, "view", {"view": "overview"})
        _log(5, 2, "prescribe")
        _log(5, 2, "view", {"view": "overview"})

        sensitive = _rec(
            patient.id, "note", date(2025, 11, 3), "Community Health Centre",
            {"diagnoses": ["Generalised anxiety disorder"], "medications": [],
             "lab_results": [], "allergies": [],
             "notes": "Counselling ongoing. Patient asked to keep this private."},
        )
        sensitive.sensitive = True
        session.add(sensitive)

        await session.commit()

        print("\nDemo data ready.\n")
        print(f"  Doctor login : {DOCTOR_EMAIL} / {DOCTOR_PASSWORD}  (verified)")
        print(f"  Patient phone: {PATIENT_PHONE}  (OTP is returned in the API response in dev)")
        print(f"  MediCard code: {patient.medicard_code}")
        print(f"  Second patient (pending request): {zain.medicard_code}")
        print(
            "\n  Ayesha has 6 records (1 marked sensitive): rising HbA1c across 3 visits "
            "and\n  a new NSAID alongside an ACE inhibitor - both should surface in the AI "
            "summary.\n"
        )


if __name__ == "__main__":
    asyncio.run(seed())
