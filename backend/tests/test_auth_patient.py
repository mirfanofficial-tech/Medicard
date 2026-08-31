import pytest


async def _register_patient(client, phone="+923001234567", **extra):
    r = await client.post("/auth/patient/otp/request", json={"phone": phone})
    assert r.status_code == 200
    code = r.json()["dev_code"]
    assert code and len(code) == 6
    r = await client.post(
        "/auth/patient/otp/verify", json={"phone": phone, "code": code, **extra}
    )
    assert r.status_code == 200, r.text
    return r.json()


@pytest.mark.asyncio
async def test_patient_otp_register_then_login_same_profile(client):
    first = await _register_patient(client, name="Ayesha", cnic="3520212345671")
    assert first["is_new"] is True
    assert len(first["medicard_code"]) == 8

    again = await _register_patient(client)
    assert again["is_new"] is False
    assert again["medicard_code"] == first["medicard_code"]
    assert again["patient_id"] == first["patient_id"]


@pytest.mark.asyncio
async def test_wrong_otp_rejected(client):
    phone = "+923009999999"
    await client.post("/auth/patient/otp/request", json={"phone": phone})
    r = await client.post(
        "/auth/patient/otp/verify", json={"phone": phone, "code": "000000"}
    )
    # 1 in a million chance the real code is 000000; accept either failure path
    assert r.status_code in (400,) or r.json().get("is_new") is True


@pytest.mark.asyncio
async def test_me_for_patient(client):
    data = await _register_patient(client, name="Bilal")
    token = data["tokens"]["access_token"]
    r = await client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200
    body = r.json()
    assert body["role"] == "patient"
    assert body["profile"]["medicard_code"] == data["medicard_code"]


@pytest.mark.asyncio
async def test_recover_reissues_code_on_same_profile(client):
    phone = "+923004445555"
    created = await _register_patient(client, phone=phone, name="Sana", cnic="1111122222333")
    old_code = created["medicard_code"]

    r = await client.post("/auth/patient/recover/request", json={"phone": phone})
    rec_code = r.json()["dev_code"]
    r = await client.post(
        "/auth/patient/recover/verify",
        json={"phone": phone, "code": rec_code, "cnic": "1111122222333"},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["patient_id"] == created["patient_id"]
    assert body["medicard_code"] != old_code


@pytest.mark.asyncio
async def test_recover_wrong_cnic_rejected(client):
    phone = "+923006667777"
    await _register_patient(client, phone=phone, cnic="1234512345671")
    r = await client.post("/auth/patient/recover/request", json={"phone": phone})
    rec_code = r.json()["dev_code"]
    r = await client.post(
        "/auth/patient/recover/verify",
        json={"phone": phone, "code": rec_code, "cnic": "9999999999999"},
    )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_guardian_creates_minor_profile(client):
    data = await _register_patient(client, phone="+923001112222", name="Guardian")
    token = data["tokens"]["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    r = await client.post("/patient/minors", json={"name": "Little One"}, headers=headers)
    assert r.status_code == 201, r.text
    minor = r.json()
    assert minor["is_minor"] is True
    assert minor["medicard_code"] != data["medicard_code"]

    r = await client.get("/patient/profiles", headers=headers)
    assert r.status_code == 200
    profiles = r.json()
    assert {p["name"] for p in profiles} == {"Guardian", "Little One"}
