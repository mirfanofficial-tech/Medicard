# MediCard backend

FastAPI + Postgres + MinIO. Owns auth, access control, and every Claude API call.
The app never holds an API key and has no endpoint that returns unscoped patient records.

## Run

```bash
docker compose -f ../infra/docker-compose.yml up -d   # Postgres + MinIO
uv sync
cp .env.example .env                                   # fill ANTHROPIC_API_KEY
uv run alembic upgrade head
uv run uvicorn app.main:app --reload
```

Docs at http://localhost:8000/docs · health at `/health` and `/health/db`.

## Checks

```bash
uv run ruff check .
uv run pytest -q          # uses in-memory SQLite, no Docker needed
```

## Migrations

```bash
uv run alembic revision --autogenerate -m "message"
uv run alembic upgrade head
```

## Layout

| Path | What |
|---|---|
| `app/config.py` | Pydantic settings, read from `.env`. |
| `app/db.py` | Async engine + `get_session` dependency. |
| `app/models/` | SQLAlchemy models. Register each in `models/__init__.py` for Alembic. |
| `app/api/` | Routers. `health.py` is the only one so far. |
| `app/core/` | Auth/security helpers (Phase 1). |
| `app/services/` | Business logic incl. grant checks and Claude calls (Phase 2+). |
