import pytest

from tests.helpers import add_record, auth, patient_signup


@pytest.mark.asyncio
async def test_me_get_and_patch(client):
    pat = await patient_signup(client, "+923007000001", name="Ayesha")
    h = auth(pat["token"])

    r = await client.get("/patient/me", headers=h)
    assert r.status_code == 200
    assert r.json()["medicard_code"] == pat["code"]
    assert r.json()["blood_group"] is None

    r = await client.patch(
        "/patient/me",
        headers=h,
        json={"gender": "Female", "blood_group": "O+", "address": "12 Jail Road"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["gender"] == "Female"
    assert body["blood_group"] == "O+"
    assert body["address"] == "12 Jail Road"


@pytest.mark.asyncio
async def test_overview_counts_and_recent(client):
    pat = await patient_signup(client, "+923007000002")
    h = auth(pat["token"])
    await add_record(client, pat["token"])  # stub Rx: meds + Penicillin allergy

    r = await client.get("/patient/overview", headers=h)
    assert r.status_code == 200
    o = r.json()
    assert o["records"] == 1
    assert o["prescriptions"] == 1
    assert o["medications"] >= 1
    assert o["allergies"] == 1
    assert len(o["recent"]) == 1
    assert o["recent"][0]["type"] == "prescription"


@pytest.mark.asyncio
async def test_derived_medications_and_allergies(client):
    pat = await patient_signup(client, "+923007000003")
    h = auth(pat["token"])
    await add_record(client, pat["token"])

    meds = (await client.get("/patient/medications", headers=h)).json()
    assert {m["name"] for m in meds} >= {"Metformin", "Ramipril"}
    assert all(m["source_record_id"] for m in meds)

    allg = (await client.get("/patient/allergies", headers=h)).json()
    assert [a["name"] for a in allg] == ["Penicillin"]
    assert allg[0]["source_record_ids"]


@pytest.mark.asyncio
async def test_patient_own_ai_summary_is_advisory(client):
    pat = await patient_signup(client, "+923007000004")
    h = auth(pat["token"])
    await add_record(client, pat["token"])

    r = await client.get("/patient/ai-summary", headers=h)
    assert r.status_code == 200
    body = r.json()
    assert "advisory" in body["advisory_notice"].lower()
    assert body["summary"]


@pytest.mark.asyncio
async def test_new_patient_has_empty_health_lists(client):
    pat = await patient_signup(client, "+923007000005")
    h = auth(pat["token"])
    assert (await client.get("/patient/medications", headers=h)).json() == []
    assert (await client.get("/patient/allergies", headers=h)).json() == []
    assert (await client.get("/patient/overview", headers=h)).json()["records"] == 0
