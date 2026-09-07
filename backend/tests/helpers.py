import base64

PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)
ADMIN = {"X-Admin-Key": "test-admin-key"}


def auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


async def patient_signup(client, phone: str, name: str = "Pat") -> dict:
    code = (
        await client.post("/auth/patient/otp/request", json={"phone": phone})
    ).json()["dev_code"]
    r = await client.post(
        "/auth/patient/otp/verify", json={"phone": phone, "code": code, "name": name}
    )
    d = r.json()
    return {
        "token": d["tokens"]["access_token"],
        "patient_id": d["patient_id"],
        "code": d["medicard_code"],
    }


async def doctor_signup(client, email: str = "doc@example.com", activate: bool = True) -> dict:
    r = await client.post(
        "/auth/doctor/register",
        json={
            "name": "Ahmed",
            "email": email,
            "password": "correct horse staple",
            "licence_no": "PMDC-1",
            "hospital": "City Hospital",
        },
    )
    d = r.json()
    if activate:
        await client.post(
            f"/admin/doctors/{d['doctor_id']}/review",
            json={"decision": "active"},
            headers=ADMIN,
        )
    return {"token": d["tokens"]["access_token"], "doctor_id": d["doctor_id"]}


async def add_record(client, token: str, *, sensitive: bool = False) -> str:
    rid = (
        await client.post(
            "/records/upload", headers=auth(token), files={"file": ("rx.png", PNG, "image/png")}
        )
    ).json()["record_id"]
    draft = (
        await client.post(f"/records/{rid}/extract", headers=auth(token))
    ).json()["draft"]
    await client.post(
        f"/records/{rid}/confirm",
        headers=auth(token),
        json={"type": "prescription", "doc_date": "2026-05-10", "provider": "City", "data": draft},
    )
    if sensitive:
        await client.post(
            f"/records/{rid}/sensitive", headers=auth(token), json={"sensitive": True}
        )
    return rid
