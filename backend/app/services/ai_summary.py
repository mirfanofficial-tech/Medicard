from __future__ import annotations

import json

from app.config import get_settings
from app.models import Record

_settings = get_settings()

SUMMARY_SYSTEM = (
    "You are clinical decision SUPPORT for a licensed physician who is looking at a patient's "
    "record. Your job is to summarise and to flag — never to decide.\n"
    "Hard rules:\n"
    "- Never recommend starting, stopping, or changing a medication. Never output a drug name "
    "paired with a dose as a suggested action. You may NOTE medications already in the record.\n"
    "- Never state a diagnosis the record does not already contain. You may point out a pattern "
    "worth a physician's attention (a rising lab trend, a possible drug interaction between "
    "medications already listed, an allergy that conflicts with a listed medication).\n"
    "- Every statement in 'summary' and every flag must cite the record id(s) it is based on. "
    "If you cannot cite a record, do not say it.\n"
    "- Be concise and neutral. No treatment plan."
)

ASK_SYSTEM = (
    "You answer a physician's question using ONLY the patient records provided as JSON. "
    "Do not use outside knowledge to add clinical facts about this patient. "
    "If the answer is not in the records, say so plainly and set answered_from_records to false. "
    "Cite the record id(s) you used. Never recommend a prescription or a dose change."
)


def records_payload(records: list[Record]) -> list[dict]:
    return [
        {
            "record_id": str(r.id),
            "type": r.type,
            "doc_date": r.doc_date.isoformat() if r.doc_date else None,
            "provider": r.provider,
            "verified": r.verified,
            "data": r.data or {},
        }
        for r in records
    ]


def _use_stub() -> bool:
    return _settings.fake_ai or not _settings.anthropic_api_key


def _stub_summary(payload: list[dict]) -> dict:
    ids = [p["record_id"] for p in payload]
    if not ids:
        return {
            "summary": "No confirmed records are shared for this patient yet.",
            "flags": [],
            "relevant_history": [],
        }
    meds = [
        m
        for p in payload
        for m in (p["data"].get("medications") or [])
        if p["type"] == "prescription"
    ]
    allergies = sorted({a for p in payload for a in (p["data"].get("allergies") or [])})
    labs = [
        (p["record_id"], lab)
        for p in payload
        for lab in (p["data"].get("lab_results") or [])
    ]
    flags = []
    if allergies and meds:
        flags.append(
            {
                "text": f"Patient lists allergies ({', '.join(allergies)}). Cross-check against "
                f"the {len(meds)} medication(s) on record before prescribing.",
                "severity": "watch",
                "source_record_ids": ids,
            }
        )
    for rid, lab in labs:
        flags.append(
            {
                "text": f"{lab.get('name')} recorded at {lab.get('value')} "
                f"{lab.get('unit') or ''} (ref {lab.get('ref_range') or 'n/a'}) - review trend.",
                "severity": "info",
                "source_record_ids": [rid],
            }
        )
    return {
        "summary": (
            f"{len(payload)} confirmed record(s): "
            f"{', '.join(sorted({p['type'] for p in payload}))}. "
            f"{len(meds)} medication line(s), "
            f"{len(allergies)} allergy note(s). (Stub summary — no model was called.)"
        ),
        "flags": flags,
        "relevant_history": [
            f"{p['type']} {p['doc_date'] or 'undated'} ({p['record_id'][:8]})" for p in payload
        ],
    }


def _stub_answer(payload: list[dict], question: str) -> dict:
    ids = [p["record_id"] for p in payload]
    allergies = sorted({a for p in payload for a in (p["data"].get("allergies") or [])})
    q = question.lower()
    if "allerg" in q and allergies:
        return {
            "answer": f"The record lists these allergies: {', '.join(allergies)}.",
            "source_record_ids": ids,
            "answered_from_records": True,
        }
    return {
        "answer": "That is not answerable from the shared records. (Stub answer — no model "
        "was called.)",
        "source_record_ids": [],
        "answered_from_records": False,
    }


def _strip_fences(text: str) -> str:
    t = text.strip()
    if t.startswith("```"):
        t = t.split("\n", 1)[1] if "\n" in t else t
        if t.endswith("```"):
            t = t[:-3]
    return t.strip().removeprefix("json").strip()


async def _call(system: str, user_text: str) -> dict:
    import anthropic

    client = anthropic.AsyncAnthropic(api_key=_settings.anthropic_api_key)
    msg = await client.messages.create(
        model=_settings.claude_model,
        max_tokens=1500,
        system=system,
        messages=[{"role": "user", "content": [{"type": "text", "text": user_text}]}],
    )
    text = "".join(b.text for b in msg.content if getattr(b, "type", None) == "text")
    return json.loads(_strip_fences(text))


async def summarize(records: list[Record]) -> dict:
    payload = records_payload(records)
    if _use_stub():
        return {**_stub_summary(payload), "model": "stub"}
    prompt = (
        "Patient records (JSON):\n"
        + json.dumps(payload, ensure_ascii=False)
        + "\n\nRespond with ONLY JSON: "
        '{"summary": str, "flags": [{"text": str, "severity": "info|watch|urgent", '
        '"source_record_ids": [str]}], "relevant_history": [str]}'
    )
    raw = await _call(SUMMARY_SYSTEM, prompt)
    return {
        "summary": str(raw.get("summary", "")),
        "flags": raw.get("flags", []) or [],
        "relevant_history": raw.get("relevant_history", []) or [],
        "model": _settings.claude_model,
    }


async def ask(records: list[Record], question: str) -> dict:
    payload = records_payload(records)
    if _use_stub():
        return {**_stub_answer(payload, question), "model": "stub"}
    prompt = (
        "Patient records (JSON):\n"
        + json.dumps(payload, ensure_ascii=False)
        + f"\n\nPhysician question: {question}\n\n"
        'Respond with ONLY JSON: {"answer": str, "source_record_ids": [str], '
        '"answered_from_records": bool}'
    )
    raw = await _call(ASK_SYSTEM, prompt)
    return {
        "answer": str(raw.get("answer", "")),
        "source_record_ids": raw.get("source_record_ids", []) or [],
        "answered_from_records": bool(raw.get("answered_from_records", False)),
        "model": _settings.claude_model,
    }
