from datetime import datetime

from pydantic import BaseModel, Field


class AccessRequestCreate(BaseModel):
    medicard_code: str = Field(min_length=6, max_length=16)


class AccessRequestView(BaseModel):
    request_id: str
    patient_name: str
    status: str
    created_at: datetime


class BreakGlassCreate(BaseModel):
    medicard_code: str = Field(min_length=6, max_length=16)
    reason: str = Field(min_length=4, max_length=500)


class GrantView(BaseModel):
    grant_id: str
    doctor_name: str
    hospital: str | None
    scope: str
    source: str
    granted_at: datetime
    expires_at: datetime
    ended_at: datetime | None = None


class DoctorGrantView(BaseModel):
    grant_id: str
    patient_id: str
    patient_name: str
    scope: str
    source: str
    granted_at: datetime
    expires_at: datetime


# ---- patient side ----


class PendingRequestView(BaseModel):
    request_id: str
    doctor_name: str
    hospital: str | None
    specialty: str | None
    for_patient: str
    created_at: datetime


class AuditEntryView(BaseModel):
    at: datetime
    action: str
    scope: str | None
    doctor_name: str | None
    hospital: str | None
    reason: str | None = None
    for_patient: str


class CriticalView(BaseModel):
    patient_name: str
    allergies: list[str]
    current_medications: list[dict]
    conditions: list[str]
    note: str
    grant: GrantView
