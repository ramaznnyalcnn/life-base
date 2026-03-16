"""Calendar event and reminder models."""

from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum

from sqlalchemy import Boolean, DateTime, Enum as SqlEnum, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin


def enum_values(enum_cls: type[Enum]) -> list[str]:
    return [member.value for member in enum_cls]


class ReminderChannel(str, Enum):
    WEB_PUSH = "web_push"
    TELEGRAM = "telegram"


class Event(TimestampMixin, Base):
    """User events and scheduled items."""

    __tablename__ = "events"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    device_id: Mapped[str | None] = mapped_column(String(120), nullable=True, index=True)
    title: Mapped[str] = mapped_column(String(160), index=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    is_all_day: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    is_important: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False, index=True)

    user = relationship("User", back_populates="events")
    reminders = relationship(
        "Reminder",
        back_populates="event",
        cascade="all, delete-orphan",
        order_by="Reminder.remind_at",
    )


class Reminder(TimestampMixin, Base):
    """Scheduled reminders for events."""

    __tablename__ = "reminders"

    id: Mapped[int] = mapped_column(primary_key=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), index=True)
    remind_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        index=True,
    )
    channel: Mapped[ReminderChannel] = mapped_column(
        SqlEnum(ReminderChannel, values_callable=enum_values, name="reminderchannel"),
        default=ReminderChannel.WEB_PUSH,
        index=True,
    )
    is_sent: Mapped[bool] = mapped_column(Boolean, default=False, index=True)

    event = relationship("Event", back_populates="reminders")
