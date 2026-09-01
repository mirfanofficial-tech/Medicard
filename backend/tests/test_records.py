import base64

import pytest

# 1x1 PNG
PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)


async def _patient_token(client, phone="+923005550000", name="Ayesha"):
    r = await client.post("/auth/patient/otp/request", json={"phone": phone})
    code = r.json()["dev_code"]
    r = await client.post(
        "/auth/patient/otp/verify", json={"phone": phone, "code": code, "name": name}
    )
    return r.json()["tokens"]["access_token"]


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


async def _upload(client, token, data=PNG, filename="rx.png", ctype="image/png"):
    r = await client.post(
        "/records/upload",
        headers=_auth(token),
        files={"file": (filename, data, ctype)},
    )
    assert r.status_code == 201, r.text
    return r.json()["record_id"]


@pytest.mark.asyncio
async def test_upload_then_extract_produces_unverified_draft(client):
    token = await _patient_token(client)
    rid = await _upload(client, token)

    r = await client.post(f"/records/{rid}/extract", headers=_auth(token))
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["extraction"]["status"] == "needs_review"
    assert body["extraction"]["confidence_by_field"]  # per-field confidence present
    assert any(m["name"] == "Metformin" for m in body["draft"]["medications"])

    # still unverified until a human confirms
    r = await client.get(f"/records/{rid}", headers=_auth(token))
    assert r.json()["verified"] is False


@pytest.mark.asyncio
async def test_confirm_marks_verified_with_edits(client):
    token = await _patient_token(client)
    rid = await _upload(client, token)
    draft = (await client.post(f"/records/{rid}/extract", headers=_auth(token))).json()["draft"]

    draft["medications"][0]["dose"] = "1000 mg"  # correct a misread dose
    r = await client.post(
        f"/records/{rid}/confirm",
        headers=_auth(token),
        json={"type": "prescription", "doc_date": "2026-05-10", "provider": "City Clinic",
              "data": draft},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["verified"] is True
    assert body["data"]["medications"][0]["dose"] == "1000 mg"
    assert body["extraction"]["status"] == "confirmed"


@pytest.mark.asyncio
async def test_timeline_lists_records_and_sensitive_toggle(client):
    token = await _patient_token(client)
    rid = await _upload(client, token)
    await client.post(f"/records/{rid}/extract", headers=_auth(token))

    r = await client.get("/records", headers=_auth(token))
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = await client.post(
        f"/records/{rid}/sensitive", headers=_auth(token), json={"sensitive": True}
    )
    assert r.status_code == 200
    assert r.json()["sensitive"] is True


@pytest.mark.asyncio
async def test_other_patient_cannot_read_record(client):
    a = await _patient_token(client, phone="+923001111000", name="A")
    b = await _patient_token(client, phone="+923002222000", name="B")
    rid = await _upload(client, a)

    r = await client.get(f"/records/{rid}", headers=_auth(b))
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_rejects_non_document_file(client):
    token = await _patient_token(client)
    r = await client.post(
        "/records/upload",
        headers=_auth(token),
        files={"file": ("notes.txt", b"hello", "text/plain")},
    )
    assert r.status_code == 415
