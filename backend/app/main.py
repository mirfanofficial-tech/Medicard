from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import admin, auth, doctor, health, patient, records
from app.config import get_settings

settings = get_settings()

app = FastAPI(
    title="MediCard API",
    version="0.1.0",
    summary="Patient-controlled medical records. AI is advisory only.",
)

# Dev-only: the Flutter web build and local tooling hit this from other origins.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.env == "dev" else [],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(auth.router)
app.include_router(patient.router)
app.include_router(records.router)
app.include_router(doctor.router)
app.include_router(admin.router)


@app.get("/")
async def root() -> dict[str, str]:
    return {"service": "medicard-api", "env": settings.env}
