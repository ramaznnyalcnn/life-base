# Ubuntu 24.04 VPS Deployment Notes

## Recommended topology

- `nginx`: serves `frontend/dist` and reverse proxies `/api/` to the backend
- `systemd`: runs migration, API service, and reminder timer
- `postgresql`: local PostgreSQL 16 or a managed PostgreSQL instance
- `certbot`: TLS for the public hostname

## Security note

Current frontend does not implement a login flow or bearer-token storage. Because of that:

- do not expose the app publicly without an outer protection layer
- if you serve the current frontend directly, leave `APP_API_TOKEN` empty or the UI will receive `401`
- recommended temporary protection: VPN, Cloudflare Access, Tailscale Funnel, or basic auth at the edge

## Project-specific environment

Set at minimum:

```dotenv
ENVIRONMENT=production
DATABASE_URL=postgresql+psycopg://lifeos:strong-password@127.0.0.1:5432/lifeos
WEB_APP_URL=https://app.example.com
CORS_ORIGINS=https://app.example.com
OPENROUTER_API_KEY=...
ENABLE_WEB_PUSH=true
VAPID_PUBLIC_KEY=...
VAPID_PRIVATE_KEY=...
VAPID_SUBJECT=mailto:notify@example.com
```

Notes:

- frontend now defaults to `/api/v1`, so same-origin nginx proxy works without `VITE_API_BASE_URL`
- if frontend and API are on different origins, build frontend with `VITE_API_BASE_URL=https://api.example.com/api/v1`
- `OPENROUTER_MODELS` can be comma-separated or JSON array

## Server bootstrap

```bash
sudo apt update
sudo apt install -y python3.12-venv python3-pip postgresql postgresql-contrib nginx
sudo systemctl enable --now postgresql nginx
```

## App layout

Recommended target path:

```text
/opt/lifeos
  backend/
  frontend/
  infra/
  .env
  .venv/
```

## Backend install

```bash
cd /opt/lifeos
python3 -m venv .venv
./.venv/bin/pip install -r backend/requirements.txt
./infra/scripts/backend-migrate.sh
sudo systemctl start lifeos-migrate.service
sudo systemctl enable --now lifeos-api.service
sudo systemctl enable --now lifeos-reminders.timer
```

## Frontend build

```bash
cd /opt/lifeos/frontend
npm ci
npm run build
```

This outputs static assets into `frontend/dist`.

## Nginx

Use [lifeos.conf](/home/ramazan/Desktop/lifebase/infra/nginx/lifeos.conf) as the base server block and adapt:

- `server_name`
- TLS certificates
- optional outer auth layer

## Health checks

Verify:

```bash
curl http://127.0.0.1:8000/health
sudo systemctl status lifeos-api.service
sudo systemctl status lifeos-reminders.timer
sudo journalctl -u lifeos-api.service -n 100 --no-pager
```
