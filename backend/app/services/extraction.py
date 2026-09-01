from __future__ import annotations

import base64
import json

from app.config import get_settings
from app.schemas.record import RecordData

_settings = get_settings()

SYSTEM = (
    "You transcribe a photographed or scanned medical document into structured data. "
    "You are an extraction tool, not a clinician: copy only what is written, never infer a "
    "diagnosis, dose, or interpretation that is not on the page. Medical handwriting is often "
    "ambiguous — when a field is unclear, still record your best reading but mark its confidence "
    "low. Do not invent values to fill the schema; leave lists empty when nothing applies."
)

PROMPT = (
    "Extract this document. Respond with ONLY a JSON object, no prose, matching:\n"
    "{\n"
    '  "type": "prescription|lab|imaging|note",\n'
    '  "doc_date": "YYYY-MM-DD or null",\n'
    '  "provider": "clinic or doctor name or null",\n'
    '  "data": {\n'
    '    "diagnoses": [string],\n'
    '    "medications": [{"name": s, "dose": s|null, "route": s|null, "freq": s|null}],\n'
    '    "lab_results": [{"name": s, "value": s|null, "unit": s|null, "ref_range": s|null}],\n'
    '    "allergies": [string],\n'
    '    "notes": string|null\n'
    "  },\n"
    '  "confidence_by_field": { "<field path>": 0.0-1.0 }\n'
    "}\n"
    "Use dotted paths in confidence_by_field, e.g. \"data.medications[0].dose\": 0.4."
)


def _fake(media_type: str) -> dict:
    return {
        "type": "prescription",
        "doc_date": "2026-05-10",
        "provider": "City Clinic (sample)",
        "data": {
            "diagnoses": ["Type 2 diabetes mellitus"],
            "medications": [
                {"name": "Metformin", "dose": "500 mg", "route": "oral", "freq": "twice daily"},
                {"name": "Ramipril", "dose": "5 mg", "route": "oral", "freq": "once daily"},
            ],
            "lab_results": [{"name": "HbA1c", "value": "8.1", "unit": "%", "ref_range": "<7"}],
            "allergies": ["Penicillin"],
            "notes": "Review in 3 months. (Stub data - no document was read.)",
        },
        "confidence_by_field": {
            "type": 0.95,
            "doc_date": 0.6,
            "data.medications[0].dose": 0.55,
            "data.medications[1].name": 0.7,
            "data.lab_results[0].value": 0.8,
        },
    }


def _strip_fences(text: str) -> str:
    t = text.strip()
    if t.startswith("```"):
        t = t.split("\n", 1)[1] if "\n" in t else t
        if t.endswith("```"):
            t = t[: -3]
    return t.strip().removeprefix("json").strip()


async def extract_document(data: bytes, media_type: str) -> dict:
    """Return {type, doc_date, provider, data, confidence_by_field}."""
    if _settings.fake_extraction or not _settings.anthropic_api_key:
        return _fake(media_type)

    import anthropic

    client = anthropic.AsyncAnthropic(api_key=_settings.anthropic_api_key)
    b64 = base64.standard_b64encode(data).decode()
    block = (
        {"type": "document", "source": {"type": "base64", "media_type": media_type, "data": b64}}
        if media_type == "application/pdf"
        else {"type": "image", "source": {"type": "base64", "media_type": media_type, "data": b64}}
    )
    msg = await client.messages.create(
        model=_settings.claude_model,
        max_tokens=2000,
        system=SYSTEM,
        messages=[{"role": "user", "content": [block, {"type": "text", "text": PROMPT}]}],
    )
    text = "".join(b.text for b in msg.content if getattr(b, "type", None) == "text")
    return json.loads(_strip_fences(text))


def normalise(raw: dict) -> tuple[str, str | None, str | None, RecordData, dict]:
    rtype = raw.get("type") or "note"
    if rtype not in {"prescription", "lab", "imaging", "note"}:
        rtype = "note"
    doc_date = raw.get("doc_date") or None
    provider = raw.get("provider") or None
    data = RecordData.model_validate(raw.get("data") or {})
    confidence = raw.get("confidence_by_field") or {}
    return rtype, doc_date, provider, data, confidence
