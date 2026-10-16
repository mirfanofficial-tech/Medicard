"""Turn a doctor's dictated text into a structured draft (note + medicine lines + advice).

Deterministic and offline. It only *formats what the doctor said*; it never adds a
medicine, a dose or advice that was not spoken. The doctor reviews every field
before anything is saved.
"""

from __future__ import annotations

import re

from app.services.prescribe import CLASSES

_EXTRA_DRUGS = {
    "paracetamol", "panadol", "omeprazole", "pantoprazole", "esomeprazole", "amlodipine",
    "insulin", "salbutamol", "cetirizine", "loratadine", "montelukast", "levothyroxine",
    "prednisolone", "ciprofloxacin", "levofloxacin", "metronidazole", "domperidone",
    "bisoprolol", "atenolol", "metoprolol", "clopidogrel", "sitagliptin", "empagliflozin",
}
DRUGS: set[str] = {m for members in CLASSES.values() for m in members} | _EXTRA_DRUGS

_ONES = {
    "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
    "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "fifteen": 15,
    "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "ninety": 90,
}
_SCALE = {"hundred": 100, "thousand": 1000}


def words_to_number(tokens: list[str]) -> float | None:
    """'five hundred' -> 500, 'two hundred fifty' -> 250, '500' -> 500."""
    total, cur, seen = 0.0, 0.0, False
    for t in tokens:
        if re.fullmatch(r"\d+(\.\d+)?", t):
            cur += float(t)
            seen = True
        elif t in _ONES:
            cur += _ONES[t]
            seen = True
        elif t in _SCALE:
            cur = (cur or 1) * _SCALE[t]
            if _SCALE[t] >= 1000:
                total += cur
                cur = 0
            seen = True
        else:
            break
    if not seen:
        return None
    return total + cur


def _fmt(n: float) -> str:
    return str(int(n)) if float(n).is_integer() else str(n)


_NUMWORD = r"(?:\d+(?:\.\d+)?|" + "|".join(sorted([*_ONES, *_SCALE], key=len, reverse=True)) + ")"
_NUMSEQ = rf"{_NUMWORD}(?:[\s-]+{_NUMWORD})*"

_FREQ = [
    (r"\b(?:four times|qid)\b", "Four times daily"),
    (r"\b(?:thrice|three times|tds|tid)\b(?:\s+(?:a\s+)?(?:daily|day))?", "Three times daily"),
    (r"\b(?:twice|two times|bd|bid)\b(?:\s+(?:a\s+)?(?:daily|day))?", "Twice daily"),
    (r"\b(?:once|one time|od)\b(?:\s+(?:a\s+)?(?:daily|day))?", "Once daily"),
    (r"\b(?:at night|bedtime|hs)\b", "At night"),
    (r"\b(?:when needed|as needed|prn|sos|if needed)\b", "When needed"),
    (r"\bdaily\b", "Once daily"),
]


def _tokens(sentence: str) -> list[str]:
    return re.findall(r"[a-z0-9\.\-]+", sentence.lower())


def parse_medicines(text: str) -> list[dict]:
    meds: list[dict] = []
    flat = re.sub(r"\s+", " ", text.lower())
    # Split into segments that each start at a known drug name or "<word> <dose> mg".
    pat = re.compile(
        rf"\b({'|'.join(sorted(map(re.escape, DRUGS), key=len, reverse=True))})\b"
        rf"|\b([a-z]{{4,}})\b(?=\s+{_NUMSEQ}\s*(?:mg|milligrams?|mcg|ml)\b)"
    )
    starts = [(m.start(), m.group(1) or m.group(2)) for m in pat.finditer(flat)]
    for i, (pos, name) in enumerate(starts):
        end = starts[i + 1][0] if i + 1 < len(starts) else len(flat)
        seg = flat[pos + len(name):end]
        seg = re.split(r"[.;]| (?:low|walk|review|follow|repeat|advise|diet)\b", seg)[0]
        dose = None
        m = re.search(rf"({_NUMSEQ})\s*(mg|milligrams?|mcg|micrograms?|ml|units?|iu)?\b", seg)
        if m:
            val = words_to_number(m.group(1).replace("-", " ").split())
            unit = (m.group(2) or "mg").lower()
            unit = {"milligram": "mg", "milligrams": "mg", "microgram": "mcg",
                    "micrograms": "mcg", "unit": "units"}.get(unit, unit)
            if val is not None:
                dose = f"{_fmt(val)} {unit}"
        freq = None
        for rgx, label in _FREQ:
            fm = re.search(rgx, seg)
            if fm:
                freq = label
                if "after food" in seg or "after meals" in seg:
                    freq += ", after food"
                break
        days = None
        dm = re.search(rf"for\s+({_NUMSEQ})\s*(day|days|week|weeks|month|months)\b", seg)
        if dm:
            n = words_to_number(dm.group(1).replace("-", " ").split())
            if n is not None:
                unit = dm.group(2).rstrip("s")
                days = f"{_fmt(n)} {unit}{'' if n == 1 else 's'}"
        meds.append({"name": name.capitalize(), "dose": dose, "freq": freq, "days": days})
    return meds


_DIET_PRESETS = {
    "sugar": {
        "note": "Low-sugar diet",
        "more": ["Daal and sabzi", "Salad", "Daliya", "Plain yogurt"],
        "less": ["Sugar in chai", "Mithai", "Fried food", "Cold drinks"],
    },
    "salt": {
        "note": "Low-salt diet",
        "more": ["Fresh fruit and vegetables", "Home-cooked food"],
        "less": ["Extra salt on food", "Pickles and chips", "Salty snacks"],
    },
}


def parse_advice(text: str) -> dict:
    t = re.sub(r"\s+", " ", text.lower())
    diet = None
    if re.search(r"low[\s-]*sugar|diabetic diet|less sugar", t):
        diet = _DIET_PRESETS["sugar"]
    elif re.search(r"low[\s-]*salt|less salt", t):
        diet = _DIET_PRESETS["salt"]

    activity: list[str] = []
    wm = re.search(rf"walk(?:ing)?(?:\s+for)?\s+({_NUMSEQ})\s*(?:minutes?|mins?)", t)
    if wm:
        n = words_to_number(wm.group(1).replace("-", " ").split())
        if n:
            activity.append(f"Walk {_fmt(n)} minutes")
    elif re.search(r"\bwalk", t):
        activity.append("Walk daily")

    tests: list[dict] = []
    for tm in re.finditer(
        rf"(?:repeat|recheck|test)\s+([a-z0-9]+)\s+in\s+({_NUMSEQ})\s*(weeks?|months?|days?)", t
    ):
        n = words_to_number(tm.group(2).replace("-", " ").split())
        if n:
            unit = tm.group(3)
            days = int(n * (7 if unit.startswith("week") else 30 if unit.startswith("month") else 1))
            name = tm.group(1)
            name = "HbA1c" if name == "hba1c" else name.capitalize()
            tests.append({"name": f"{name} test", "in_days": days})

    follow = None
    fm = re.search(
        rf"(?:review|follow[\s-]*up|see (?:me|you))\s+(?:in|after)\s+({_NUMSEQ})\s*(weeks?|days?|months?)",
        t,
    )
    if fm:
        n = words_to_number(fm.group(1).replace("-", " ").split())
        if n:
            unit = fm.group(2)
            follow = int(n * (7 if unit.startswith("week") else 30 if unit.startswith("month") else 1))

    return {"diet": diet, "activity": activity, "tests": tests, "follow_up_days": follow}


_COMPLAINT = re.compile(r"\b(reports?|complains?|complaint|since|for (?:the )?(?:last )?\w+ (?:days?|weeks?)|"
                        r"pain|thirst|tired|fever|cough)\b")
_PLAN = re.compile(r"\b(advise|advice|plan|review|follow|repeat|diet|walk|start|continue)\b")


def parse_note(text: str) -> dict:
    complaint, assessment, plan = [], [], []
    for s in re.split(r"(?<=[.!?])\s+|\n+", text.strip()):
        s = s.strip()
        if not s:
            continue
        low = s.lower()
        if any(d in low.split() or d in re.findall(r"[a-z]+", low) for d in DRUGS):
            continue  # medicine lines go to the prescription, not the visit note
        if _PLAN.search(low) and not _COMPLAINT.search(low):
            plan.append(s)
        elif _COMPLAINT.search(low):
            complaint.append(s)
        else:
            assessment.append(s)
    j = lambda xs: " ".join(xs) or None  # noqa: E731
    return {"complaint": j(complaint), "assessment": j(assessment), "plan": j(plan)}


def parse(text: str) -> dict:
    return {
        "note": parse_note(text),
        "medications": parse_medicines(text),
        "advice": parse_advice(text),
    }
