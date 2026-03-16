# Life OS

Cloud-ready, mobile-first rewrite of Life OS.

This repository starts as a clean monorepo skeleton so the old project's
finance/event engine can be migrated into a better backend and a React frontend.
The new system is designed around PostgreSQL, not SQLite.

## Initial Structure

```text
backend/
  app/
    api/routes/
    core/
    db/
    models/
    schemas/
    services/
  tests/
frontend/
  public/
  src/
    api/
    app/
    components/
    features/
    hooks/
    lib/
    pages/
    styles/
shared/
  contracts/
docs/
infra/
```

## Directory Intent

- `backend/app/api/routes`: FastAPI routers
- `backend/app/core`: config, security, settings
- `backend/app/db`: PostgreSQL session and persistence helpers
- `backend/app/models`: ORM models
- `backend/app/schemas`: request/response schemas
- `backend/app/services`: business logic
- `frontend/src/api`: frontend API clients
- `frontend/src/app`: app shell, routing, providers
- `frontend/src/features`: feature-specific UI and state
- `shared/contracts`: shared payload contracts and migration notes
- `docs`: architecture and migration documentation
- `infra`: deployment files

The next step is wiring the backend application entrypoint and frontend app boot.

## Backend Hardening Notes

- Copy `.env.example` to `.env` before first production boot.
- Run DB migrations via `./infra/scripts/backend-migrate.sh`.
- Start the API via `./infra/scripts/backend-start.sh`.
- Set `APP_API_TOKEN` to protect all `/api/v1/*` endpoints with `X-App-Token` or `Authorization: Bearer ...`.
- Run reminder dispatch without HTTP via `python -m app.cli.dispatch_reminders`.
- Run the periodic worker via `python -m app.cli.run_reminder_worker --interval 60`.
- Provision a DB-backed bearer token via `python -m app.cli.issue_token --email owner@example.com --name "Owner"`.
