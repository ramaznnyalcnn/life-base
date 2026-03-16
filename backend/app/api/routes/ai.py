"""AI parse endpoints."""

from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import ValidationError
from sqlalchemy.orm import Session

from app.api.security import get_current_user, resolve_route_user
from app.db import get_db
from app.models import User
from app.schemas import AIClarificationRequest, AIExecutionResponse, AIParseRequest, AIParseResponse
from app.services.ai_execution import AIExecutionService, get_ai_execution_service
from app.services.ai_parser import AIParserService, get_ai_parser_service


router = APIRouter(prefix="/ai", tags=["ai"])


def _device_id(value: str | None) -> str | None:
    return value if isinstance(value, str) else None


@router.post(
    "/parse",
    response_model=AIParseResponse,
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(get_current_user)],
)
def parse_message(
    payload: AIParseRequest,
    service: AIParserService = Depends(get_ai_parser_service),
):
    try:
        return service.parse(payload)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except (ValueError, ValidationError) as exc:
        raise HTTPException(status_code=502, detail=f"AI yaniti gecersiz: {exc}") from exc


@router.post("/execute", response_model=AIExecutionResponse, status_code=status.HTTP_200_OK)
def execute_message(
    payload: AIParseRequest,
    db: Session = Depends(get_db),
    parser_service: AIParserService = Depends(get_ai_parser_service),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    execution_service = get_ai_execution_service(parser_service)
    try:
        payload.device_id = payload.device_id or _device_id(x_device_id)
        return execution_service.execute_message(db, payload, user_id=current_user.id)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except (ValueError, ValidationError) as exc:
        raise HTTPException(status_code=502, detail=f"AI yaniti gecersiz: {exc}") from exc


@router.post("/clarify", response_model=AIExecutionResponse, status_code=status.HTTP_200_OK)
def clarify_message(
    payload: AIClarificationRequest,
    db: Session = Depends(get_db),
    parser_service: AIParserService = Depends(get_ai_parser_service),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    execution_service = get_ai_execution_service(parser_service)
    try:
        payload.device_id = payload.device_id or _device_id(x_device_id)
        return execution_service.continue_with_clarification(db, payload, user_id=current_user.id)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except (ValueError, ValidationError) as exc:
        raise HTTPException(status_code=502, detail=f"AI yaniti gecersiz: {exc}") from exc
