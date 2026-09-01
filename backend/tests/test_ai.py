import pytest

from tests.helpers import add_record, auth, doctor_signup, patient_signup


async def _granted(client):
    doc = await doctor_signup(client)
    pat = await patient_signup(client, "+923002000001", name="Ayesha Khan")
    await add_record(client, pat["token"])
    r = await client.post(
        "/doctor/access-requests",
        headers=auth(doc["token"]),
        json={"medicard_code": pat["code"]},
    )
    req_id = r.json()["request_id"]
    await client.post(f"/patient/access-requests/{req_id}/approve", headers=auth(pat["token"]))
    return doc, pat


@pytest.mark.asyncio
async def test_ai_summary_requires_a_grant(client):
    doc = await doctor_signup(client)
    pat = await patient_signup(client, "+923002000002")
    r = await client.get(
        f"/doctor/patients/{pat['patient_id']}/ai-summary", headers=auth(doc["token"])
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_ai_summary_flags_cite_real_records_and_is_advisory(client):
    doc, pat = await _granted(client)

    records = (
        await client.get(
            f"/doctor/patients/{pat['patient_id']}/records", headers=auth(doc["token"])
        )
    ).json()
    real_ids = {r["record_id"] for r in records}

    r = await client.get(
        f"/doctor/patients/{pat['patient_id']}/ai-summary", headers=auth(doc["token"])
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert "advisory" in body["advisory_notice"].lower()
    assert body["summary"]
    assert body["flags"], "stub should surface at least one flag for a record with an allergy"
    for f in body["flags"]:
        assert f["severity"] in {"info", "watch", "urgent"}
        assert set(f["source_record_ids"]).issubset(real_ids)

    # logged for the patient
    hist = (await client.get("/patient/access-history", headers=auth(pat["token"]))).json()
    assert any(h["action"] == "view" for h in hist)


@pytest.mark.asyncio
async def test_ai_ask_is_grounded(client):
    doc, pat = await _granted(client)

    r = await client.post(
        f"/doctor/patients/{pat['patient_id']}/ai-ask",
        headers=auth(doc["token"]),
        json={"question": "What allergies are on file?"},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["answered_from_records"] is True
    assert "Penicillin" in body["answer"]
    assert body["source_record_ids"]

    r = await client.post(
        f"/doctor/patients/{pat['patient_id']}/ai-ask",
        headers=auth(doc["token"]),
        json={"question": "What is the capital of France?"},
    )
    body = r.json()
    assert body["answered_from_records"] is False
    assert body["source_record_ids"] == []


@pytest.mark.asyncio
async def test_ai_ask_needs_grant(client):
    doc = await doctor_signup(client)
    pat = await patient_signup(client, "+923002000003")
    r = await client.post(
        f"/doctor/patients/{pat['patient_id']}/ai-ask",
        headers=auth(doc["token"]),
        json={"question": "anything"},
    )
    assert r.status_code == 403
