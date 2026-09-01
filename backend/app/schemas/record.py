from datetime import date, datetime

from pydantic import BaseModel, Field


class Medication(BaseModel):
    name: str
    dose: str | None = None
    route: str | None = None
    freq: str | None = None


class LabResult(BaseModel):
    name: str
    value: str | None = None
    unit: str | None = None
    ref_range: str | None = None


class RecordData(BaseModel):
    diagnoses: list[str] = Field(default_factory=list)
    medications: list[Medication] = Field(default_factory=list)
    lab_results: list[LabResult] = Field(default_factory=list)
    allergies: list[str] = Field(default_factory=list)
    notes: str | None = None


class RecordSummary(BaseModel):
    record_id: str
    type: str
    doc_date: date | None
    provider: str | None
    verified: bool
    sensitive: bool
    created_at: datetime


class ExtractionView(BaseModel):
    job_id: str
    status: str
    confidence_by_field: dict = Field(default_factory=dict)
    error: str | None = None


class RecordDetail(RecordSummary):
    data: RecordData
    source_url: str | None = None
    extraction: ExtractionView | None = None


class UploadResult(BaseModel):
    record_id: str
    type: str


class ExtractResult(BaseModel):
    record_id: str
    extraction: ExtractionView
    draft: RecordData


class ConfirmRequest(BaseModel):
    type: str | None = None
    doc_date: date | None = None
    provider: str | None = None
    data: RecordData


class SensitiveRequest(BaseModel):
    sensitive: bool
