from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal, require_patient
from app.db import get_session
from app.models import Patient
from app.schemas.auth import MinorCreate, PatientSummary
from app.services.medicard_code import generate_unique_code
from app.services.patients import self_patient as _self_patient

router = APIRouter(prefix="/patient", tags=["patient"])


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


@router.post(
    "/minors",
    response_model=PatientSummary,
    status_code=status.HTTP_201_CREATED,
)
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
