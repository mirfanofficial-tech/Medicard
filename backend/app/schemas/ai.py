from pydantic import BaseModel, Field

ADVISORY_NOTICE = (
    "Advisory only. This is decision support, not a diagnosis or a prescription. "
    "The licensed physician retains full clinical and prescribing responsibility."
)


class AiFlag(BaseModel):
    text: str
    severity: str  # info | watch | urgent
    source_record_ids: list[str] = Field(default_factory=list)


class AiSummary(BaseModel):
    summary: str
    flags: list[AiFlag] = Field(default_factory=list)
    relevant_history: list[str] = Field(default_factory=list)
    model: str
    advisory_notice: str = ADVISORY_NOTICE


class AiAskRequest(BaseModel):
    question: str = Field(min_length=3, max_length=500)


class AiAnswer(BaseModel):
    answer: str
    source_record_ids: list[str] = Field(default_factory=list)
    answered_from_records: bool
    model: str
    advisory_notice: str = ADVISORY_NOTICE
