"""SQLAlchemy models. Import every model here so Alembic autogenerate sees them."""

from app.models.base import Base
from app.models.doctor import Doctor, DoctorStatus
from app.models.otp import OtpChallenge, OtpPurpose
from app.models.patient import Patient
from app.models.record import ExtractionJob, ExtractionStatus, Record, RecordType
from app.models.user import User, UserRole

__all__ = [
    "Base",
    "User",
    "UserRole",
    "Patient",
    "Doctor",
    "DoctorStatus",
    "OtpChallenge",
    "OtpPurpose",
    "Record",
    "RecordType",
    "ExtractionJob",
    "ExtractionStatus",
]
