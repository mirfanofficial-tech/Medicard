from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import health
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


@app.get("/")
async def root() -> dict[str, str]:
    return {"service": "medicard-api", "env": settings.env}
