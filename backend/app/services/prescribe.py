"""Deterministic prescribing assistant.

Two rule-based helpers, no model call:
  * candidates()   — the patient's current medications, taken straight from their
    own prescription records. The assistant never proposes a drug that is not
    already documented for this patient.
  * check()        — allergy / interaction / duplicate-therapy checks on a draft.
"""

from __future__ import annotations

from app.models import Record

# --- small curated drug-class map (lowercase substring match on the drug name) ---

CLASSES: dict[str, set[str]] = {
    "penicillin": {
        "penicillin", "amoxicillin", "ampicillin", "flucloxacillin", "co-amoxiclav",
        "augmentin", "piperacillin", "benzylpenicillin", "cloxacillin",
    },
    "cephalosporin": {"cephalexin", "cefuroxime", "ceftriaxone", "cefixime", "cefaclor"},
    "nsaid": {
        "ibuprofen", "naproxen", "diclofenac", "ketorolac", "aspirin", "mefenamic",
        "indomethacin", "celecoxib", "etoricoxib", "piroxicam",
    },
    "ace_inhibitor": {
        "ramipril", "lisinopril", "enalapril", "perindopril", "captopril", "quinapril",
        "trandolapril",
    },
    "arb": {"losartan", "valsartan", "candesartan", "irbesartan", "telmisartan", "olmesartan"},
    "potassium_sparing": {"spironolactone", "amiloride", "eplerenone", "triamterene"},
    "anticoagulant": {
        "warfarin", "apixaban", "rivaroxaban", "dabigatran", "edoxaban", "heparin",
        "enoxaparin",
    },
    "sulfonylurea": {"gliclazide", "glimepiride", "glibenclamide", "glipizide", "glyburide"},
    "biguanide": {"metformin"},
    "statin": {"atorvastatin", "simvastatin", "rosuvastatin", "pravastatin", "lovastatin"},
    "macrolide": {"erythromycin", "clarithromycin", "azithromycin"},
    "loop_diuretic": {"furosemide", "bumetanide", "torasemide"},
}

# class-pair interactions: (class_a, class_b, severity, message)
INTERACTIONS: list[tuple[str, str, str, str]] = [
    ("nsaid", "ace_inhibitor", "watch",
     "NSAID + ACE inhibitor: acute kidney injury risk and reduced BP control. "
     "Check renal function."),
    ("nsaid", "arb", "watch",
     "NSAID + ARB: renal risk and reduced BP control. Check renal function."),
    ("nsaid", "anticoagulant", "urgent", "NSAID + anticoagulant: increased bleeding risk."),
    ("nsaid", "loop_diuretic", "watch", "NSAID blunts loop-diuretic effect; renal risk."),
    ("ace_inhibitor", "potassium_sparing", "watch",
     "ACE inhibitor + potassium-sparing diuretic: hyperkalaemia risk."),
    ("arb", "potassium_sparing", "watch",
     "ARB + potassium-sparing diuretic: hyperkalaemia risk."),
    ("ace_inhibitor", "arb", "watch",
     "ACE inhibitor + ARB: dual RAAS blockade is not generally recommended."),
    ("macrolide", "statin", "watch",
     "Macrolide + statin: raised myopathy/rhabdomyolysis risk."),
    ("macrolide", "anticoagulant", "watch", "Macrolide can potentiate warfarin."),
]

DUPLICATE_CLASSES = {
    "nsaid", "ace_inhibitor", "arb", "sulfonylurea", "biguanide", "statin",
    "anticoagulant", "penicillin",
}


def _norm(s: str | None) -> str:
    return (s or "").strip().lower()


def classes_of(name: str) -> set[str]:
    n = _norm(name)
    out: set[str] = set()
    for cls, members in CLASSES.items():
        if any(m in n or n in m for m in members) or cls in n:
            out.add(cls)
    return out


def _med_dict(m: dict) -> dict:
    return {
        "name": m.get("name", ""),
        "dose": m.get("dose"),
        "route": m.get("route"),
        "freq": m.get("freq"),
    }


def current_medications(records: list[Record]) -> list[dict]:
    """Deduped current meds from the patient's prescription records, newest first."""
    seen: set[str] = set()
    out: list[dict] = []
    rx = sorted(
        (r for r in records if r.type == "prescription"),
        key=lambda r: (r.doc_date is None, r.doc_date),
        reverse=True,
    )
    for r in rx:
        for m in (r.data or {}).get("medications", []) or []:
            key = _norm(m.get("name"))
            if not key or key in seen:
                continue
            seen.add(key)
            out.append(
                {
                    **_med_dict(m),
                    "source_record_id": str(r.id),
                    "source_date": r.doc_date.isoformat() if r.doc_date else None,
                }
            )
    return out


def known_allergies(records: list[Record]) -> list[str]:
    allergies: set[str] = set()
    for r in records:
        for a in (r.data or {}).get("allergies", []) or []:
            allergies.add(str(a))
    return sorted(allergies)


def candidate_names(records: list[Record]) -> set[str]:
    return {_norm(m["name"]) for m in current_medications(records)}


def check(records: list[Record], draft: list[dict]) -> list[dict]:
    """allergy / interaction / duplicate checks for a draft med list."""
    checks: list[dict] = []
    allergies = known_allergies(records)
    current = current_medications(records)
    draft_named = [m for m in draft if _norm(m.get("name"))]

    # allergy
    for m in draft_named:
        d_classes = classes_of(m["name"])
        for a in allergies:
            a_classes = classes_of(a)
            hit = (
                (_norm(a) in _norm(m["name"]))
                or (_norm(m["name"]) in _norm(a))
                or bool(d_classes & a_classes)
            )
            if hit:
                checks.append(
                    {
                        "kind": "allergy",
                        "severity": "urgent",
                        "message": f"{m['name']} conflicts with a recorded allergy to {a}.",
                        "drugs": [m["name"]],
                    }
                )

    # interactions: draft x draft, and draft x current
    pool = [(m["name"], "draft") for m in draft_named] + [
        (c["name"], "current") for c in current
    ]
    for i in range(len(pool)):
        for j in range(i + 1, len(pool)):
            (na, sa_), (nb, sb) = pool[i], pool[j]
            if sa_ == "current" and sb == "current":
                continue  # not something this prescription introduces
            ca, cb = classes_of(na), classes_of(nb)
            for x, y, sev, msg in INTERACTIONS:
                if (x in ca and y in cb) or (x in cb and y in ca):
                    where = "" if sa_ == sb == "draft" else " (one is already on the record)"
                    checks.append(
                        {
                            "kind": "interaction",
                            "severity": sev,
                            "message": f"{msg}{where}",
                            "drugs": sorted({na, nb}),
                        }
                    )

    # duplicate therapy vs current
    cur_by_name = {_norm(c["name"]): c for c in current}
    for m in draft_named:
        nm = _norm(m["name"])
        if nm in cur_by_name:
            c = cur_by_name[nm]
            checks.append(
                {
                    "kind": "duplicate",
                    "severity": "info",
                    "message": f"Continues existing {m['name']}"
                    + (f" (from {c['source_date']})" if c["source_date"] else "")
                    + ".",
                    "drugs": [m["name"]],
                }
            )
            continue
        d_classes = {c for c in classes_of(m["name"]) if c in DUPLICATE_CLASSES}
        for c in current:
            if d_classes & classes_of(c["name"]):
                checks.append(
                    {
                        "kind": "duplicate",
                        "severity": "watch",
                        "message": f"{m['name']} is the same class as existing {c['name']} "
                        f"({', '.join(sorted(d_classes))}). Confirm this is intended.",
                        "drugs": sorted({m["name"], c["name"]}),
                    }
                )
                break

    # de-dupe identical messages
    uniq: list[dict] = []
    seen_msg: set[str] = set()
    for c in checks:
        if c["message"] in seen_msg:
            continue
        seen_msg.add(c["message"])
        uniq.append(c)
    order = {"urgent": 0, "watch": 1, "info": 2}
    uniq.sort(key=lambda c: order.get(c["severity"], 3))
    return uniq
