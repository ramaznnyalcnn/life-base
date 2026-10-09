# Life OS — Full-Stack Personal Productivity Platform

![Python](https://img.shields.io/badge/Python-FastAPI-blue)
![React](https://img.shields.io/badge/React-19-61DAFB)
![Flutter](https://img.shields.io/badge/Flutter-Android-02569B)
![PostgreSQL](https://img.shields.io/badge/Database-PostgreSQL-336791)
![Docker](https://img.shields.io/badge/Deploy-Docker-2496ED)

A cloud-ready monorepo personal life management platform — FastAPI backend, React 19 web frontend, and a Flutter Android app sharing a PostgreSQL database with Alembic migrations.

## Architecture

```
lifebase/
├── backend/          FastAPI + SQLAlchemy + PostgreSQL + Alembic
├── frontend/         React 19 + Vite + TypeScript
├── mobile/           Flutter + Dart + native Android integrations
├── shared/           Shared contracts between frontend and backend
└── infra/            Docker Compose + deployment scripts
```

**Stack:**
- **Backend:** Python, FastAPI (async), SQLAlchemy ORM, Alembic migrations, pytest
- **Web:** React 19, Vite, TypeScript, vitest
- **Mobile:** Flutter, Dart, Riverpod, GoRouter, Drift, Android Calendar Provider, WorkManager, Keystore, and Glance
- **Database:** PostgreSQL (migrated from SQLite for production readiness)
- **DevOps:** Docker, Docker Compose

## Quick Start

```bash
cp .env.example .env
docker compose up --build
./infra/scripts/backend-migrate.sh
# API: http://localhost:8000
# Web: http://localhost:5173
```

## Backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
./infra/scripts/backend-start.sh
```

All `/api/v1/*` endpoints require `X-App-Token` or `Authorization: Bearer ...`.

Provision a token:
```bash
python -m app.cli.issue_token --email owner@example.com --name "Owner"
```

Run reminder dispatch:
```bash
python -m app.cli.run_reminder_worker --interval 60
```

## Web Frontend

```bash
cd frontend && npm install && npm run dev
```

## Mobile

```bash
cd mobile
flutter pub get
flutter run
```

See [Android architecture](docs/mobile-android.md) for device setup, offline behavior, calendar sync, reminders, and the home-screen widget.

## Testing

```bash
cd backend && pytest -q
cd frontend && npm run test
cd mobile && flutter test && flutter analyze
```

## Design Decisions

- **Monorepo** — backend, web, and mobile in one repo with shared payload contracts
- **PostgreSQL over SQLite** — production-grade persistence with Alembic schema evolution
- **Async FastAPI** — non-blocking I/O throughout
- **Flutter Android** — mobile-first UI with native calendar, reminder, background sync, and widget support
- **Selection-first operations** — structured `/api/v2` actions replace natural-language command entry
- **Keystore + Drift** — encrypted credentials and an offline operation queue on device

See [Structured Operation API](docs/operation-api.md) for the class-based backend operation contract.
