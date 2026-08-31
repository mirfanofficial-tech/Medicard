# MediCard

Shared, patient-controlled medical-record app with AI extraction and **advisory-only** AI clinical
support. See [PLAN.md](PLAN.md) for scope, architecture, and the phased build plan.

## Repo layout

| Path | What |
|---|---|
| `backend/` | FastAPI + Postgres + MinIO. Owns auth, access-control, and all Claude API calls. |
| `app/` | Flutter client (Android-first). Patient and Doctor roles in one codebase. |
| `infra/` | `docker-compose.yml` for Postgres + MinIO in dev. |
| `PLAN.md` | Implementation plan. |

## Quick start (dev)

```bash
# 1. Infra (needs Docker Desktop running)
docker compose -f infra/docker-compose.yml up -d

# 2. Backend
cd backend
uv sync
cp .env.example .env          # then fill in ANTHROPIC_API_KEY
uv run alembic upgrade head
uv run uvicorn app.main:app --reload
# API docs: http://localhost:8000/docs

# 3. App
cd ../app
flutter pub get
flutter run                    # pick a device; -d chrome works for quick iteration
```

## Status

Phase 0 (setup) — in progress.
