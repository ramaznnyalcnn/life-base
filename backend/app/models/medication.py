"""Medication reminder models."""

from __future__ import annotations

from datetime import datetime, date
from enum import Enum

from sqlalchemy import Boolean, Date, DateTime, Enum as SqlEnum, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin
from app.models.event import enum_values


class MedicationDoseStatus(str, Enum):
    TAKEN = "taken"
    SNOOZED = "snoozed"


class Medication(TimestampMixin, Base):
    """Recurring medication schedule owned by a user/device."""

    __tablename__ = "medications"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    device_id: Mapped[str | None] = mapped_column(String(120), nullable=True, index=True)
    name: Mapped[str] = mapped_column(String(120), index=True)
    dosage: Mapped[str] = mapped_column(String(120))
    instructions: Mapped[str | None] = mapped_column(Text, nullable=True)
    schedule_mode: Mapped[str] = mapped_column(String(16), default="weekdays")
    weekdays: Mapped[str] = mapped_column(String(32))
    interval_days: Mapped[int | None] = mapped_column(Integer, nullable=True)
    dose_times: Mapped[str] = mapped_column(String(255))
    starts_on: Mapped[date] = mapped_column(Date, index=True)
    ends_on: Mapped[date | None] = mapped_column(Date, nullable=True, index=True)
    timezone: Mapped[str] = mapped_column(String(64), default="Europe/Istanbul")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)

    user = relationship("User", back_populates="medications")
    dose_logs = relationship(
        "MedicationDoseLog",
        back_populates="medication",
        cascade="all, delete-orphan",
        order_by="MedicationDoseLog.scheduled_for",
    )


class MedicationDoseLog(TimestampMixin, Base):
    """User action for a scheduled medication dose."""

    __tablename__ = "medication_dose_logs"
    __table_args__ = (
        UniqueConstraint("medication_id", "scheduled_for", name="uq_medication_dose_logs_medication_id_scheduled_for"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    medication_id: Mapped[int] = mapped_column(ForeignKey("medications.id"), index=True)
    scheduled_for: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    status: Mapped[MedicationDoseStatus] = mapped_column(
        SqlEnum(MedicationDoseStatus, values_callable=enum_values, name="medicationdosestatus"),
        index=True,
    )
    taken_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    snoozed_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)

    medication = relationship("Medication", back_populates="dose_logs")


class MedicationPushDelivery(TimestampMixin, Base):
    """Successful push delivery for one medication dose notification."""

    __tablename__ = "medication_push_deliveries"
    __table_args__ = (
        UniqueConstraint(
            "push_subscription_id",
            "medication_id",
            "scheduled_for",
            "notify_at",
            name="uq_medication_push_delivery_target_dose_time",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    push_subscription_id: Mapped[int] = mapped_column(ForeignKey("push_subscriptions.id"), index=True)
    medication_id: Mapped[int] = mapped_column(ForeignKey("medications.id"), index=True)
    scheduled_for: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    notify_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    sent_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
