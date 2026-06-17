# Life OS

![FastAPI](https://img.shields.io/badge/API-FastAPI-009688)
![PostgreSQL](https://img.shields.io/badge/Database-PostgreSQL-336791)
![React](https://img.shields.io/badge/Web-React-61dafb)
![Expo](https://img.shields.io/badge/Mobile-Expo-000020)
![Docker](https://img.shields.io/badge/Deploy-Docker%20%2B%20systemd-2496ed)

Life OS is a full-stack personal operations system for wallet tracking, calendar events, recurring routines, medication reminders, push notifications, and AI-assisted entry. The repository is structured as a production-style monorepo with a FastAPI backend, PostgreSQL migrations, a React PWA, an Expo Android client, and deployment artifacts for Docker or same-host VPS installs.

## What It Shows

- Multi-user FastAPI backend with bearer-token authentication and owner bootstrap flow.
- PostgreSQL-first data model with Alembic migrations for accounts, transactions, events, recurring events, medications, notifications, transfers, and users.
- React/Vite PWA frontend with wallet, calendar, history, manage, settings, login, push notification, and AI command screens.
- Expo React Native mobile app that stores login sessions securely and syncs reminders locally.
- Reminder dispatch worker with systemd timer support and Docker Compose deployment paths.
- AI parser service with OpenRouter integration kept behind environment configuration.
- Test coverage for API routes, auth, migrations, reminders, notifications, deploy artifacts, frontend components, and mobile config.

## Architecture

```text
React PWA / Expo Mobile
        |
        v
FastAPI API gateway and route layer
        |
        v
Service layer: wallet, events, transfers, medication, notifications, AI parser
        |
        v
SQLAlchemy models + Alembic migrations
        |
        v
PostgreSQL

Background workers:
  - medication and reminder dispatch
  - push notification delivery
```

## Repository Layout

```text
backend/   FastAPI app, SQLAlchemy models, Alembic migrations, CLI tools, tests
frontend/  React/Vite PWA, service worker, frontend tests, nginx image
mobile/    Expo React Native app, secure session storage, notification sync
infra/     Docker Compose, nginx, systemd services, backend run scripts
docs/      Cloud, VPS, mobile, and operations notes
shared/    Shared contracts and migration notes
```

## Screenshots

The `docs/assets/` directory contains the current desktop and mobile visual snapshots used while shaping the UI:

- `docs/assets/vintage-desktop.png`
- `docs/assets/vintage-mobile.png`
- `docs/assets/vintage-blur-desktop.png`
- `docs/assets/vintage-blur-mobile.png`

## Backend Quick Start

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
cp .env.example .env
./infra/scripts/backend-migrate.sh
./infra/scripts/backend-start.sh
```

Useful commands:

```bash
PYTHONPATH=backend ./.venv/bin/python -m app.cli.create_user \
  --email owner@example.com \
  --name "Owner" \
  --password "replace-with-a-strong-password" \
  --admin

PYTHONPATH=backend ./.venv/bin/python -m app.cli.dispatch_reminders --limit 50
PYTHONPATH=backend ./.venv/bin/python -m app.cli.run_reminder_worker --interval 60
```

## Frontend Quick Start

```bash
cd frontend
npm ci
npm run test
npm run build
npm run dev
```

The frontend defaults to same-origin `/api/v1`. For split frontend/API deployments, build with `VITE_API_BASE_URL=https://api.example.com/api/v1`.

## Mobile Quick Start

```bash
cd mobile
npm ci
npm run verify:config
npm run typecheck
npm run start
```

The mobile app is designed for personal Android use with Expo. It stores bearer tokens with `expo-secure-store` and stores local app settings separately from credentials.

## Deployment

Two deployment paths are included:

```bash
# Backend-only local simulation
docker compose -f infra/compose/backend-stack.yml up --build

# Full stack simulation / VPS baseline
docker compose -f infra/compose/prod-stack.yml up -d --build
```

For a same-host Ubuntu deployment, use the systemd units in `infra/systemd/` and the nginx config in `infra/nginx/lifeos.conf`. See `docs/ubuntu-24.04-vps.md`, `docs/cloud.md`, and `docs/ops.md`.

## Configuration

The repository tracks `.env.example` and ignores real `.env` files. Production secrets that must stay out of Git include:

- `POSTGRES_PASSWORD`
- `APP_API_TOKEN`
- `DEFAULT_OWNER_PASSWORD`
- `OPENROUTER_API_KEY`
- `VAPID_PRIVATE_KEY`

## Testing

```bash
PYTHONPATH=backend pytest backend/tests -q
cd frontend && npm test
cd mobile && npm run verify:config && npm run typecheck
```

Some integration tests use local SQLite fixtures; production deployments should run PostgreSQL through Alembic migrations.

## Notes

This repository is optimized for reviewability: application code, infrastructure, migrations, UI tests, backend tests, mobile code, screenshots, and deployment notes are tracked; local databases, real secrets, build outputs, and native mobile build artifacts are ignored.
