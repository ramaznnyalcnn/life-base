"""Pydantic schemas for events and reminders."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models import ReminderChannel


class ReminderBase(BaseModel):
    remind_at: datetime
    channel: ReminderChannel = ReminderChannel.WEB_PUSH


class ReminderCreate(ReminderBase):
    pass


class ReminderRead(ReminderBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    event_id: int
    is_sent: bool


class EventBase(BaseModel):
    title: str = Field(min_length=2, max_length=160)
    description: str | None = None
    starts_at: datetime
    ends_at: datetime | None = None
    is_all_day: bool = False
    is_important: bool = False
    is_completed: bool = False
    is_recurring: bool = False
    recurring_rule_id: int | None = None

    @model_validator(mode="after")
    def validate_time_range(self):
        if self.ends_at is not None and self.ends_at < self.starts_at:
            raise ValueError("Bitis zamani baslangictan once olamaz.")
        return self


class EventCreate(EventBase):
    reminder_offsets_minutes: list[int] | None = None
    device_id: str | None = Field(default=None, max_length=120)


class EventUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=160)
    description: str | None = None
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    is_all_day: bool | None = None
    is_important: bool | None = None
    is_completed: bool | None = None
    reminder_offsets_minutes: list[int] | None = None


class EventRead(EventBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    reminders: list[ReminderRead] = Field(default_factory=list)
