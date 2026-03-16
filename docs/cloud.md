# Cloud Notes

## Current status

- Local PostgreSQL migration applied successfully
- API boots and answers `/health`
- Container packaging is ready for backend-only deployment

## Generic cloud path

1. Build the image from `backend/Dockerfile`
2. Provide a managed PostgreSQL `DATABASE_URL`
3. Run one migration job using `infra/scripts/backend-migrate.sh`
4. Run the API container using `infra/scripts/backend-start.sh`
5. Run a second worker container using `python -m app.cli.run_reminder_worker --interval 60`

## Local stack simulation

```bash
docker compose -f infra/compose/backend-stack.yml up --build
```

This brings up:

- PostgreSQL
- one-shot migration container
- API container
- reminder worker container
