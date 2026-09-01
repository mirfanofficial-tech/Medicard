from datetime import date

from pydantic import BaseModel, Field

from app.schemas.record import Medication, RecordDetail


class RxCandidate(Medication):
    source_record_id: str
    source_date: str | None = None


class RxContext(BaseModel):
    patient_name: str
    candidates: list[RxCandidate] = Field(default_factory=list)
    known_allergies: list[str] = Field(default_factory=list)
    assistant_note: str = (
        "You are the prescriber. This assistant only lists medicines already documented "
        "for this patient and runs allergy / interaction / duplicate checks on your draft. "
        "It never proposes a new medicine."
    )


class RxCheck(BaseModel):
    kind: str  # allergy | interaction | duplicate
    severity: str  # urgent | watch | info
    message: str
    drugs: list[str] = Field(default_factory=list)


class RxLine(Medication):
    origin: str = "manual"  # "history" (ticked from the candidate list) | "manual"


class RxCheckRequest(BaseModel):
    medications: list[RxLine] = Field(default_factory=list)


class RxCheckResult(BaseModel):
    checks: list[RxCheck] = Field(default_factory=list)


class RxCreateRequest(BaseModel):
    doc_date: date | None = None
    medications: list[RxLine] = Field(min_length=1)
    notes: str | None = Field(default=None, max_length=1000)


class RxCreateResult(BaseModel):
    record: RecordDetail
    checks: list[RxCheck] = Field(default_factory=list)
