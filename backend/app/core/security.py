import hashlib
import hmac
from datetime import UTC, datetime, timedelta

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError

from app.config import get_settings

_settings = get_settings()
_ph = PasswordHasher()

ACCESS = "access"
REFRESH = "refresh"


def hash_password(password: str) -> str:
    return _ph.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return _ph.verify(password_hash, password)
    except VerifyMismatchError:
        return False


def hmac_sha256(value: str) -> str:
    """Deterministic keyed hash — used for OTP codes and CNIC (not passwords)."""
    return hmac.new(
        _settings.jwt_secret.encode(), value.encode(), hashlib.sha256
    ).hexdigest()


def _now() -> datetime:
    return datetime.now(UTC)


def create_access_token(subject: str, role: str) -> str:
    payload = {
        "sub": subject,
        "role": role,
        "type": ACCESS,
        "iat": _now(),
        "exp": _now() + timedelta(minutes=_settings.access_token_ttl_min),
    }
    return jwt.encode(payload, _settings.jwt_secret, algorithm=_settings.jwt_alg)


def create_refresh_token(subject: str) -> str:
    payload = {
        "sub": subject,
        "type": REFRESH,
        "iat": _now(),
        "exp": _now() + timedelta(days=_settings.refresh_token_ttl_days),
    }
    return jwt.encode(payload, _settings.jwt_secret, algorithm=_settings.jwt_alg)


def decode_token(token: str) -> dict:
    return jwt.decode(token, _settings.jwt_secret, algorithms=[_settings.jwt_alg])
