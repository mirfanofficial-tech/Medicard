import secrets
from datetime import UTC, datetime, timedelta

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.core.security import hmac_sha256
from app.models import OtpChallenge

_settings = get_settings()


def _now() -> datetime:
    return datetime.now(UTC)


def _as_aware(dt: datetime) -> datetime:
    return dt if dt.tzinfo is not None else dt.replace(tzinfo=UTC)


async def issue_otp(session: AsyncSession, phone: str, purpose: str) -> str:
    """Create an OTP challenge and return the plaintext code.

    In dev the code is handed back to the caller so there is no SMS dependency.
    A production build would send it over SMS and return nothing.
    """
    code = f"{secrets.randbelow(1_000_000):06d}"
    challenge = OtpChallenge(
        phone=phone,
        code_hash=hmac_sha256(code),
        purpose=purpose,
        expires_at=_now() + timedelta(minutes=_settings.otp_ttl_min),
    )
    session.add(challenge)
    await session.flush()
    return code


async def verify_otp(session: AsyncSession, phone: str, code: str, purpose: str) -> None:
    challenge = (
        await session.execute(
            select(OtpChallenge)
            .where(
                OtpChallenge.phone == phone,
                OtpChallenge.purpose == purpose,
                OtpChallenge.consumed_at.is_(None),
            )
            .order_by(OtpChallenge.created_at.desc())
        )
    ).scalars().first()

    if challenge is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Request a code first")
    if challenge.attempts >= _settings.otp_max_attempts:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS, "Too many attempts; request a new code"
        )
    if _as_aware(challenge.expires_at) < _now():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Code expired; request a new one")

    challenge.attempts += 1
    if not secrets.compare_digest(challenge.code_hash, hmac_sha256(code)):
        await session.flush()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Incorrect code")

    challenge.consumed_at = _now()
    await session.flush()
