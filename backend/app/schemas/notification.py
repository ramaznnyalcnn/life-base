"""Schemas for push notification subscriptions."""

from pydantic import BaseModel, ConfigDict, Field


class PushSubscriptionKeys(BaseModel):
    p256dh: str = Field(min_length=16, max_length=512)
    auth: str = Field(min_length=8, max_length=512)


class PushSubscriptionCreate(BaseModel):
    endpoint: str = Field(min_length=20, max_length=4000)
    keys: PushSubscriptionKeys
    device_label: str | None = Field(default=None, max_length=160)
    user_agent: str | None = None


class PushSubscriptionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    endpoint: str
    device_label: str | None
    user_agent: str | None
    is_active: bool


class PushSubscriptionDelete(BaseModel):
    endpoint: str = Field(min_length=20, max_length=4000)


class PushPublicConfig(BaseModel):
    enabled: bool
    vapid_public_key: str


class PushMessageRequest(BaseModel):
    title: str = Field(min_length=2, max_length=120)
    body: str = Field(min_length=2, max_length=240)
    url: str = Field(default="/", min_length=1, max_length=300)


class PushDispatchResult(BaseModel):
    sent_count: int
    failed_count: int
    deactivated_count: int
    reminder_count: int = 0
    medication_dose_count: int = 0
