import pytest

ADMIN = {"X-Admin-Key": "test-admin-key"}

DOCTOR = {
    "name": "Dr Ahmed",
    "email": "ahmed@example.com",
    "password": "correct horse staple",
    "licence_no": "PMDC-12345",
    "specialty": "Endocrinology",
    "hospital": "City Hospital",
}


@pytest.mark.asyncio
async def test_doctor_registers_pending_and_cannot_be_active_yet(client):
    r = await client.post("/auth/doctor/register", json=DOCTOR)
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["status"] == "pending_verification"

    # login works, but status is still pending
    r = await client.post(
        "/auth/doctor/login", json={"email": DOCTOR["email"], "password": DOCTOR["password"]}
    )
    assert r.status_code == 200
    assert r.json()["status"] == "pending_verification"


@pytest.mark.asyncio
async def test_duplicate_email_rejected(client):
    await client.post("/auth/doctor/register", json=DOCTOR)
    r = await client.post("/auth/doctor/register", json={**DOCTOR, "licence_no": "PMDC-999"})
    assert r.status_code == 409


@pytest.mark.asyncio
async def test_admin_review_queue_and_approval(client):
    reg = (await client.post("/auth/doctor/register", json=DOCTOR)).json()
    doctor_id = reg["doctor_id"]

    r = await client.get("/admin/doctors", headers=ADMIN)
    assert r.status_code == 200
    assert any(row["doctor_id"] == doctor_id for row in r.json())

    r = await client.post(
        f"/admin/doctors/{doctor_id}/review",
        json={"decision": "active", "note": "licence checked"},
        headers=ADMIN,
    )
    assert r.status_code == 200
    assert r.json()["status"] == "active"

    # now off the pending queue
    r = await client.get("/admin/doctors", headers=ADMIN)
    assert all(row["doctor_id"] != doctor_id for row in r.json())


@pytest.mark.asyncio
async def test_admin_requires_key(client):
    r = await client.get("/admin/doctors")
    assert r.status_code == 401
    r = await client.get("/admin/doctors", headers={"X-Admin-Key": "wrong"})
    assert r.status_code == 401


@pytest.mark.asyncio
async def test_refresh_returns_new_access_token(client):
    reg = (await client.post("/auth/doctor/register", json=DOCTOR)).json()
    refresh = reg["tokens"]["refresh_token"]
    r = await client.post("/auth/refresh", json={"refresh_token": refresh})
    assert r.status_code == 200
    assert r.json()["access_token"]
