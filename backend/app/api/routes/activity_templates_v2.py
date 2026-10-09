"""Management endpoints for selectable activity templates."""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.security import get_current_user, resolve_route_user
from app.db import get_db
from app.models import ActivityTemplate, ActivityTemplateKind, User
from app.schemas.activity_template import ActivityTemplateCreate, ActivityTemplateRead, ActivityTemplateUpdate
from app.services.activity_templates import ensure_system_activity_templates, list_activity_templates


router = APIRouter(prefix="/activity-templates", tags=["activity-templates-v2"])


def _owned_template(db: Session, template_id: int, user_id: int) -> ActivityTemplate:
    template = db.scalar(select(ActivityTemplate).where(ActivityTemplate.id == template_id))
    if template is None:
        raise HTTPException(status_code=404, detail="Etkinlik sablonu bulunamadi.")
    if template.user_id != user_id or template.is_system:
        raise HTTPException(status_code=403, detail="Sistem sablonu degistirilemez.")
    return template


@router.get("", response_model=list[ActivityTemplateRead])
def list_templates(
    kind: ActivityTemplateKind | None = Query(default=None),
    include_inactive: bool = Query(default=False),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    ensure_system_activity_templates(db)
    return list_activity_templates(
        db, user_id=current_user.id, kind=kind, active_only=not include_inactive
    )


@router.post("", response_model=ActivityTemplateRead, status_code=status.HTTP_201_CREATED)
def create_template(
    payload: ActivityTemplateCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    label = payload.label.strip()
    existing = db.scalar(select(ActivityTemplate).where(
        ActivityTemplate.user_id == current_user.id,
        ActivityTemplate.kind == payload.kind,
        func.lower(ActivityTemplate.label) == label.lower(),
    ))
    if existing is not None:
        raise HTTPException(status_code=409, detail="Bu sablon zaten var.")
    template = ActivityTemplate(
        user_id=current_user.id, kind=payload.kind, label=label, is_system=False, is_active=True
    )
    db.add(template)
    db.commit()
    db.refresh(template)
    return template


@router.patch("/{template_id}", response_model=ActivityTemplateRead)
def update_template(
    template_id: int,
    payload: ActivityTemplateUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    template = _owned_template(db, template_id, current_user.id)
    if payload.label is not None:
        template.label = payload.label.strip()
    if payload.is_active is not None:
        template.is_active = payload.is_active
    db.commit()
    db.refresh(template)
    return template


@router.delete("/{template_id}", status_code=status.HTTP_204_NO_CONTENT)
def deactivate_template(
    template_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    template = _owned_template(db, template_id, current_user.id)
    template.is_active = False
    db.commit()
