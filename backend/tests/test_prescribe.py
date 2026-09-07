import pytest

from tests.helpers import add_record, auth, doctor_signup, patient_signup


async def _granted(client, phone="+923005000001"):
    doc = await doctor_signup(client)
    pat = await patient_signup(client, phone, name="Ayesha Khan")
    await add_record(client, pat["token"])  # stub Rx: Metformin, Ramipril, Penicillin allergy
    r = await client.post(
        "/doctor/access-requests",
        headers=auth(doc["token"]),
        json={"medicard_code": pat["code"]},
    )
    req_id = r.json()["request_id"]
    await client.post(f"/patient/access-requests/{req_id}/approve", headers=auth(pat["token"]))
    return doc, pat


@pytest.mark.asyncio
async def test_context_needs_grant(client):
    doc = await doctor_signup(client)
    pat = await patient_signup(client, "+923005000002")
    r = await client.get(
        f"/doctor/patients/{pat['patient_id']}/prescribe/context", headers=auth(doc["token"])
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_context_lists_only_documented_meds(client):
    doc, pat = await _granted(client)
    r = await client.get(
        f"/doctor/patients/{pat['patient_id']}/prescribe/context", headers=auth(doc["token"])
    )
    assert r.status_code == 200, r.text
    body = r.json()
    names = {c["name"] for c in body["candidates"]}
    assert {"Metformin", "Ramipril"}.issubset(names)
    assert body["known_allergies"] == ["Penicillin"]
    assert all(c["source_record_id"] for c in body["candidates"])


@pytest.mark.asyncio
async def test_check_flags_allergy_interaction_duplicate(client):
    doc, pat = await _granted(client)
    pid = pat["patient_id"]

    # amoxicillin -> penicillin-class allergy conflict
    r = await client.post(
        f"/doctor/patients/{pid}/prescribe/check",
        headers=auth(doc["token"]),
        json={"medications": [{"name": "Amoxicillin", "dose": "500 mg", "freq": "TDS"}]},
    )
    kinds = {(c["kind"], c["severity"]) for c in r.json()["checks"]}
    assert ("allergy", "urgent") in kinds

    # ibuprofen interacts with the ramipril already on record
    r = await client.post(
        f"/doctor/patients/{pid}/prescribe/check",
        headers=auth(doc["token"]),
        json={"medications": [{"name": "Ibuprofen", "dose": "400 mg", "freq": "PRN"}]},
    )
    msgs = " ".join(c["message"] for c in r.json()["checks"] if c["kind"] == "interaction")
    assert "ACE inhibitor" in msgs

    # metformin duplicates existing therapy
    r = await client.post(
        f"/doctor/patients/{pid}/prescribe/check",
        headers=auth(doc["token"]),
        json={"medications": [{"name": "Metformin", "dose": "1000 mg", "freq": "BD"}]},
    )
    assert any(c["kind"] == "duplicate" for c in r.json()["checks"])


@pytest.mark.asyncio
async def test_create_prescription_lands_on_both_timelines_and_is_audited(client):
    doc, pat = await _granted(client)
    pid = pat["patient_id"]

    r = await client.post(
        f"/doctor/patients/{pid}/prescribe",
        headers=auth(doc["token"]),
        json={
            "medications": [
                {"name": "Metformin", "dose": "1000 mg", "freq": "BD", "origin": "history"},
                {"name": "Amlodipine", "dose": "5 mg", "freq": "OD", "origin": "manual"},
            ],
            "notes": "BP still high; adding amlodipine.",
        },
    )
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["record"]["verified"] is True
    assert body["record"]["type"] == "prescription"
    assert "Dr Ahmed" in body["record"]["provider"]

    # patient sees it
    tl = (await client.get("/records", headers=auth(pat["token"]))).json()
    assert any(x["provider"] and "Dr Ahmed" in x["provider"] for x in tl)

    # doctor sees it under the grant
    dtl = (
        await client.get(f"/doctor/patients/{pid}/records", headers=auth(doc["token"]))
    ).json()
    assert any("Dr Ahmed" in (x["provider"] or "") for x in dtl)

    hist = (await client.get("/patient/access-history", headers=auth(pat["token"]))).json()
    assert "prescribe" in [h["action"] for h in hist]


@pytest.mark.asyncio
async def test_create_rejects_history_line_not_in_record(client):
    doc, pat = await _granted(client)
    r = await client.post(
        f"/doctor/patients/{pat['patient_id']}/prescribe",
        headers=auth(doc["token"]),
        json={"medications": [{"name": "Empagliflozin", "dose": "10 mg", "origin": "history"}]},
    )
    assert r.status_code == 422
    assert "not documented" in r.text


@pytest.mark.asyncio
async def test_break_glass_scope_cannot_prescribe(client):
    doc = await doctor_signup(client)
    pat = await patient_signup(client, "+923005000009")
    await add_record(client, pat["token"])
    await client.post(
        "/doctor/break-glass",
        headers=auth(doc["token"]),
        json={"medicard_code": pat["code"], "reason": "Unconscious in ED"},
    )
    r = await client.post(
        f"/doctor/patients/{pat['patient_id']}/prescribe",
        headers=auth(doc["token"]),
        json={"medications": [{"name": "Paracetamol", "dose": "1 g"}]},
    )
    assert r.status_code == 403
