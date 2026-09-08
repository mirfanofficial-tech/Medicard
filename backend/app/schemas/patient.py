from datetime import date, datetime

from pydantic import BaseModel, Field

from app.schemas.record import Medication


class PatientMe(BaseModel):
    patient_id: str
    name: str
    medicard_code: str
    phone: str | None = None
    dob: date | None = None
    gender: str | None = None
    blood_group: str | None = None
    address: str | None = None


class PatientMeUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    dob: date | None = None
    gender: str | None = Field(default=None, max_length=16)
    blood_group: str | None = Field(default=None, max_length=8)
    address: str | None = Field(default=None, max_length=300)


class RecentRecord(BaseModel):
    record_id: str
    type: str
    provider: str | None
    doc_date: date | None
    verified: bool
    created_at: datetime


class PatientOverview(BaseModel):
    name: str
    records: int
    lab_reports: int
    prescriptions: int
    imaging: int
    medications: int
    allergies: int
    recent: list[RecentRecord] = Field(default_factory=list)


class DerivedMedication(Medication):
    source_record_id: str
    source_date: str | None = None


class AllergyItem(BaseModel):
    name: str
    source_record_ids: list[str] = Field(default_factory=list)
