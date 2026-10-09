"""Activity template bootstrap and management."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import ActivityTemplate, ActivityTemplateKind


DEFAULT_ACTIVITY_TEMPLATES: dict[ActivityTemplateKind, tuple[str, ...]] = {
    ActivityTemplateKind.TASK: ("Alisveris", "Arama", "Ev isi", "Calisma", "Spor", "Diger"),
    ActivityTemplateKind.EVENT: ("Toplanti", "Randevu", "Ders", "Seyahat", "Diger"),
    ActivityTemplateKind.ROUTINE: ("Spor", "Okuma", "Calisma", "Bakim", "Diger"),
}


def ensure_system_activity_templates(session: Session) -> int:
    existing = set(
        session.execute(
            select(ActivityTemplate.kind, ActivityTemplate.label).where(ActivityTemplate.user_id.is_(None))
        ).all()
    )
    created = 0
    for kind, labels in DEFAULT_ACTIVITY_TEMPLATES.items():
        for label in labels:
            if (kind, label) in existing:
                continue
            session.add(ActivityTemplate(kind=kind, label=label, is_system=True, is_active=True))
            created += 1
    if created:
        session.commit()
    return created


def list_activity_templates(
    session: Session,
    *,
    user_id: int,
    kind: ActivityTemplateKind | None = None,
    active_only: bool = True,
) -> list[ActivityTemplate]:
    query = select(ActivityTemplate).where(
        (ActivityTemplate.user_id == user_id) | (ActivityTemplate.user_id.is_(None))
    )
    if kind is not None:
        query = query.where(ActivityTemplate.kind == kind)
    if active_only:
        query = query.where(ActivityTemplate.is_active.is_(True))
    return list(session.scalars(query.order_by(ActivityTemplate.kind, ActivityTemplate.label)).all())
