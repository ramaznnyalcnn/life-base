"""Execution layer for AI parse results."""

from __future__ import annotations

from datetime import timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Account, AccountType, TransactionType
from app.schemas import (
    AIAction,
    AIClarificationRequest,
    AIExecutionResponse,
    AIExecutionStatus,
    AIParseRequest,
    AIParseResponse,
    EventCreate,
    RecurringEventCreate,
    TransferCreate,
    TransactionCreate,
)
from app.services.ai_parser import AIParserService
from app.services.auth import ensure_default_user
from app.services.events import create_event
from app.services.finance import create_transaction, resolve_account
from app.services.recurring_events import create_recurring_event
from app.services.transfers import create_transfer


class AIExecutionService:
    """Turn parsed AI intent into real domain actions."""

    def __init__(self, parser_service: AIParserService):
        self.parser_service = parser_service

    @staticmethod
    def _resolve_user_id(session: Session, user_id: int | None) -> int:
        return user_id if user_id is not None else ensure_default_user(session).id

    @staticmethod
    def build_follow_up_question(parse_result: AIParseResponse) -> str:
        """Build a natural follow-up question for missing fields."""

        missing = set(parse_result.missing_fields)

        if "account_name" in missing:
            if parse_result.action == AIAction.PAYMENT:
                return "Parayi hangi kart veya hesaba gonderdin?"
            return "Bunu hangi hesap veya kart ile kaydedeyim?"

        if parse_result.action == AIAction.PAYMENT:
            if {"source_account_name", "destination_account_name"} <= missing:
                return "Parayi hangi hesaptan hangi kart veya hesaba gonderdin?"
            if "source_account_name" in missing:
                return "Odemeyi hangi hesaptan yaptin?"
            if "destination_account_name" in missing:
                return "Parayi hangi kart veya hesaba gonderdin?"

        if "amount" in missing:
            if parse_result.action == AIAction.INCOME:
                return "Tutar ne kadar?"
            if parse_result.action == AIAction.PAYMENT:
                return "Odeme tutari ne kadar?"
            return "Harcama tutari ne kadar?"

        if "recurrence_days" in missing:
            return "Hangi gunlerde tekrar etsin?"

        if {"title", "starts_at"} <= missing:
            return "Etkinligin adi ne ve hangi gun veya tarihte olsun? Saat zorunlu degil."
        if "title" in missing:
            return "Etkinligin adi ne?"
        if "starts_at" in missing:
            return "Hangi gun veya tarihte olsun? Saat zorunlu degil."
        if "description" in missing:
            return "Bunu kisaca nasil aciklayayim?"

        return "Eksik kalan bilgiyi biraz daha net yazar misin?"

    @classmethod
    def _needs_input(cls, parse_result: AIParseResponse, message: str | None = None) -> AIExecutionResponse:
        follow_up_question = cls.build_follow_up_question(parse_result)
        return AIExecutionResponse(
            status=AIExecutionStatus.NEEDS_INPUT,
            parse_result=parse_result,
            assistant_message=message or parse_result.assistant_message,
            missing_fields=parse_result.missing_fields,
            follow_up_question=follow_up_question,
        )

    def _execute_payment(
        self,
        session: Session,
        parse_result: AIParseResponse,
        *,
        user_id: int | None = None,
    ) -> AIExecutionResponse:
        owner_id = self._resolve_user_id(session, user_id)
        tx = parse_result.transaction
        assert tx is not None

        source_account, destination_account = self._resolve_payment_accounts(session, owner_id, parse_result)
        if source_account is None or destination_account is None:
            return self._needs_input(parse_result)

        created = create_transfer(
            session,
            TransferCreate(
                source_account_id=source_account.id,
                destination_account_id=destination_account.id,
                amount=tx.amount,
                description=tx.description,
                occurred_at=tx.occurred_at.astimezone(timezone.utc) if tx.occurred_at else None,
            ),
            user_id=owner_id,
        )

        return AIExecutionResponse(
            status=AIExecutionStatus.COMPLETED,
            parse_result=parse_result,
            assistant_message=parse_result.assistant_message,
            missing_fields=[],
            follow_up_question=None,
            transfer_id=created.id,
        )

    @staticmethod
    def _list_owned_accounts(
        session: Session,
        owner_id: int,
        account_types: set[AccountType],
    ) -> list[Account]:
        return list(
            session.scalars(
                select(Account)
                .where(
                    Account.user_id == owner_id,
                    Account.is_active.is_(True),
                    Account.type.in_(account_types),
                )
                .order_by(Account.id.asc())
            ).all()
        )

    def _resolve_payment_accounts(
        self,
        session: Session,
        owner_id: int,
        parse_result: AIParseResponse,
    ) -> tuple[Account | None, Account | None]:
        tx = parse_result.transaction
        assert tx is not None

        source_name = tx.source_account_name
        destination_name = tx.destination_account_name or tx.account_name

        source_account = resolve_account(session, source_name, owner_id) if source_name else None
        if source_account is None and not source_name:
            source_candidates = self._list_owned_accounts(session, owner_id, {AccountType.BANK, AccountType.CASH})
            if len(source_candidates) == 1:
                source_account = source_candidates[0]
                tx.source_account_name = source_account.name

        destination_account = resolve_account(session, destination_name, owner_id) if destination_name else None
        if destination_account is None and not destination_name:
            destination_candidates = self._list_owned_accounts(session, owner_id, {AccountType.CREDIT_CARD})
            if len(destination_candidates) == 1:
                destination_account = destination_candidates[0]
                tx.destination_account_name = destination_account.name

        if source_account is None:
            if "source_account_name" not in parse_result.missing_fields:
                parse_result.missing_fields.append("source_account_name")
        else:
            parse_result.missing_fields = [field for field in parse_result.missing_fields if field != "source_account_name"]

        if destination_account is None:
            if "destination_account_name" not in parse_result.missing_fields:
                parse_result.missing_fields.append("destination_account_name")
        else:
            parse_result.missing_fields = [
                field for field in parse_result.missing_fields if field not in {"destination_account_name", "account_name"}
            ]

        return source_account, destination_account

    def _execute_transaction(
        self,
        session: Session,
        parse_result: AIParseResponse,
        *,
        user_id: int | None = None,
    ) -> AIExecutionResponse:
        owner_id = self._resolve_user_id(session, user_id)
        tx = parse_result.transaction
        assert tx is not None

        account = resolve_account(session, tx.account_name, owner_id)
        if account is None:
            if "account_name" not in parse_result.missing_fields:
                parse_result.missing_fields.append("account_name")
            return self._needs_input(
                parse_result,
                "Islemi hangi hesap veya kart ile kaydedecegimi netlestirmen gerekiyor.",
            )

        if parse_result.missing_fields:
            return self._needs_input(parse_result)

        action_map = {
            AIAction.EXPENSE: TransactionType.EXPENSE,
            AIAction.INCOME: TransactionType.INCOME,
            AIAction.PAYMENT: TransactionType.PAYMENT,
        }

        created = create_transaction(
            session,
            TransactionCreate(
                account_id=account.id,
                category_name=tx.category_name,
                type=action_map[parse_result.action],
                amount=tx.amount,
                description=tx.description,
                occurred_at=tx.occurred_at.astimezone(timezone.utc) if tx.occurred_at else None,
            ),
            user_id=owner_id,
        )

        return AIExecutionResponse(
            status=AIExecutionStatus.COMPLETED,
            parse_result=parse_result,
            assistant_message=parse_result.assistant_message,
            missing_fields=[],
            follow_up_question=None,
            transaction_id=created.id,
        )

    def _execute_event(
        self,
        session: Session,
        parse_result: AIParseResponse,
        *,
        user_id: int | None = None,
        device_id: str | None = None,
    ) -> AIExecutionResponse:
        owner_id = self._resolve_user_id(session, user_id)
        event = parse_result.event
        assert event is not None

        if parse_result.missing_fields:
            return self._needs_input(parse_result)

        if event.is_recurring or event.recurrence_days:
            created = create_recurring_event(
                session,
                RecurringEventCreate(
                    title=event.title,
                    description=event.description,
                    weekdays=event.recurrence_days,
                    starts_on=event.starts_at.date(),
                    start_time=None if event.is_all_day else event.starts_at.timetz().replace(tzinfo=None),
                    end_time=(
                        None
                        if event.is_all_day or event.ends_at is None
                        else event.ends_at.timetz().replace(tzinfo=None)
                    ),
                    is_all_day=event.is_all_day,
                    is_important=False,
                    device_id=device_id,
                ),
                user_id=owner_id,
            )

            return AIExecutionResponse(
                status=AIExecutionStatus.COMPLETED,
                parse_result=parse_result,
                assistant_message=parse_result.assistant_message,
                missing_fields=[],
                follow_up_question=None,
                recurring_event_id=created.id,
            )

        created = create_event(
            session,
            EventCreate(
                title=event.title,
                description=event.description,
                starts_at=event.starts_at.astimezone(timezone.utc) if event.starts_at else None,
                ends_at=event.ends_at.astimezone(timezone.utc) if event.ends_at else None,
                is_all_day=event.is_all_day,
                reminder_offsets_minutes=None,
                device_id=device_id,
            ),
            user_id=owner_id,
        )

        return AIExecutionResponse(
            status=AIExecutionStatus.COMPLETED,
            parse_result=parse_result,
            assistant_message=parse_result.assistant_message,
            missing_fields=[],
            follow_up_question=None,
            event_id=created.id,
        )

    def execute_parse_result(
        self,
        session: Session,
        parse_result: AIParseResponse,
        *,
        user_id: int | None = None,
        device_id: str | None = None,
    ) -> AIExecutionResponse:
        """Execute a previously parsed AI result."""

        if parse_result.action == AIAction.PAYMENT:
            return self._execute_payment(session, parse_result, user_id=user_id)

        if parse_result.action in {AIAction.EXPENSE, AIAction.INCOME}:
            return self._execute_transaction(session, parse_result, user_id=user_id)

        if parse_result.action == AIAction.EVENT:
            return self._execute_event(session, parse_result, user_id=user_id, device_id=device_id)

        if parse_result.action == AIAction.SUMMARY:
            return AIExecutionResponse(
                status=AIExecutionStatus.UNSUPPORTED,
                parse_result=parse_result,
                assistant_message="Ozet ve analiz tarafini arayuzden gosterecegiz; bu mesaj kayit olusturmuyor.",
                missing_fields=[],
                follow_up_question=None,
            )

        return self._needs_input(
            parse_result,
            "Mesaji dogrudan isleme ceviremedim. Biraz daha net yazman gerekiyor.",
        )

    def execute_message(
        self,
        session: Session,
        request: AIParseRequest,
        *,
        user_id: int | None = None,
    ) -> AIExecutionResponse:
        """Parse a raw message and execute it when safe."""

        parse_result = self.parser_service.parse(request)
        return self.execute_parse_result(session, parse_result, user_id=user_id, device_id=request.device_id)

    def continue_with_clarification(
        self,
        session: Session,
        request: AIClarificationRequest,
        *,
        user_id: int | None = None,
    ) -> AIExecutionResponse:
        """Re-run the parse with the user's clarification merged in."""

        combined_message = (
            f"Ilk mesaj: {request.original_message}\n"
            f"Ek bilgi: {request.clarification}"
        )
        return self.execute_message(
            session,
            AIParseRequest(message=combined_message, device_id=request.device_id),
            user_id=user_id,
        )


def get_ai_execution_service(parser_service: AIParserService) -> AIExecutionService:
    """Factory for the execution service."""

    return AIExecutionService(parser_service)
    @staticmethod
    def _resolve_user_id(session: Session, user_id: int | None) -> int:
        return user_id if user_id is not None else ensure_default_user(session).id
