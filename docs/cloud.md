# Cloud Notes

## Current status

- Local PostgreSQL migration applied successfully
- API boots and answers `/health`
- Container packaging is ready for full-stack deployment

## Recommended Docker path

1. Copy `.env.example` to `.env`
2. Fill production secrets and review `POSTGRES_*`, `WEB_APP_URL`, `VAPID_*`, `OPENROUTER_*`
3. Start the stack with `docker compose -f infra/compose/prod-stack.yml up -d --build`
4. Verify `http://SERVER_IP:${WEB_PORT:-8080}/health`
5. When the app is stable, put TLS in front of the `web` service and map `WEB_PORT=80`

This stack brings up:

- PostgreSQL
- one-shot migration container
- API container
- reminder worker container
- nginx web container serving the frontend and proxying `/api/`

## Backend-only local simulation

```bash
docker compose -f infra/compose/backend-stack.yml up --build
```

## Full-stack local or VPS simulation

```bash
docker compose -f infra/compose/prod-stack.yml up -d --build
```

Default exposed port is `8080` so local runs do not fight with an existing host nginx.

## Important notes

- The frontend includes a bearer-token login flow. Keep `APP_API_TOKEN` empty for normal browser/mobile use; enable it only when every client can send the shared service token.
- The `db` service is intentionally not published to the host.
- For same-origin deployment, keep `VITE_API_BASE_URL=/api/v1`.
