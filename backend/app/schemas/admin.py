from datetime import datetime
from typing import Literal

from pydantic import BaseModel


class DoctorReviewRow(BaseModel):
    doctor_id: str
    name: str
    email: str
    licence_no: str
    specialty: str | None
    hospital: str | None
    status: str
    registered_at: datetime


class DoctorDecision(BaseModel):
    decision: Literal["active", "rejected"]
    note: str | None = None
