import secrets

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Patient

# Crockford base32: no I, L, O, U — avoids handwriting/OCR confusion.
_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
_BODY_LEN = 7


def _checksum(body: str) -> str:
    total = sum(_ALPHABET.index(c) for c in body)
    return _ALPHABET[total % len(_ALPHABET)]


def new_code() -> str:
    body = "".join(secrets.choice(_ALPHABET) for _ in range(_BODY_LEN))
    return body + _checksum(body)


def is_valid_shape(code: str) -> bool:
    code = code.strip().upper().replace("-", "")
    if len(code) != _BODY_LEN + 1 or any(c not in _ALPHABET for c in code):
        return False
    return _checksum(code[:_BODY_LEN]) == code[_BODY_LEN]


def normalise(code: str) -> str:
    return code.strip().upper().replace("-", "")


async def generate_unique_code(session: AsyncSession) -> str:
    for _ in range(20):
        code = new_code()
        exists = (
            await session.execute(select(Patient.id).where(Patient.medicard_code == code))
        ).first()
        if exists is None:
            return code
    raise RuntimeError("could not allocate a unique MediCard code")
