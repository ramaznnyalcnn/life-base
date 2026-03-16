"""Push notification subscription helpers."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from urllib.parse import urlparse

from sqlalchemy import select
from sqlalchemy.orm import Session
from pywebpush import WebPushException, webpush

from app.core.config import Settings, get_settings
from app.models import Event, PushSubscription, Reminder, ReminderChannel
from app.schemas import PushDispatchResult, PushMessageRequest, PushSubscriptionCreate
from app.services.auth import ensure_default_user


def _resolve_user_id(session: Session, user_id: int | None) -> int:
    return user_id if user_id is not None else ensure_default_user(session).id


def list_push_subscriptions(
    session: Session,
    user_id: int | None = None,
    device_id: str | None = None,
) -> list[PushSubscription]:
    owner_id = _resolve_user_id(session, user_id)
    query = (
        select(PushSubscription)
        .where(PushSubscription.is_active.is_(True))
        .where(PushSubscription.user_id == owner_id)
        .order_by(PushSubscription.id.desc())
    )
    if device_id:
        query = query.where(PushSubscription.device_id == device_id)
    return list(session.scalars(query).all())


def upsert_push_subscription(
    session: Session,
    payload: PushSubscriptionCreate,
    user_id: int | None = None,
    device_id: str | None = None,
) -> PushSubscription:
    owner_id = _resolve_user_id(session, user_id)
    existing = session.scalar(
        select(PushSubscription).where(
            PushSubscription.endpoint == payload.endpoint,
            PushSubscription.user_id == owner_id,
        )
    )
    if existing is not None:
        existing.p256dh = payload.keys.p256dh
        existing.auth = payload.keys.auth
        existing.user_id = owner_id
        existing.device_id = device_id
        existing.device_label = payload.device_label
        existing.user_agent = payload.user_agent
        existing.is_active = True
        session.commit()
        session.refresh(existing)
        return existing

    subscription = PushSubscription(
        user_id=owner_id,
        device_id=device_id,
        endpoint=payload.endpoint,
        p256dh=payload.keys.p256dh,
        auth=payload.keys.auth,
        device_label=payload.device_label,
        user_agent=payload.user_agent,
        is_active=True,
    )
    session.add(subscription)
    session.commit()
    session.refresh(subscription)
    return subscription


def deactivate_push_subscription(
    session: Session,
    endpoint: str,
    *,
    user_id: int | None = None,
) -> None:
    owner_id = _resolve_user_id(session, user_id)
    subscription = session.scalar(
        select(PushSubscription).where(
            PushSubscription.endpoint == endpoint,
            PushSubscription.user_id == owner_id,
        )
    )
    if subscription is None:
        return
    subscription.is_active = False
    session.commit()


def _subscription_payload(subscription: PushSubscription) -> dict[str, object]:
    return {
        "endpoint": subscription.endpoint,
        "keys": {
            "p256dh": subscription.p256dh,
            "auth": subscription.auth,
        },
    }


def _aud_from_endpoint(endpoint: str) -> str:
    parsed = urlparse(endpoint)
    return f"{parsed.scheme}://{parsed.netloc}"


class WebPushGateway:
    """Thin wrapper around pywebpush for easier testing."""

    def send(
        self,
        subscription: PushSubscription,
        payload: dict[str, str],
        settings: Settings,
    ) -> None:
        webpush(
            subscription_info=_subscription_payload(subscription),
            data=json.dumps(payload),
            vapid_private_key=settings.vapid_private_key,
            vapid_claims={
                "sub": settings.vapid_subject,
                "aud": _aud_from_endpoint(subscription.endpoint),
            },
        )


def _ensure_push_ready(settings: Settings) -> None:
    if not settings.enable_web_push:
        raise ValueError("Web push aktif degil.")
    if not settings.vapid_public_key or not settings.vapid_private_key:
        raise ValueError("VAPID ayarlari eksik.")


def send_push_message(
    session: Session,
    request: PushMessageRequest,
    *,
    user_id: int | None = None,
    device_id: str | None = None,
    gateway: WebPushGateway | None = None,
    settings: Settings | None = None,
) -> PushDispatchResult:
    settings = settings or get_settings()
    _ensure_push_ready(settings)
    gateway = gateway or WebPushGateway()
    owner_id = _resolve_user_id(session, user_id)
    subscriptions = list_push_subscriptions(session, user_id=owner_id, device_id=device_id)

    sent_count = 0
    failed_count = 0
    deactivated_count = 0
    for subscription in subscriptions:
        try:
            gateway.send(
                subscription,
                {
                    "title": request.title,
                    "body": request.body,
                    "url": request.url,
                },
                settings,
            )
            sent_count += 1
        except WebPushException as exc:
            failed_count += 1
            status_code = getattr(getattr(exc, "response", None), "status_code", None)
            if status_code in {404, 410}:
                deactivate_push_subscription(session, subscription.endpoint, user_id=owner_id)
                deactivated_count += 1

    return PushDispatchResult(
        sent_count=sent_count,
        failed_count=failed_count,
        deactivated_count=deactivated_count,
    )


def dispatch_due_reminders(
    session: Session,
    *,
    now: datetime | None = None,
    user_id: int | None = None,
    device_id: str | None = None,
    limit: int = 20,
    gateway: WebPushGateway | None = None,
    settings: Settings | None = None,
) -> PushDispatchResult:
    settings = settings or get_settings()
    _ensure_push_ready(settings)
    gateway = gateway or WebPushGateway()
    owner_id = _resolve_user_id(session, user_id)
    current_time = now or datetime.now(timezone.utc)
    reminders = list(
        session.scalars(
            select(Reminder)
            .join(Event, Event.id == Reminder.event_id)
            .where(
                Reminder.is_sent.is_(False),
                Reminder.channel == ReminderChannel.WEB_PUSH,
                Reminder.remind_at <= current_time,
                Event.user_id == owner_id,
                Event.device_id == device_id if device_id else True,
            )
            .order_by(Reminder.remind_at.asc(), Reminder.id.asc())
            .limit(limit)
        ).all()
    )

    sent_count = 0
    failed_count = 0
    deactivated_count = 0
    reminder_count = 0

    subscriptions = list_push_subscriptions(session, user_id=owner_id)
    for reminder in reminders:
        reminder_count += 1
        reminder_sent = 0
        reminder_subscriptions = [
            subscription
            for subscription in subscriptions
            if reminder.event.device_id is None or subscription.device_id == reminder.event.device_id
        ]
        for subscription in reminder_subscriptions:
            try:
                gateway.send(
                    subscription,
                    {
                        "title": reminder.event.title,
                        "body": reminder.event.description or "Yaklasan etkinlik hatirlatmasi.",
                        "url": "/",
                    },
                    settings,
                )
                sent_count += 1
                reminder_sent += 1
            except WebPushException as exc:
                failed_count += 1
                status_code = getattr(getattr(exc, "response", None), "status_code", None)
                if status_code in {404, 410}:
                    deactivate_push_subscription(session, subscription.endpoint, user_id=owner_id)
                    deactivated_count += 1

        if reminder_sent > 0:
            reminder.is_sent = True

    session.commit()
    return PushDispatchResult(
        sent_count=sent_count,
        failed_count=failed_count,
        deactivated_count=deactivated_count,
        reminder_count=reminder_count,
    )
