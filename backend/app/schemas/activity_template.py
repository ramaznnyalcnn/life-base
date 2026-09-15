"""Schemas for user-managed planning selections."""

from pydantic import BaseModel, ConfigDict, Field

from app.models import ActivityTemplateKind


class ActivityTemplateCreate(BaseModel):
    kind: ActivityTemplateKind
    label: str = Field(min_length=1, max_length=160)


class ActivityTemplateUpdate(BaseModel):
    label: str | None = Field(default=None, min_length=1, max_length=160)
    is_active: bool | None = None


class ActivityTemplateRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    kind: ActivityTemplateKind
    label: str
    is_system: bool
    is_active: bool
