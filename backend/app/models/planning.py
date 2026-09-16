"""Planning templates and task persistence models."""

from __future__ import annotations

from datetime import date, datetime
from enum import Enum

from sqlalchemy import Boolean, Date, DateTime, Enum as SqlEnum, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, EntityVersionMixin, TimestampMixin
from app.models.event import enum_values


class ActivityTemplateKind(str, Enum):
    TASK = "task"
    EVENT = "event"
    ROUTINE = "routine"


class ActivityTemplate(EntityVersionMixin, TimestampMixin, Base):
    """Reusable selection shown by structured planning operations."""

    __tablename__ = "activity_templates"
    __table_args__ = (
        UniqueConstraint("user_id", "kind", "label", name="uq_activity_templates_user_kind_label"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    kind: Mapped[ActivityTemplateKind] = mapped_column(
        SqlEnum(ActivityTemplateKind, values_callable=enum_values, name="activitytemplatekind"),
        index=True,
    )
    label: Mapped[str] = mapped_column(String(160), index=True)
    is_system: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)

    user = relationship("User", back_populates="activity_templates")
    tasks = relationship("Task", back_populates="template")
    events = relationship("Event", back_populates="template")
    recurring_events = relationship("RecurringEvent", back_populates="template")


class Task(EntityVersionMixin, TimestampMixin, Base):
    """Completable work item that may optionally have a clock time."""

    __tablename__ = "tasks"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    device_id: Mapped[str | None] = mapped_column(String(120), nullable=True, index=True)
    template_id: Mapped[int | None] = mapped_column(
        ForeignKey("activity_templates.id"), nullable=True, index=True
    )
    title: Mapped[str] = mapped_column(String(160), index=True)
    due_on: Mapped[date] = mapped_column(Date, index=True)
    scheduled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    is_important: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user = relationship("User", back_populates="tasks")
    template = relationship("ActivityTemplate", back_populates="tasks")
    reminders = relationship(
        "Reminder",
        back_populates="task",
        cascade="all, delete-orphan",
        order_by="Reminder.remind_at",
    )
