from datetime import date

from pydantic import BaseModel, EmailStr, Field


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


# ---- patient phone OTP ----


class OtpRequest(BaseModel):
    phone: str = Field(min_length=6, max_length=32)


class OtpRequestResult(BaseModel):
    sent: bool = True
    # dev only: the code is echoed so the flow works without an SMS provider
    dev_code: str | None = None


class PatientOtpVerify(BaseModel):
    phone: str = Field(min_length=6, max_length=32)
    code: str = Field(min_length=6, max_length=6)
    # only used when the phone is new
    name: str | None = Field(default=None, max_length=120)
    dob: date | None = None
    cnic: str | None = Field(default=None, max_length=20)


class PatientAuthResult(BaseModel):
    tokens: TokenPair
    patient_id: str
    medicard_code: str
    is_new: bool


# ---- patient recovery ----


class PatientRecoverVerify(BaseModel):
    phone: str = Field(min_length=6, max_length=32)
    code: str = Field(min_length=6, max_length=6)
    cnic: str | None = Field(default=None, max_length=20)


class PatientRecoverResult(BaseModel):
    tokens: TokenPair
    patient_id: str
    medicard_code: str
    reissued: bool = True


# ---- doctor ----


class DoctorRegister(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    licence_no: str = Field(min_length=3, max_length=64)
    specialty: str | None = Field(default=None, max_length=120)
    hospital: str | None = Field(default=None, max_length=200)


class DoctorLogin(BaseModel):
    email: EmailStr
    password: str


class DoctorAuthResult(BaseModel):
    tokens: TokenPair
    doctor_id: str
    status: str


class RefreshRequest(BaseModel):
    refresh_token: str


class AccessTokenResult(BaseModel):
    access_token: str
    token_type: str = "bearer"


# ---- me / guardian ----


class MeResult(BaseModel):
    user_id: str
    role: str
    profile: dict


class MinorCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    dob: date | None = None


class PatientSummary(BaseModel):
    patient_id: str
    name: str
    medicard_code: str
    is_minor: bool
