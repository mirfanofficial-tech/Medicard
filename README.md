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

- Phase 0 (setup) — done.
- Phase 1 (identity & auth) — done: patient phone-OTP, doctor register/login + licence-review
  queue, guardian minors, lost-code recovery.
- Phase 2 (records) — done: upload → Claude extraction (`claude-sonnet-5`, JSON schema,
  per-field confidence) → human confirmation screen → verified/unverified timeline, sensitive
  toggle. Set `FAKE_EXTRACTION=true` (or leave `ANTHROPIC_API_KEY` blank) to run it without Claude.
- Phase 3 (consent-gated doctor access) — done: doctor requests by code → patient approves →
  time-boxed, logged, scoped grant; sensitive records withheld; break-glass emergency mode
  (critical-only, logged, reason required); patient Access History with revoke.
- Phase 4 (advisory AI) — done: `GET /doctor/patients/{id}/ai-summary` and `POST …/ai-ask`
  (`claude-sonnet-5`), summariser/flagger only — never prescribes — every claim cites a source
  record; grounded Ask that declines off-record questions. `FAKE_AI=true` (or no key) stubs it.
- Backend `pytest` (31) + app `flutter test` (3) green.
- Next: Phase 5 — polish, low-bandwidth mode, demo seed + script.

Docker Desktop has been down throughout, so the stack has been exercised against SQLite +
`STORAGE_BACKEND=local`. Bring up `infra/docker-compose.yml` for the Postgres + MinIO path.
