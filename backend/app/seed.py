"""Seed a realistic demo patient + doctor.

    uv run python -m app.seed

Idempotent: it deletes the demo doctor and demo patient (by the known email /
phone) and recreates them, then prints the credentials.
"""

import asyncio
from datetime import date

from sqlalchemy import delete, select

from app.core.security import hash_password
from app.db import SessionLocal
from app.models import (
    AccessGrant,
    AccessRequest,
    AuditLog,
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
        session.add(
            Doctor(
                user_id=du.id,
                name="Sara Ahmed",
                email=DOCTOR_EMAIL,
                password_hash=hash_password(DOCTOR_PASSWORD),
                licence_no="PMDC-DEMO-4471",
                specialty="Internal Medicine",
                hospital="City Hospital, Lahore",
                status=DoctorStatus.active.value,
            )
        )

        pu = User(role=UserRole.patient.value)
        session.add(pu)
        await session.flush()
        patient = Patient(
            user_id=pu.id,
            name="Ayesha Khan",
            dob=date(1979, 4, 12),
            phone=PATIENT_PHONE,
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
                             "freq": "once daily"},
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
                            {"name": "Metformin", "dose": "1000 mg", "route": "oral",
                             "freq": "twice daily"},
                            {"name": "Ramipril", "dose": "5 mg", "route": "oral",
                             "freq": "once daily"},
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
        print(
            "\n  Ayesha has 6 records (1 marked sensitive): rising HbA1c across 3 visits "
            "and\n  a new NSAID alongside an ACE inhibitor - both should surface in the AI "
            "summary.\n"
        )


if __name__ == "__main__":
    asyncio.run(seed())
