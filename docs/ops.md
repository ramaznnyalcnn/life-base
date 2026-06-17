# Ops Notes

## Boot Flow

1. Copy `.env.example` to `.env` and fill production secrets
2. Create a virtualenv and install `backend/requirements.txt`
3. Run migrations:

```bash
./infra/scripts/backend-migrate.sh
```

4. Start the API:

```bash
./infra/scripts/backend-start.sh
```

## Reminder Dispatch

Recommended production model: `systemd` timer + one-shot service.

1. Put the project at `/opt/lifeos`
2. Ensure `/opt/lifeos/.env` contains production values
3. Copy `infra/systemd/lifeos-migrate.service`, `infra/systemd/lifeos-api.service`, `infra/systemd/lifeos-reminders.service` and `infra/systemd/lifeos-reminders.timer` into `/etc/systemd/system/`
5. Run:

```bash
sudo systemctl daemon-reload
sudo systemctl start lifeos-migrate.service
sudo systemctl enable --now lifeos-api.service
sudo systemctl enable --now lifeos-reminders.timer
sudo systemctl status lifeos-api.service
sudo systemctl status lifeos-reminders.timer
```

### Manual commands

Run once:

```bash
PYTHONPATH=backend ./.venv/bin/python -m app.cli.dispatch_reminders --limit 50
```

Run as a loop worker:

```bash
PYTHONPATH=backend ./.venv/bin/python -m app.cli.run_reminder_worker --interval 60
```
