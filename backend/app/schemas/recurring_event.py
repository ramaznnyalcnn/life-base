"""Schemas for recurring routine rules."""

from datetime import date, time

from pydantic import BaseModel, ConfigDict, Field, model_validator


class RecurringEventBase(BaseModel):
    title: str = Field(min_length=2, max_length=160)
    description: str | None = None
    weekdays: list[int] = Field(min_length=1)
    starts_on: date
    ends_on: date | None = None
    start_time: time | None = None
    end_time: time | None = None
    is_all_day: bool = False
    is_important: bool = False
    is_active: bool = True
    interval_weeks: int = Field(default=1, ge=1, le=12)

    @model_validator(mode="after")
    def validate_rule(self):
        if any(day < 0 or day > 6 for day in self.weekdays):
            raise ValueError("Gunler 0 ile 6 arasinda olmali.")
        if self.ends_on is not None and self.ends_on < self.starts_on:
            raise ValueError("Bitis tarihi baslangictan once olamaz.")
        if self.is_all_day:
            self.start_time = None
            self.end_time = None
        elif self.end_time is not None and self.start_time is not None and self.end_time <= self.start_time:
            raise ValueError("Bitis saati baslangictan sonra olmali.")
        return self


class RecurringEventCreate(RecurringEventBase):
    device_id: str | None = Field(default=None, max_length=120)


class RecurringEventRead(RecurringEventBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    device_id: str | None = None
