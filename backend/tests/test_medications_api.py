from datetime import date, datetime, time, timezone

from app.api.routes.medications import (
    create_medication_endpoint,
    delete_medication_endpoint,
    get_medication_notification_schedule,
    get_medication_schedule,
    list_medications_endpoint,
    mark_medication_dose_taken_endpoint,
    snooze_medication_dose_endpoint,
    update_medication_endpoint,
)
from app.main import app
from app.schemas import MedicationCreate, MedicationDoseSnooze, MedicationDoseTaken, MedicationUpdate
from app.services.medications import build_medication_dashboard, build_notification_schedule


def test_medication_api_creates_lists_updates_and_deactivates(db_session):
    medication = create_medication_endpoint(
        MedicationCreate(
            name="Vitamin D",
            dosage="1 tablet",
            instructions="Kahvalti ile",
            weekdays=[0, 2, 4],
            dose_times=[time(9, 0), time(21, 0)],
            starts_on=date(2026, 5, 17),
        ),
        db_session,
        x_device_id="device-a",
    )

    assert medication.id is not None
    assert medication.device_id == "device-a"
    assert medication.weekdays == [0, 2, 4]
    assert medication.dose_times == [time(9, 0), time(21, 0)]

    rows = list_medications_endpoint(db_session, x_device_id="device-a")
    assert [row.name for row in rows] == ["Vitamin D"]

    updated = update_medication_endpoint(
        medication.id,
        MedicationUpdate(dosage="2 tablet", weekdays=[1, 3], dose_times=[time(8, 30)]),
        db_session,
        x_device_id="device-a",
    )
    assert updated.dosage == "2 tablet"
    assert updated.weekdays == [1, 3]
    assert updated.dose_times == [time(8, 30)]

    delete_medication_endpoint(medication.id, db_session, x_device_id="device-a")
    rows_after_delete = list_medications_endpoint(db_session, x_device_id="device-a")
    assert rows_after_delete[0].is_active is False


def test_medication_dashboard_and_notification_schedule_handle_taken_and_snoozed_doses(db_session):
    medication = create_medication_endpoint(
        MedicationCreate(
            name="Tansiyon ilaci",
            dosage="5 mg",
            instructions="Su ile al",
            weekdays=[6],
            dose_times=[time(9, 0)],
            starts_on=date(2026, 5, 17),
            timezone="Europe/Istanbul",
        ),
        db_session,
        x_device_id="device-a",
    )
    now = datetime(2026, 5, 17, 5, 30, tzinfo=timezone.utc)

    dashboard = build_medication_dashboard(db_session, device_id="device-a", now=now, days=0)

    assert len(dashboard.today_doses) == 1
    dose = dashboard.today_doses[0]
    assert dose.medication_name == "Tansiyon ilaci"
    assert dose.status == "pending"
    assert dose.scheduled_for.isoformat() == "2026-05-17T06:00:00+00:00"

    snoozed = snooze_medication_dose_endpoint(
        medication.id,
        MedicationDoseSnooze(scheduled_for=dose.scheduled_for, snooze_minutes=10),
        db_session,
        x_device_id="device-a",
    )
    assert snoozed.status == "snoozed"

    schedule = build_notification_schedule(
        db_session,
        device_id="device-a",
        now=datetime(2026, 5, 17, 6, 1, tzinfo=timezone.utc),
        days=0,
    )
    assert len(schedule) == 1
    assert schedule[0].status == "snoozed"

    taken = mark_medication_dose_taken_endpoint(
        medication.id,
        MedicationDoseTaken(scheduled_for=dose.scheduled_for),
        db_session,
        x_device_id="device-a",
    )
    assert taken.status == "taken"

    schedule_after_taken = build_notification_schedule(
        db_session,
        device_id="device-a",
        now=datetime(2026, 5, 17, 6, 2, tzinfo=timezone.utc),
        days=0,
    )
    assert schedule_after_taken == []


def test_medication_routes_share_records_across_user_devices(db_session):
    create_medication_endpoint(
        MedicationCreate(
            name="Benim ilacim",
            dosage="1 kapsul",
            weekdays=[0],
            dose_times=[time(8, 0)],
            starts_on=date(2026, 5, 18),
        ),
        db_session,
        x_device_id="device-a",
    )
    create_medication_endpoint(
        MedicationCreate(
            name="Diger cihaz ilaci",
            dosage="1 kapsul",
            weekdays=[0],
            dose_times=[time(8, 0)],
            starts_on=date(2026, 5, 18),
        ),
        db_session,
        x_device_id="device-b",
    )

    rows = list_medications_endpoint(db_session, x_device_id="device-a")
    assert [row.name for row in rows] == ["Benim ilacim", "Diger cihaz ilaci"]


def test_interval_medication_schedule_uses_start_date_cadence(db_session):
    create_medication_endpoint(
        MedicationCreate(
            name="Iki gunde bir",
            dosage="1 tablet",
            schedule_mode="interval",
            weekdays=[],
            interval_days=2,
            dose_times=[time(9, 0)],
            starts_on=date(2026, 5, 17),
            timezone="Europe/Istanbul",
        ),
        db_session,
        x_device_id="device-a",
    )

    schedule = get_medication_schedule(
        from_date=date(2026, 5, 17),
        to_date=date(2026, 5, 22),
        db=db_session,
    )

    assert [dose.scheduled_for.date().isoformat() for dose in schedule] == [
        "2026-05-17",
        "2026-05-19",
        "2026-05-21",
    ]


def test_medication_endpoint_schedule_shape(db_session):
    create_medication_endpoint(
        MedicationCreate(
            name="Omega",
            dosage="1 kapsul",
            weekdays=[6],
            dose_times=[time(23, 59)],
            starts_on=date(2026, 5, 17),
        ),
        db_session,
        x_device_id="device-a",
    )

    schedule = get_medication_notification_schedule(days=1, limit=10, db=db_session, x_device_id="device-a")

    assert isinstance(schedule, list)


def test_medication_routes_are_registered_on_app():
    paths = {route.path for route in app.routes}

    assert "/api/v1/medications" in paths
    assert "/api/v1/medications/dashboard" in paths
    assert "/api/v1/medications/notification-schedule" in paths
    assert "/api/v1/medications/schedule" in paths
    assert "/api/v1/medications/{medication_id}/doses/taken" in paths
    assert "/api/v1/medications/{medication_id}/doses/snooze" in paths
