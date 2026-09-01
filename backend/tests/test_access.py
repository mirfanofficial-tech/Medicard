import uuid
from datetime import UTC, datetime, timedelta

import pytest

from app.models import AccessGrant
from tests.helpers import add_record, auth, doctor_signup, patient_signup


async def _request_and_approve(client, doc, pat):
    r = await client.post(
        "/doctor/access-requests",
        headers=auth(doc["token"]),
        json={"medicard_code": pat["code"]},
    )
    assert r.status_code == 201, r.text
    req_id = r.json()["request_id"]

    pending = (await client.get("/patient/access-requests", headers=auth(pat["token"]))).json()
    assert any(p["request_id"] == req_id for p in pending)

    r = await client.post(
        f"/patient/access-requests/{req_id}/approve", headers=auth(pat["token"])
    )
    assert r.status_code == 200, r.text
    return r.json()["grant_id"]


@pytest.mark.asyncio
async def test_pending_doctor_cannot_request_access(client):
    doc = await doctor_signup(client, activate=False)
    pat = await patient_signup(client, "+923001000001")
    r = await client.post(
        "/doctor/access-requests",
        headers=auth(doc["token"]),
        json={"medicard_code": pat["code"]},
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_consent_flow_grants_scoped_read(client):
    doc = await doctor_signup(client)
    pat = await patient_signup(client, "+923001000002", name="Ayesha Khan")
    await add_record(client, pat["token"])
    await add_record(client, pat["token"], sensitive=True)

    # no grant yet
    r = await client.get(
        f"/doctor/patients/{pat['patient_id']}/records", headers=auth(doc["token"])
    )
    assert r.status_code == 403

    await _request_and_approve(client, doc, pat)

    r = await client.get(
        f"/doctor/patients/{pat['patient_id']}/records", headers=auth(doc["token"])
    )
    assert r.status_code == 200
    rows = r.json()
    assert len(rows) == 1  # sensitive record withheld

    hist = (await client.get("/patient/access-history", headers=auth(pat["token"]))).json()
    actions = [h["action"] for h in hist]
    assert "grant" in actions and "view" in actions and "request" in actions
    assert hist[0]["for_patient"] == "Ayesha Khan"


@pytest.mark.asyncio
async def test_denied_request_blocks_access(client):
    doc = await doctor_signup(client)
    pat = await patient_signup(client, "+923001000003")
    r = await client.post(
        "/doctor/access-requests",
        headers=auth(doc["token"]),
        json={"medicard_code": pat["code"]},
    )
    req_id = r.json()["request_id"]
    r = await client.post(
        f"/patient/access-requests/{req_id}/deny", headers=auth(pat["token"])
    )
    assert r.status_code == 204

    r = await client.get(
        f"/doctor/patients/{pat['patient_id']}/records", headers=auth(doc["token"])
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_expired_grant_is_forbidden(client, db):
    doc = await doctor_signup(client)
    pat = await patient_signup(client, "+923001000004")
    grant_id = await _request_and_approve(client, doc, pat)

    grant = await db.get(AccessGrant, uuid.UUID(grant_id))
    grant.expires_at = datetime.now(UTC) - timedelta(hours=1)
    await db.commit()

    r = await client.get(
        f"/doctor/patients/{pat['patient_id']}/records", headers=auth(doc["token"])
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_doctor_ends_grant_early(client):
    doc = await doctor_signup(client)
    pat = await patient_signup(client, "+923001000005")
    grant_id = await _request_and_approve(client, doc, pat)

    r = await client.post(f"/doctor/grants/{grant_id}/end", headers=auth(doc["token"]))
    assert r.status_code == 204

    r = await client.get(
        f"/doctor/patients/{pat['patient_id']}/records", headers=auth(doc["token"])
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_patient_revokes_grant(client):
    doc = await doctor_signup(client)
    pat = await patient_signup(client, "+923001000006")
    grant_id = await _request_and_approve(client, doc, pat)

    r = await client.post(
        f"/patient/grants/{grant_id}/revoke", headers=auth(pat["token"])
    )
    assert r.status_code == 204

    r = await client.get(
        f"/doctor/patients/{pat['patient_id']}/records", headers=auth(doc["token"])
    )
    assert r.status_code == 403

    hist = (await client.get("/patient/access-history", headers=auth(pat["token"]))).json()
    assert "revoke" in [h["action"] for h in hist]


@pytest.mark.asyncio
async def test_break_glass_returns_critical_only_and_is_logged(client):
    doc = await doctor_signup(client)
    pat = await patient_signup(client, "+923001000007")
    # confirmed prescription: stub has Metformin + a Penicillin allergy
    await add_record(client, pat["token"])

    r = await client.post(
        "/doctor/break-glass",
        headers=auth(doc["token"]),
        json={"medicard_code": pat["code"], "reason": "Unconscious in ED, no next of kin"},
    )
    assert r.status_code == 201, r.text
    body = r.json()
    assert "Penicillin" in body["allergies"]
    assert any(m["name"] == "Metformin" for m in body["current_medications"])
    assert body["grant"]["scope"] == "critical"

    # critical scope cannot open the full timeline
    r = await client.get(
        f"/doctor/patients/{pat['patient_id']}/records", headers=auth(doc["token"])
    )
    assert r.status_code == 403

    hist = (await client.get("/patient/access-history", headers=auth(pat["token"]))).json()
    bg = [h for h in hist if h["action"] == "break_glass"]
    assert bg and bg[0]["reason"] == "Unconscious in ED, no next of kin"


@pytest.mark.asyncio
async def test_break_glass_requires_reason(client):
    doc = await doctor_signup(client)
    pat = await patient_signup(client, "+923001000008")
    r = await client.post(
        "/doctor/break-glass",
        headers=auth(doc["token"]),
        json={"medicard_code": pat["code"], "reason": ""},
    )
    assert r.status_code == 422
