"""Schemas for medication reminders."""

from datetime import date, datetime, time
from typing import Literal
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, Field, model_validator


DoseItemStatus = Literal["pending", "taken", "snoozed"]
MedicationScheduleMode = Literal["weekdays", "interval"]


class MedicationBase(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    dosage: str = Field(min_length=1, max_length=120)
    instructions: str | None = None
    schedule_mode: MedicationScheduleMode = "weekdays"
    weekdays: list[int] = Field(default_factory=list)
    interval_days: int | None = Field(default=None, ge=1, le=365)
    dose_times: list[time] = Field(min_length=1)
    starts_on: date
    ends_on: date | None = None
    timezone: str = Field(default="Europe/Istanbul", min_length=1, max_length=64)
    is_active: bool = True

    @model_validator(mode="after")
    def validate_schedule(self):
        if any(day < 0 or day > 6 for day in self.weekdays):
            raise ValueError("Gunler 0 ile 6 arasinda olmali.")
        if self.schedule_mode == "weekdays":
            if not self.weekdays:
                raise ValueError("Gun programinda en az bir gun gerekli.")
            if self.interval_days is not None:
                raise ValueError("Gun programinda aralik kullanilamaz.")
        elif self.weekdays or self.interval_days is None:
            raise ValueError("Aralikli programda gunler bos ve gun araligi zorunlu olmali.")
        if self.ends_on is not None and self.ends_on < self.starts_on:
            raise ValueError("Bitis tarihi baslangictan once olamaz.")
        try:
            ZoneInfo(self.timezone)
        except ZoneInfoNotFoundError as exc:
            raise ValueError("Timezone gecersiz.") from exc
        return self


class MedicationCreate(MedicationBase):
    device_id: str | None = Field(default=None, max_length=120)


class MedicationUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    dosage: str | None = Field(default=None, min_length=1, max_length=120)
    instructions: str | None = None
    schedule_mode: MedicationScheduleMode | None = None
    weekdays: list[int] | None = None
    interval_days: int | None = Field(default=None, ge=1, le=365)
    dose_times: list[time] | None = None
    starts_on: date | None = None
    ends_on: date | None = None
    timezone: str | None = Field(default=None, min_length=1, max_length=64)
    is_active: bool | None = None

    @model_validator(mode="after")
    def validate_schedule(self):
        if self.weekdays is not None and (
            any(day < 0 or day > 6 for day in self.weekdays)
            or (not self.weekdays and self.schedule_mode != "interval")
        ):
            raise ValueError("Gunler 0 ile 6 arasinda olmali.")
        if self.schedule_mode == "weekdays" and self.interval_days is not None:
            raise ValueError("Gun programinda aralik kullanilamaz.")
        if self.schedule_mode == "interval" and self.weekdays not in (None, []):
            raise ValueError("Aralikli programda gunler bos olmali.")
        if self.dose_times is not None and not self.dose_times:
            raise ValueError("En az bir saat gerekli.")
        if self.starts_on is not None and self.ends_on is not None and self.ends_on < self.starts_on:
            raise ValueError("Bitis tarihi baslangictan once olamaz.")
        if self.timezone is not None:
            try:
                ZoneInfo(self.timezone)
            except ZoneInfoNotFoundError as exc:
                raise ValueError("Timezone gecersiz.") from exc
        return self


class MedicationRead(MedicationBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    device_id: str | None = None


class MedicationDoseItem(BaseModel):
    medication_id: int
    medication_name: str
    dosage: str
    instructions: str | None = None
    scheduled_for: datetime
    notify_at: datetime
    status: DoseItemStatus
    taken_at: datetime | None = None
    snoozed_until: datetime | None = None


class MedicationDashboard(BaseModel):
    medications: list[MedicationRead]
    today_doses: list[MedicationDoseItem]
    upcoming_doses: list[MedicationDoseItem]


class MedicationDoseTaken(BaseModel):
    scheduled_for: datetime
    taken_at: datetime | None = None


class MedicationDoseSnooze(BaseModel):
    scheduled_for: datetime
    snooze_minutes: int = Field(default=10, ge=5, le=120)
