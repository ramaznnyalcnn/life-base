from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]


def test_env_example_exists_with_core_keys():
    env_example = (REPO_ROOT / ".env.example").read_text()

    assert "DATABASE_URL=" in env_example
    assert "APP_API_TOKEN=" in env_example
    assert "REMINDER_DISPATCH_INTERVAL_SECONDS=" in env_example


def test_systemd_artifacts_exist():
    assert (REPO_ROOT / "infra" / "systemd" / "lifeos-api.service").exists()
    assert (REPO_ROOT / "infra" / "systemd" / "lifeos-migrate.service").exists()
    assert (REPO_ROOT / "infra" / "systemd" / "lifeos-reminders.service").exists()
    assert (REPO_ROOT / "infra" / "systemd" / "lifeos-reminders.timer").exists()


def test_deploy_scripts_exist():
    migrate_script = (REPO_ROOT / "infra" / "scripts" / "backend-migrate.sh").read_text()
    start_script = (REPO_ROOT / "infra" / "scripts" / "backend-start.sh").read_text()

    assert "alembic" in migrate_script
    assert "command -v alembic" in migrate_script
    assert "uvicorn" in start_script
    assert "command -v uvicorn" in start_script


def test_container_artifacts_exist():
    dockerfile = (REPO_ROOT / "backend" / "Dockerfile").read_text()
    compose_file = (REPO_ROOT / "infra" / "compose" / "backend-stack.yml").read_text()
    prod_compose_file = (REPO_ROOT / "infra" / "compose" / "prod-stack.yml").read_text()
    frontend_dockerfile = (REPO_ROOT / "frontend" / "Dockerfile").read_text()
    frontend_nginx = (REPO_ROOT / "frontend" / "nginx.conf").read_text()

    assert "python:3.12-slim" in dockerfile
    assert "run_reminder_worker" in compose_file
    assert "postgres:16" in compose_file
    assert "nginx:1.27-alpine" in frontend_dockerfile
    assert "proxy_pass http://lifeos_api" in frontend_nginx
    assert "service_completed_successfully" in prod_compose_file
    assert "VITE_API_BASE_URL" in prod_compose_file
