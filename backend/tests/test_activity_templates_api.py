from app.models import ActivityTemplate
from sqlalchemy import select

from tests.conftest import api_request


def test_user_can_create_list_update_and_deactivate_activity_template(setup_database):
    created = api_request("POST", "/api/v2/activity-templates", json={"kind": "task", "label": "Kodlama"})
    assert created.status_code == 201
    template_id = created.json()["id"]

    listed = api_request("GET", "/api/v2/activity-templates?kind=task")
    assert listed.status_code == 200
    assert "Kodlama" in {item["label"] for item in listed.json()}

    updated = api_request("PATCH", f"/api/v2/activity-templates/{template_id}", json={"label": "Proje"})
    assert updated.status_code == 200
    assert updated.json()["label"] == "Proje"

    deleted = api_request("DELETE", f"/api/v2/activity-templates/{template_id}")
    assert deleted.status_code == 204
    with setup_database() as session:
        assert session.scalar(select(ActivityTemplate).where(ActivityTemplate.id == template_id)).is_active is False


def test_system_activity_template_cannot_be_modified():
    system_id = api_request("GET", "/api/v2/operations/context").json()["sources"]["activity_templates.task"][0]["value"]

    response = api_request("PATCH", f"/api/v2/activity-templates/{system_id}", json={"label": "Degisti"})

    assert response.status_code == 403
