import pytest

from app.services import voice
from tests.helpers import PNG, auth, doctor_signup, patient_signup


async def _record(client, token, data, rtype="prescription", date="2026-05-10"):
    rid = (
        await client.post(
            "/records/upload", headers=auth(token), files={"file": ("x.png", PNG, "image/png")}
        )
    ).json()["record_id"]
    await client.post(f"/records/{rid}/extract", headers=auth(token))
    r = await client.post(
        f"/records/{rid}/confirm",
        headers=auth(token),
        json={"type": rtype, "doc_date": date, "provider": "City Clinic", "data": data},
    )
    assert r.status_code == 200, r.text
    return rid


RX = {
    "diagnoses": ["Type 2 diabetes mellitus"],
    "medications": [
        {"name": "Metformin", "dose": "500 mg", "freq": "twice daily"},
        {"name": "Ramipril", "dose": "5 mg", "freq": "once daily, at night"},
        {"name": "Ibuprofen", "dose": "400 mg", "freq": "as needed"},
    ],
    "lab_results": [],
    "allergies": ["Penicillin"],
    "reactions": [{"drug": "Ibuprofen", "effect": "Stomach pain", "date": "Aug 2025"}],
    "stopped": [{"name": "Amlodipine", "reason": "Ankle swelling", "date": "2025"}],
}


def _lab(value, date):
    return {
        "diagnoses": [], "medications": [], "allergies": [],
        "lab_results": [{"name": "HbA1c", "value": value, "unit": "%", "ref_range": "<7"}],
    }, date


async def _granted(client, phone="+923006000001"):
    doc = await doctor_signup(client)
    pat = await patient_signup(client, phone, name="Ayesha Khan")
    await _record(client, pat["token"], RX)
    for v, d in (("7.4", "2026-02-10"), ("8.1", "2026-05-12"), ("8.6", "2026-08-20")):
        data, date = _lab(v, d)
        await _record(client, pat["token"], data, rtype="lab", date=date)
    req = await client.post(
        "/doctor/access-requests",
        headers=auth(doc["token"]),
        json={"medicard_code": pat["code"]},
    )
    await client.post(
        f"/patient/access-requests/{req.json()['request_id']}/approve",
        headers=auth(pat["token"]),
    )
    return doc, pat


def test_voice_parser_structures_only_what_was_said():
    out = voice.parse(
        "Metformin five hundred twice daily for thirty days, Ramipril five milligram once daily. "
        "Low sugar diet, walk twenty minutes, review in two weeks. Repeat HbA1c in six weeks."
    )
    meds = {m["name"]: m for m in out["medications"]}
    assert meds["Metformin"]["dose"] == "500 mg"
    assert meds["Metformin"]["freq"] == "Twice daily"
    assert meds["Metformin"]["days"] == "30 days"
    assert meds["Ramipril"]["dose"] == "5 mg"
    assert set(meds) == {"Metformin", "Ramipril"}  # nothing invented
    assert out["advice"]["activity"] == ["Walk 20 minutes"]
    assert out["advice"]["follow_up_days"] == 14
    assert out["advice"]["tests"][0]["in_days"] == 42


@pytest.mark.asyncio
async def test_voice_parse_endpoint_is_doctor_only(client):
    pat = await patient_signup(client, "+923006000009")
    r = await client.post(
        "/doctor/voice/parse", headers=auth(pat["token"]), json={"text": "Metformin 500 daily"}
    )
    assert r.status_code in (401, 403)
    doc = await doctor_signup(client)
    r = await client.post(
        "/doctor/voice/parse",
        headers=auth(doc["token"]),
        json={"text": "Metformin 500 mg twice daily"},
    )
    assert r.status_code == 200
    assert r.json()["medications"][0]["name"] == "Metformin"


@pytest.mark.asyncio
async def test_patient_home_and_daily_ticks(client):
    _, pat = await _granted(client)
    h = (await client.get("/patient/home", headers=auth(pat["token"]))).json()
    assert h["next_medicine"] is not None
    assert h["summary"]["text"].startswith("Your sugar has gone up")
    assert [r["verdict"] for r in h["reports"]] == ["High", "High"]
    assert h["more_reports"] is True
    # as-needed ibuprofen gets no daily slot
    assert not any("Ibuprofen" in i["title"] for i in h["today"]["items"])
    first = h["today"]["items"][0]
    assert first["done"] is False

    t = (
        await client.post(
            "/patient/care/log",
            headers=auth(pat["token"]),
            json={"item_key": first["key"], "done": True},
        )
    ).json()
    assert t["done"] == 1
    bad = await client.post(
        "/patient/care/log", headers=auth(pat["token"]), json={"item_key": "evil:key"}
    )
    assert bad.status_code == 422


@pytest.mark.asyncio
async def test_patient_ask_is_grounded(client):
    _, pat = await _granted(client)
    ok = (
        await client.post(
            "/patient/ask",
            headers=auth(pat["token"]),
            json={"question": "What is each medicine for?"},
        )
    ).json()
    assert ok["answered_from_records"] is True and "Metformin" in ok["answer"]
    off = (
        await client.post(
            "/patient/ask",
            headers=auth(pat["token"]),
            json={"question": "Will it rain tomorrow?"},
        )
    ).json()
    assert off["answered_from_records"] is False


@pytest.mark.asyncio
async def test_overview_surfaces_history_and_needs_grant(client):
    doc = await doctor_signup(client, "nogrant@example.com")
    pat0 = await patient_signup(client, "+923006000002")
    r = await client.get(
        f"/doctor/patients/{pat0['patient_id']}/overview", headers=auth(doc["token"])
    )
    assert r.status_code == 403

    doc, pat = await _granted(client, "+923006000003")
    o = (
        await client.get(
            f"/doctor/patients/{pat['patient_id']}/overview", headers=auth(doc["token"])
        )
    ).json()
    kinds = {(a["kind"], a["title"]) for a in o["history_alerts"]}
    assert ("allergy", "Penicillin") in kinds
    assert ("reaction", "Ibuprofen") in kinds
    assert any(k == "stopped" for k, _ in kinds)
    assert all(a["source_record_id"] for a in o["history_alerts"])
    assert o["trends"][0]["name"] == "HbA1c" and o["trends"][0]["flag"] == "high"
    assert any("risen at every test" in t["text"] for t in o["tips"])
    assert o["conditions"] == ["Type 2 diabetes mellitus"]
    assert o["counts"]["lab_tests"] == 3 and o["counts"]["documents"] == 4
    assert o["latest_labs"][0]["name"] == "HbA1c" and o["latest_labs"][0]["flag"] == "high"
    assert o["phone"] and o["registered_on"]
    assert any(r["summary"] for r in o["records"])


@pytest.mark.asyncio
async def test_prescribe_with_advice_creates_care_plan_and_warns_on_past_reaction(client):
    doc, pat = await _granted(client, "+923006000004")
    pid = pat["patient_id"]

    chk = (
        await client.post(
            f"/doctor/patients/{pid}/prescribe/check",
            headers=auth(doc["token"]),
            json={"medications": [{"name": "Ibuprofen", "dose": "400 mg"}]},
        )
    ).json()
    assert any(c["kind"] == "reaction" for c in chk["checks"])

    parsed = voice.parse(
        "Metformin 500 mg twice daily for 30 days. Low sugar diet, walk 20 minutes, "
        "review in two weeks."
    )
    r = await client.post(
        f"/doctor/patients/{pid}/prescribe",
        headers=auth(doc["token"]),
        json={
            "medications": [
                {"name": "Metformin", "dose": "500 mg", "freq": "Twice daily", "days": "30 days",
                 "origin": "history"}
            ],
            "advice": parsed["advice"],
        },
    )
    assert r.status_code == 201, r.text
    assert r.json()["care_plan_created"] is True

    plan = (await client.get("/patient/care-plan", headers=auth(pat["token"]))).json()
    assert plan["has_plan"] is True
    assert plan["diet"]["note"] == "Low-sugar diet"
    assert plan["activity"] == ["Walk 20 minutes"]
    assert plan["follow_up"]["date"]
    assert plan["issued_by"] == "Dr Ahmed"


@pytest.mark.asyncio
async def test_doctor_dashboard_counts_and_alerts(client):
    doc, pat = await _granted(client, "+923006000007")
    d = (await client.get("/doctor/dashboard", headers=auth(doc["token"]))).json()
    assert d["stats"]["active_access"] == 1
    assert d["active"][0]["patient_name"] == "Ayesha Khan"
    assert any("Allergy" in a["text"] for a in d["active"][0]["alerts"])
    assert len(d["week"]) == 7
    assert any(a["action"] == "grant" for a in d["activity"])

    other = await patient_signup(client, "+923006000008", name="Zed")
    await client.post(
        "/doctor/access-requests",
        headers=auth(doc["token"]),
        json={"medicard_code": other["code"]},
    )
    d = (await client.get("/doctor/dashboard", headers=auth(doc["token"]))).json()
    assert d["stats"]["pending_requests"] == 1
    assert d["pending"][0]["patient_name"] == "Zed"

    nodoc = await doctor_signup(client, "pending@example.com", activate=False)
    r = await client.get("/doctor/dashboard", headers=auth(nodoc["token"]))
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_stopped_medicine_is_not_current(client):
    pat = await patient_signup(client, "+923006000011")
    await _record(
        client, pat["token"],
        {"medications": [{"name": "Amlodipine", "dose": "5 mg", "freq": "once daily"}],
         "diagnoses": [], "lab_results": [], "allergies": []},
        date="2026-01-01",
    )
    await _record(
        client, pat["token"],
        {"medications": [{"name": "Ramipril", "dose": "5 mg", "freq": "once daily"}],
         "stopped": [{"name": "Amlodipine", "reason": "Ankle swelling", "date": "2026"}],
         "diagnoses": [], "lab_results": [], "allergies": []},
        date="2026-06-01",
    )
    meds = (await client.get("/patient/medications", headers=auth(pat["token"]))).json()
    assert [m["name"] for m in meds] == ["Ramipril"]
