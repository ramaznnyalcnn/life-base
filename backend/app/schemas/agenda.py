"""Unified agenda contracts used by mobile screens and widgets."""

from datetime import date, datetime

from pydantic import BaseModel, Field


class AgendaItem(BaseModel):
    id: str
    source_id: int | str
    kind: str
    title: str
    day: date
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    is_all_day: bool = False
    is_important: bool = False
    is_completed: bool = False
    status: str = "pending"
    calendar_exportable: bool = True
    metadata: dict[str, object] = Field(default_factory=dict)
    reminders: list[datetime] = Field(default_factory=list)


class AgendaToday(BaseModel):
    date: date
    timezone: str
    version: int = 0
    overdue: list[AgendaItem] = Field(default_factory=list)
    tasks: list[AgendaItem] = Field(default_factory=list)
    timeline: list[AgendaItem] = Field(default_factory=list)
    next_item: AgendaItem | None = None


class AgendaRange(BaseModel):
    from_date: date
    to_date: date
    timezone: str
    version: int = 0
    items: list[AgendaItem] = Field(default_factory=list)
