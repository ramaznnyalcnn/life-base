"""Schemas for calendar dashboard responses."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.schemas.event import EventRead, ReminderRead


class CalendarReminderItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    event_id: int
    event_title: str
    remind_at: datetime
    is_sent: bool


class CalendarDashboard(BaseModel):
    focus_event: EventRead | None
    upcoming_events: list[EventRead]
    past_events: list[EventRead]
    pending_reminders: list[CalendarReminderItem]
