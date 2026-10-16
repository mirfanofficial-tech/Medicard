"""Patient care journey + doctor-side history surfacing.

Everything here is deterministic (no model call): it re-presents what is already in
the patient's confirmed records and in the doctor's own care plan.
"""

from __future__ import annotations

import re
from datetime import date, datetime, timedelta, timezone

from app.models import CareLog, CarePlan, Record
from app.services import prescribe as rx

# Pakistan Standard Time — fixed offset, so no tzdata dependency on Windows.
PKT = timezone(timedelta(hours=5))
PLAN_WEEKS = 6


def local_now() -> datetime:
    return datetime.now(PKT)


# ---------------------------------------------------------------- lab helpers

_FRIENDLY = (
    (("hba1c", "glucose", "sugar"), "sugar"),
    (("cholesterol", "ldl", "hdl", "lipid", "triglyceride"), "cholesterol"),
    (("creatinine", "urea", "egfr"), "kidney test"),
)


def friendly(name: str) -> str:
    n = name.lower()
    for keys, label in _FRIENDLY:
        if any(k in n for k in keys):
            return label
    return name


def _num(v) -> float | None:
    try:
        return float(str(v).replace(",", "").strip())
    except (TypeError, ValueError):
        return None


def flag(value, ref: str | None) -> str | None:
    """'high' | 'low' | 'normal' | None (cannot tell)."""
    x = _num(value)
    if x is None or not ref:
        return None
    r = ref.replace("–", "-").replace("—", "-").strip()
    m = re.fullmatch(r"\s*<\s*=?\s*([\d.]+)\s*", r)
    if m:
        return "high" if x > float(m.group(1)) else "normal"
    m = re.fullmatch(r"\s*>\s*=?\s*([\d.]+)\s*", r)
    if m:
        return "low" if x < float(m.group(1)) else "normal"
    m = re.fullmatch(r"\s*([\d.]+)\s*-\s*([\d.]+)\s*", r)
    if m:
        lo, hi = float(m.group(1)), float(m.group(2))
        return "low" if x < lo else "high" if x > hi else "normal"
    return None


def lab_series(records: list[Record]) -> dict[str, list[dict]]:
    """name -> [{date, value, unit, ref, record_id}] oldest first (numeric values only)."""
    series: dict[str, list[dict]] = {}
    labs = sorted(
        (r for r in records if r.type == "lab"),
        key=lambda r: (r.doc_date is None, r.doc_date or date.min),
    )
    for r in labs:
        for lr in (r.data or {}).get("lab_results", []) or []:
            v = _num(lr.get("value"))
            if v is None or not lr.get("name"):
                continue
            series.setdefault(lr["name"], []).append(
                {
                    "date": r.doc_date,
                    "value": v,
                    "unit": lr.get("unit"),
                    "ref": lr.get("ref_range"),
                    "record_id": str(r.id),
                }
            )
    return series


def _short_date(d: date | None) -> str:
    return d.strftime("%d %b") if d else ""


# ----------------------------------------------------------- medicine schedule

_PRN = ("prn", "when needed", "as needed", "sos", "if needed")


def slots(freq: str | None) -> list[str]:
    """Clock times (HH:MM) at which a medicine with this frequency is taken."""
    f = (freq or "").lower()
    if any(k in f for k in _PRN):
        return []
    if any(k in f for k in ("four", "qid", "4 times")):
        return ["08:00", "13:00", "18:00", "22:00"]
    if any(k in f for k in ("thrice", "three", "tds", "tid", "3 times")):
        return ["08:00", "14:00", "20:00"]
    if any(k in f for k in ("twice", "bd", "bid", "2 times", "two")):
        return ["08:00", "20:00"]
    if any(k in f for k in ("night", "hs", "bedtime", "evening")):
        return ["20:00"]
    return ["08:00"]


def _label(hhmm: str) -> str:
    h, m = int(hhmm[:2]), int(hhmm[3:])
    suffix = "am" if h < 12 else "pm"
    return f"{(h % 12) or 12}:{m:02d} {suffix}"


def _time_word(hhmm: str) -> str:
    h = int(hhmm[:2])
    return "Morning" if h < 12 else "Afternoon" if h < 17 else "Night"


def _key(name: str, hhmm: str) -> str:
    return f"med:{rx._norm(name).replace(' ', '-')}:{hhmm}"


def active_plan(plans: list[CarePlan]) -> CarePlan | None:
    live = [p for p in plans if p.active]
    return max(live, key=lambda p: p.created_at) if live else None


def today_items(
    meds: list[dict], plan: CarePlan | None, done_keys: set[str]
) -> list[dict]:
    items: list[dict] = []
    for m in meds:
        for t in slots(m.get("freq")):
            title = f"{m['name']} {m['dose']}".strip() if m.get("dose") else m["name"]
            key = _key(m["name"], t)
            items.append(
                {
                    "key": key,
                    "kind": "medicine",
                    "title": title,
                    "sub": f"{_time_word(t)} · {_label(t)}",
                    "time": t,
                    "done": key in done_keys,
                }
            )
    if plan:
        diet_note = (plan.diet or {}).get("note")
        if diet_note:
            items.append(
                {"key": "diet:0", "kind": "diet", "title": diet_note,
                 "sub": "All day", "time": "12:00", "done": "diet:0" in done_keys}
            )
        for i, a in enumerate(plan.activity or []):
            k = f"act:{i}"
            items.append(
                {"key": k, "kind": "activity", "title": a, "sub": "Today",
                 "time": "19:00", "done": k in done_keys}
            )
    items.sort(key=lambda i: (i["time"], i["title"]))
    return items


def next_medicine(items: list[dict], now: datetime) -> dict | None:
    pending = [i for i in items if i["kind"] == "medicine" and not i["done"]]
    if not pending:
        return None
    nowm = now.hour * 60 + now.minute

    def minutes(i: dict) -> int:
        return int(i["time"][:2]) * 60 + int(i["time"][3:]) - nowm

    upcoming = [i for i in pending if minutes(i) >= -30]
    pick = min(upcoming, key=minutes) if upcoming else max(pending, key=minutes)
    return {
        "key": pick["key"],
        "name": pick["title"],
        "at": _label(pick["time"]),
        "in_minutes": minutes(pick),
    }


# ------------------------------------------------------------ patient content

def reports(records: list[Record], limit: int = 2) -> list[dict]:
    labs = sorted(
        (r for r in records if r.type == "lab"),
        key=lambda r: (r.doc_date is None, r.doc_date or date.min),
        reverse=True,
    )
    out = []
    for r in labs[:limit]:
        results = (r.data or {}).get("lab_results", []) or []
        flags = [flag(x.get("value"), x.get("ref_range")) for x in results]
        level = "high" if "high" in flags else "low" if "low" in flags else (
            "normal" if "normal" in flags else "unknown"
        )
        first = results[0]["name"] if results else "Lab report"
        title = f"{friendly(first).capitalize()} test" if results else "Lab report"
        if friendly(first) == "sugar" and "hba1c" in first.lower():
            title = "Sugar test (HbA1c)"
        out.append(
            {
                "record_id": str(r.id),
                "title": title,
                "sub": " · ".join(x for x in (_short_date(r.doc_date), r.provider) if x),
                "verdict": {"high": "High", "low": "Low", "normal": "All normal",
                            "unknown": "See report"}[level],
                "level": level,
            }
        )
    return out


def plain_summary(records: list[Record], plan: CarePlan | None) -> dict:
    series = lab_series(records)
    rising = None
    for name, pts in series.items():
        if len(pts) < 2 or not (pts[-1]["value"] > pts[-2]["value"]):
            continue
        if flag(pts[-1]["value"], pts[-1]["ref"]) == "high":
            rising = (name, pts)
            break
    follow = ""
    if plan and plan.follow_up_date:
        follow = f" See your doctor on {plan.follow_up_date.strftime('%d %b')}."
    if rising:
        name, pts = rising
        text = (
            f"Your {friendly(name)} has gone up in your last {len(pts)} tests. "
            f"Keep taking your medicines every day.{follow}"
        )
        trend = [{"label": p["date"].strftime("%b") if p["date"] else "",
                  "value": p["value"]} for p in pts[-4:]]
    elif records:
        text = f"Your records look steady. Keep taking your medicines on time.{follow}"
        trend = []
    else:
        text = "Add your first prescription or report to see a summary here."
        trend = []
    return {"text": text, "trend": trend, "unit": rising[1][-1]["unit"] if rising else None}


_TIPS = {
    "diabetes": [
        ("🚶", "Walk 20 minutes after dinner", "Helps keep your sugar down"),
        ("🍵", "Try chai with less sugar", "One spoon less each day"),
        ("💧", "Drink 8 glasses of water", "Keep a bottle with you"),
    ],
    "hypertension": [
        ("🧂", "Use a little less salt", "Taste food before adding salt"),
        ("🚶", "Walk for 20 minutes", "A gentle walk most days"),
        ("💧", "Drink enough water", "Keep a bottle with you"),
    ],
    "general": [
        ("🚶", "Take a short walk today", "Even 10 minutes helps"),
        ("💧", "Drink 8 glasses of water", "Keep a bottle with you"),
        ("😴", "Sleep 7 to 8 hours", "Go to bed at the same time"),
    ],
}


def conditions(records: list[Record]) -> list[str]:
    seen: dict[str, str] = {}
    for r in records:
        for d in (r.data or {}).get("diagnoses", []) or []:
            seen.setdefault(str(d).strip().lower(), str(d).strip())
    return list(seen.values())


def tips(records: list[Record], plan: CarePlan | None) -> list[dict]:
    conds = " ".join(conditions(records)).lower()
    key = "diabetes" if "diabet" in conds else "hypertension" if "hypertens" in conds else "general"
    out = [{"emoji": e, "title": t, "sub": s, "from_doctor": False} for e, t, s in _TIPS[key]]
    if plan:
        for a in (plan.activity or [])[:1]:
            out.insert(0, {"emoji": "👩‍⚕️", "title": a, "sub": "Your doctor's advice",
                           "from_doctor": True})
    return out[:3]


ASKS = [
    "What does my sugar report mean?",
    "What is each medicine for?",
    "What can I eat?",
    "When is my next test?",
]


# ------------------------------------------------------------------ care plan

def plan_view(plan: CarePlan | None, now: datetime) -> dict | None:
    if plan is None:
        return None
    created = plan.created_at.date() if plan.created_at else now.date()
    days = max(0, (now.date() - created).days)
    week = min(PLAN_WEEKS, days // 7 + 1)
    percent = min(100, round(days / (PLAN_WEEKS * 7) * 100))
    events = []
    for t in plan.tests or []:
        d = date.fromisoformat(t["due"]) if t.get("due") else None
        if d:
            events.append({"title": t["name"], "date": d, "kind": "test"})
    if plan.follow_up_date:
        events.append({"title": "Doctor follow-up", "date": plan.follow_up_date, "kind": "visit"})
    events.sort(key=lambda e: e["date"])
    return {
        "week": week,
        "of": PLAN_WEEKS,
        "percent": percent,
        "diet": {
            "note": (plan.diet or {}).get("note"),
            "more": (plan.diet or {}).get("more", []),
            "less": (plan.diet or {}).get("less", []),
        },
        "activity": plan.activity or [],
        "events": [
            {"title": e["title"], "when": e["date"].strftime("%a %d %b"),
             "date": e["date"].isoformat(), "kind": e["kind"]}
            for e in events
        ],
        "follow_up_date": plan.follow_up_date.isoformat() if plan.follow_up_date else None,
        "issued_on": created.isoformat(),
    }


# ---------------------------------------------------------- doctor-side views

def _src(r: Record) -> str:
    kind = {"lab": "Lab", "prescription": "Prescription", "note": "Note",
            "imaging": "Imaging"}.get(r.type, r.type.title())
    return f"{kind} · {_short_date(r.doc_date)}".strip(" ·")


def history_alerts(records: list[Record]) -> list[dict]:
    """Allergies, past medicine reactions, stopped medicines — brought to the doctor."""
    ordered = sorted(
        records, key=lambda r: (r.doc_date is None, r.doc_date or date.min), reverse=True
    )
    alerts: list[dict] = []
    seen: set[tuple[str, str]] = set()

    def add(kind: str, title: str, text: str, r: Record, severity: str) -> None:
        k = (kind, title.lower())
        if k in seen:
            return
        seen.add(k)
        alerts.append(
            {"kind": kind, "severity": severity, "title": title, "text": text,
             "source_record_id": str(r.id), "source_label": _src(r)}
        )

    for r in ordered:
        d = r.data or {}
        for a in d.get("allergies", []) or []:
            add("allergy", str(a), "Documented allergy.", r, "urgent")
        for x in d.get("reactions", []) or []:
            when = f" ({x['date']})" if x.get("date") else ""
            add("reaction", x["drug"], f"{x['effect']}{when}", r, "watch")
        for x in d.get("stopped", []) or []:
            why = f" — {x['reason']}" if x.get("reason") else ""
            when = f" ({x['date']})" if x.get("date") else ""
            add("stopped", f"{x['name']} stopped", f"Stopped{why}{when}", r, "info")
    order = {"urgent": 0, "watch": 1, "info": 2}
    alerts.sort(key=lambda a: order[a["severity"]])
    return alerts


def reaction_checks(records: list[Record], draft: list[dict]) -> list[dict]:
    """Per-line warning when a drafted medicine has a documented past reaction."""
    out = []
    for m in draft:
        n = rx._norm(m.get("name"))
        if not n:
            continue
        for r in records:
            for x in (r.data or {}).get("reactions", []) or []:
                dn = rx._norm(x.get("drug"))
                if dn and (dn in n or n in dn):
                    when = f" ({x['date']})" if x.get("date") else ""
                    out.append(
                        {
                            "kind": "reaction",
                            "severity": "watch",
                            "message": f"{m['name']}: past reaction on record — {x['effect']}{when}. "
                            f"Source: {_src(r)}.",
                            "drugs": [m["name"]],
                        }
                    )
    seen, uniq = set(), []
    for c in out:
        if c["message"] not in seen:
            seen.add(c["message"])
            uniq.append(c)
    return uniq


def trends(records: list[Record], limit: int = 3) -> list[dict]:
    out = []
    for name, pts in lab_series(records).items():
        if len(pts) < 2:
            continue
        last = pts[-1]
        fl = flag(last["value"], last["ref"])
        out.append(
            {
                "name": name,
                "unit": last["unit"],
                "latest": last["value"],
                "flag": fl or "unknown",
                "ref": last["ref"],
                "points": [
                    {"date": p["date"].isoformat() if p["date"] else None, "value": p["value"]}
                    for p in pts
                ],
                "_rank": (fl != "high", fl == "normal", -len(pts)),
            }
        )
    out.sort(key=lambda t: t["_rank"])
    for t in out:
        t.pop("_rank")
    return out[:limit]


def doctor_tips(records: list[Record], meds: list[dict], now: datetime) -> list[dict]:
    """Small, factual nudges derived from the record. Never a prescribing suggestion."""
    out: list[dict] = []
    for name, pts in lab_series(records).items():
        if len(pts) >= 2 and all(b["value"] > a["value"] for a, b in zip(pts, pts[1:], strict=False)):
            last = pts[-1]["date"]
            months = max(0, round((now.date() - last).days / 30)) if last else None
            ago = f" — last test {months} month(s) ago" if months is not None else ""
            out.append({"severity": "watch",
                        "text": f"{name} has risen at every test ({len(pts)} results){ago}."})
    for c in rx.check(records, [dict(m) for m in meds]):
        if c["kind"] == "interaction":
            out.append({"severity": c["severity"], "text": c["message"]})
    for c in reaction_checks(records, meds):
        out.append({"severity": "watch", "text": c["message"]})
    return out[:5]


def adherence(meds: list[dict], plan: CarePlan | None, logs: list[CareLog]) -> list[dict]:
    """Last 7 days: done vs expected, by kind (medicine / activity / diet)."""
    per_day_meds = sum(len(slots(m.get("freq"))) for m in meds)
    expected = {
        "medicine": per_day_meds * 7,
        "activity": len((plan.activity or []) if plan else []) * 7,
        "diet": 7 if plan and (plan.diet or {}).get("note") else 0,
    }
    done = {"medicine": 0, "activity": 0, "diet": 0}
    for lg in logs:
        if not lg.done:
            continue
        kind = ("medicine" if lg.item_key.startswith("med:")
                else "activity" if lg.item_key.startswith("act:") else "diet")
        done[kind] += 1
    label = {"medicine": "Medicines taken", "activity": "Activity done", "diet": "Diet followed"}
    return [
        {"label": label[k], "done": min(done[k], expected[k]), "total": expected[k]}
        for k in ("medicine", "activity", "diet") if expected[k]
    ]


def visits(records: list[Record], limit: int = 3) -> list[dict]:
    rows = sorted(
        (r for r in records if r.type in ("prescription", "note")),
        key=lambda r: (r.doc_date is None, r.doc_date or date.min),
        reverse=True,
    )
    return [
        {"date": r.doc_date.isoformat() if r.doc_date else None,
         "text": f"{r.provider or 'Clinic'} · {'Prescription' if r.type == 'prescription' else 'Note'}"}
        for r in rows[:limit]
    ]


def record_title(r: Record) -> str:
    d = r.data or {}
    if r.type == "lab":
        names = [x.get("name") for x in d.get("lab_results", []) or [] if x.get("name")]
        return f"{names[0]} · Lab report" if names else "Lab report"
    if r.type == "prescription":
        n = len(d.get("medications", []) or [])
        return f"Prescription · {n} medicine{'s' if n != 1 else ''}"
    return {"imaging": "Imaging", "note": "Clinic note"}.get(r.type, r.type.title())


# ------------------------------------------------------- grounded patient Q&A

def answer_patient(records: list[Record], plan: CarePlan | None, question: str) -> dict:
    """Offline, grounded answer built only from the patient's own confirmed records."""
    q = question.lower()
    meds = rx.current_medications(records)
    if re.search(r"medicine|tablet|dawa|medication|pill", q):
        if not meds:
            return {"answer": "I can't see any medicines in your records yet.",
                    "answered_from_records": False, "source_record_ids": []}
        lines = "; ".join(
            f"{m['name']}" + (f" {m['dose']}" if m.get("dose") else "")
            + (f" ({m['freq']})" if m.get("freq") else "")
            for m in meds
        )
        return {
            "answer": f"Your records list: {lines}. Ask your doctor what each one is for.",
            "answered_from_records": True,
            "source_record_ids": sorted({m["source_record_id"] for m in meds}),
        }
    if re.search(r"sugar|hba1c|report|test result|cholesterol|kidney", q):
        s = plain_summary(records, plan)
        labs = reports(records, 1)
        return {
            "answer": s["text"],
            "answered_from_records": bool(labs),
            "source_record_ids": [x["record_id"] for x in labs],
        }
    if re.search(r"eat|diet|food|khana|chai", q):
        d = (plan.diet if plan else None) or {}
        if d.get("note"):
            more = ", ".join(d.get("more", [])[:4])
            less = ", ".join(d.get("less", [])[:4])
            return {
                "answer": f"Your doctor advised: {d['note']}. Eat more: {more}. Eat less: {less}.",
                "answered_from_records": True,
                "source_record_ids": [str(plan.record_id)] if plan and plan.record_id else [],
            }
        return {"answer": "Your doctor has not added diet advice yet. Please ask at your next visit.",
                "answered_from_records": False, "source_record_ids": []}
    if re.search(r"next test|follow|appointment|when", q):
        view = plan_view(plan, local_now()) if plan else None
        if view and view["events"]:
            e = view["events"][0]
            return {"answer": f"Next: {e['title']} on {e['when']}.",
                    "answered_from_records": True,
                    "source_record_ids": [str(plan.record_id)] if plan and plan.record_id else []}
        return {"answer": "I don't see an upcoming test or visit in your plan.",
                "answered_from_records": False, "source_record_ids": []}
    return {
        "answer": "I can only answer from your own records. Try asking about your reports, "
        "medicines, diet or next test - or ask your doctor.",
        "answered_from_records": False,
        "source_record_ids": [],
    }


def lab_rows(records: list[Record], limit: int = 6) -> list[dict]:
    """Newest lab values first, flattened for a results table."""
    rows: list[dict] = []
    labs = sorted(
        (r for r in records if r.type == "lab"),
        key=lambda r: (r.doc_date is None, r.doc_date or date.min),
        reverse=True,
    )
    for r in labs:
        for x in (r.data or {}).get("lab_results", []) or []:
            if not x.get("name"):
                continue
            rows.append(
                {
                    "name": x["name"],
                    "value": str(x.get("value") or ""),
                    "unit": x.get("unit"),
                    "ref": x.get("ref_range"),
                    "flag": flag(x.get("value"), x.get("ref_range")) or "unknown",
                    "date": r.doc_date.strftime("%d %b %Y") if r.doc_date else None,
                    "record_id": str(r.id),
                }
            )
    return rows[:limit]


def lab_test_count(records: list[Record]) -> int:
    return sum(len((r.data or {}).get("lab_results", []) or []) for r in records if r.type == "lab")


def record_summary(r: Record) -> str | None:
    """One line describing a record, for the timeline."""
    d = r.data or {}
    if r.type == "lab":
        res = (d.get("lab_results") or [None])[0]
        if res:
            fl = flag(res.get("value"), res.get("ref_range"))
            tail = f" ({fl.capitalize()})" if fl and fl != "normal" else ""
            return f"Result: {res.get('value', '')} {res.get('unit') or ''}{tail}".strip()
    if r.type == "prescription":
        names = [m.get("name") for m in d.get("medications", []) or [] if m.get("name")]
        if names:
            return ", ".join(names)
    return d.get("notes") or ", ".join(d.get("diagnoses", []) or []) or None
