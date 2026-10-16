from pydantic import BaseModel, Field

from app.schemas.ai import ADVISORY_NOTICE


class NextMedicine(BaseModel):
    key: str
    name: str
    at: str
    in_minutes: int


class TodayItem(BaseModel):
    key: str
    kind: str  # medicine | diet | activity
    title: str
    sub: str
    time: str
    done: bool


class TodayView(BaseModel):
    done: int
    total: int
    items: list[TodayItem] = Field(default_factory=list)


class SummaryView(BaseModel):
    text: str
    trend: list[dict] = Field(default_factory=list)
    unit: str | None = None
    note: str = "Explained from your own records. It is not a diagnosis."


class ReportView(BaseModel):
    record_id: str
    title: str
    sub: str
    verdict: str
    level: str  # high | low | normal | unknown


class TipView(BaseModel):
    emoji: str
    title: str
    sub: str
    from_doctor: bool = False


class FollowUp(BaseModel):
    date: str
    when: str
    with_doctor: str | None = None


class PatientHome(BaseModel):
    name: str
    next_medicine: NextMedicine | None = None
    today: TodayView
    summary: SummaryView
    reports: list[ReportView] = Field(default_factory=list)
    more_reports: bool = False
    tips: list[TipView] = Field(default_factory=list)
    asks: list[str] = Field(default_factory=list)
    follow_up: FollowUp | None = None
    pending_requests: int = 0


class DietView(BaseModel):
    note: str | None = None
    more: list[str] = Field(default_factory=list)
    less: list[str] = Field(default_factory=list)


class EventView(BaseModel):
    title: str
    when: str
    date: str
    kind: str


class CarePlanView(BaseModel):
    has_plan: bool
    issued_by: str | None = None
    issued_on: str | None = None
    week: int = 0
    of: int = 0
    percent: int = 0
    today: TodayView
    diet: DietView = Field(default_factory=DietView)
    activity: list[str] = Field(default_factory=list)
    events: list[EventView] = Field(default_factory=list)
    follow_up: FollowUp | None = None
    disclaimer: str = (
        "This plan follows your doctor's advice. If you feel very unwell, contact your "
        "doctor or go to the nearest hospital."
    )


class CareLogRequest(BaseModel):
    item_key: str = Field(min_length=3, max_length=120)
    done: bool = True


class PatientAskRequest(BaseModel):
    question: str = Field(min_length=3, max_length=500)


class PatientAnswer(BaseModel):
    answer: str
    answered_from_records: bool
    source_record_ids: list[str] = Field(default_factory=list)
    notice: str = "Answers come only from your own records. For emergencies, call your doctor."


# ---- doctor side ----

class VoiceParseRequest(BaseModel):
    text: str = Field(min_length=3, max_length=4000)


class VoiceNote(BaseModel):
    complaint: str | None = None
    assessment: str | None = None
    plan: str | None = None


class VoiceMedicine(BaseModel):
    name: str
    dose: str | None = None
    freq: str | None = None
    days: str | None = None


class AdviceTest(BaseModel):
    name: str
    in_days: int


class AdviceDiet(BaseModel):
    note: str | None = None
    more: list[str] = Field(default_factory=list)
    less: list[str] = Field(default_factory=list)


class Advice(BaseModel):
    diet: AdviceDiet | None = None
    activity: list[str] = Field(default_factory=list)
    tests: list[AdviceTest] = Field(default_factory=list)
    follow_up_days: int | None = Field(default=None, ge=1, le=365)


class VoiceParseResult(BaseModel):
    note: VoiceNote
    medications: list[VoiceMedicine] = Field(default_factory=list)
    advice: Advice
    notice: str = (
        "Written from your dictation. Check every field — nothing is saved until you confirm."
    )


class AssistantAsk(BaseModel):
    question: str = Field(min_length=2, max_length=500)
    patient_id: str | None = None


class HistoryAlert(BaseModel):
    kind: str  # allergy | reaction | stopped
    severity: str  # urgent | watch | info
    title: str
    text: str
    source_record_id: str
    source_label: str


class TrendPoint(BaseModel):
    date: str | None
    value: float


class TrendView(BaseModel):
    name: str
    unit: str | None = None
    latest: float
    flag: str
    ref: str | None = None
    points: list[TrendPoint] = Field(default_factory=list)


class DoctorTip(BaseModel):
    severity: str
    text: str


class AdherenceRow(BaseModel):
    label: str
    done: int
    total: int


class VisitRow(BaseModel):
    date: str | None
    text: str


class OverviewRecord(BaseModel):
    record_id: str
    type: str
    title: str
    sub: str
    verified: bool
    summary: str | None = None
    date: str | None = None


class LabRow(BaseModel):
    name: str
    value: str
    unit: str | None = None
    ref: str | None = None
    flag: str  # high | low | normal | unknown
    date: str | None = None
    record_id: str


class OverviewCounts(BaseModel):
    conditions: int = 0
    medications: int = 0
    allergies: int = 0
    documents: int = 0
    lab_tests: int = 0


class Upcoming(BaseModel):
    title: str
    when: str


class PatientOverview(BaseModel):
    patient_id: str
    name: str
    age: int | None = None
    gender: str | None = None
    blood_group: str | None = None
    medicard_code: str
    address: str | None = None
    phone: str | None = None
    registered_on: str | None = None
    last_updated: str | None = None
    counts: OverviewCounts = Field(default_factory=OverviewCounts)
    latest_labs: list[LabRow] = Field(default_factory=list)
    upcoming: Upcoming | None = None
    conditions: list[str] = Field(default_factory=list)
    allergies: list[str] = Field(default_factory=list)
    grant_expires_at: str | None = None
    history_alerts: list[HistoryAlert] = Field(default_factory=list)
    trends: list[TrendView] = Field(default_factory=list)
    records: list[OverviewRecord] = Field(default_factory=list)
    hidden_count: int = 0
    medications: list[dict] = Field(default_factory=list)
    tips: list[DoctorTip] = Field(default_factory=list)
    adherence: list[AdherenceRow] = Field(default_factory=list)
    visits: list[VisitRow] = Field(default_factory=list)
    advisory_notice: str = ADVISORY_NOTICE


class DashStats(BaseModel):
    active_access: int = 0
    pending_requests: int = 0
    prescriptions_30d: int = 0
    patients_seen_30d: int = 0
    emergency_30d: int = 0


class DashDay(BaseModel):
    day: str
    views: int = 0
    prescriptions: int = 0


class DashActive(BaseModel):
    grant_id: str
    patient_id: str
    patient_name: str
    age: int | None = None
    gender: str | None = None
    scope: str
    source: str
    expires_at: str
    alerts: list[DoctorTip] = Field(default_factory=list)


class DashPending(BaseModel):
    request_id: str
    patient_name: str
    created_at: str


class DashActivity(BaseModel):
    at: str
    action: str
    patient_name: str
    text: str


class DoctorDashboard(BaseModel):
    name: str
    specialty: str | None = None
    hospital: str | None = None
    stats: DashStats
    week: list[DashDay] = Field(default_factory=list)
    active: list[DashActive] = Field(default_factory=list)
    pending: list[DashPending] = Field(default_factory=list)
    activity: list[DashActivity] = Field(default_factory=list)
