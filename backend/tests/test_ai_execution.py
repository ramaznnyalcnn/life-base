from datetime import datetime, timezone
from decimal import Decimal

from app.main import app
from app.models import Account, AccountType, Event, RecurringEvent, Transaction, Transfer
from app.schemas import AIAction, AIClarificationRequest, AIExecutionStatus, AIParseRequest, AIParseResponse
from app.services.ai_execution import AIExecutionService
from app.services.ai_parser import AIParserService


class ExecutionGateway:
    def __init__(self, responses: dict[str, str]):
        self.responses = responses
        self.settings = type(
            "Settings",
            (),
            {
                "openrouter_models": ["stepfun/step-3.5-flash:free"],
                "openrouter_model": "stepfun/step-3.5-flash:free",
            },
        )()

    def complete(self, model: str, system_prompt: str, user_message: str, response_schema: dict) -> str:
        return self.responses[user_message]


def make_execution_service(responses: dict[str, str]) -> AIExecutionService:
    parser = AIParserService(
        ExecutionGateway(responses),
        now_provider=lambda: datetime(2026, 3, 9, 12, 0, tzinfo=timezone.utc),
    )
    return AIExecutionService(parser)


def test_follow_up_question_builder_covers_core_missing_field_cases():
    amount_case = AIParseResponse.model_validate(
        {
            "action": "expense",
            "confidence": 0.7,
            "missing_fields": ["amount"],
            "assistant_message": "Tutar eksik.",
            "transaction": {
                "amount": None,
                "account_name": None,
                "category_name": "Market",
                "description": "Market",
                "occurred_at": "2026-03-09T12:00:00+00:00",
            },
            "event": None,
            "summary": None,
        }
    )
    event_case = AIParseResponse.model_validate(
        {
            "action": "event",
            "confidence": 0.6,
            "missing_fields": ["title", "starts_at"],
            "assistant_message": "Eksik bilgi var.",
            "transaction": None,
            "event": {
                "title": None,
                "description": None,
                "starts_at": None,
                "ends_at": None,
            },
            "summary": None,
        }
    )

    assert AIExecutionService.build_follow_up_question(amount_case) == "Harcama tutari ne kadar?"
    assert (
        AIExecutionService.build_follow_up_question(event_case)
        == "Etkinligin adi ne ve hangi gun veya tarihte olsun? Saat zorunlu degil."
    )


def test_execute_message_creates_expense_using_single_account_fallback(db_session):
    account = Account(
        name="Ana Kart",
        type=AccountType.CREDIT_CARD,
        currency="TRY",
        balance=Decimal("10000.00"),
        credit_limit=Decimal("30000.00"),
        statement_day=20,
        due_day=1,
    )
    db_session.add(account)
    db_session.commit()

    service = make_execution_service(
        {
            "350 tl migros": """
            {"action":"expense","confidence":0.97,"missing_fields":[],"assistant_message":"350 TL market harcamasi olarak algiladim.","transaction":{"amount":350,"account_name":null,"category_name":"Market","description":"Migros harcamasi","occurred_at":"2026-03-09T12:00:00+00:00"},"event":null,"summary":null}
            """,
        }
    )

    result = service.execute_message(db_session, AIParseRequest(message="350 tl migros"))

    assert result.status == AIExecutionStatus.COMPLETED
    assert result.transaction_id is not None
    saved = db_session.get(Transaction, result.transaction_id)
    assert saved is not None
    assert saved.account_id == account.id
    assert saved.amount == Decimal("350")
    assert db_session.get(Account, account.id).balance == Decimal("9650.00")


def test_execute_message_requires_account_when_multiple_accounts_exist(db_session):
    db_session.add_all(
        [
            Account(name="Enpara", type=AccountType.BANK, currency="TRY", balance=Decimal("5000.00")),
            Account(name="Akbank", type=AccountType.CREDIT_CARD, currency="TRY", balance=Decimal("8000.00"), credit_limit=Decimal("20000.00")),
        ]
    )
    db_session.commit()

    service = make_execution_service(
        {
            "120 kahve": """
            {"action":"expense","confidence":0.94,"missing_fields":[],"assistant_message":"Kahve harcamasi olarak algiladim.","transaction":{"amount":120,"account_name":null,"category_name":"Kahve","description":"Kahve harcamasi","occurred_at":"2026-03-09T12:00:00+00:00"},"event":null,"summary":null}
            """,
        }
    )

    result = service.execute_message(db_session, AIParseRequest(message="120 kahve"))

    assert result.status == AIExecutionStatus.NEEDS_INPUT
    assert result.transaction_id is None
    assert result.missing_fields == ["account_name"]
    assert result.follow_up_question == "Bunu hangi hesap veya kart ile kaydedeyim?"


def test_execute_message_creates_transfer_for_payment_intent(db_session):
    source = Account(
        name="Enpara",
        type=AccountType.BANK,
        currency="TRY",
        balance=Decimal("8000.00"),
    )
    destination = Account(
        name="Ziraat",
        type=AccountType.CREDIT_CARD,
        currency="TRY",
        balance=Decimal("6000.00"),
        credit_limit=Decimal("25000.00"),
        statement_day=15,
        due_day=2,
    )
    db_session.add_all([source, destination])
    db_session.commit()

    service = make_execution_service(
        {
            "enpara hesabimdan ziraat karta 5000 odeme yaptim": """
            {"action":"payment","confidence":0.95,"missing_fields":[],"assistant_message":"Kart odemesi olarak algiladim.","transaction":{"amount":5000,"account_name":"Ziraat","source_account_name":"Enpara","destination_account_name":"Ziraat","category_name":null,"description":"Kredi karti odemesi","occurred_at":"2026-03-09T12:00:00+00:00"},"event":null,"summary":null}
            """,
        }
    )

    result = service.execute_message(
        db_session,
        AIParseRequest(message="enpara hesabimdan ziraat karta 5000 odeme yaptim"),
    )

    assert result.status == AIExecutionStatus.COMPLETED
    assert result.transfer_id is not None
    saved = db_session.get(Transfer, result.transfer_id)
    assert saved is not None
    assert saved.source_account_id == source.id
    assert saved.destination_account_id == destination.id
    assert db_session.get(Account, source.id).balance == Decimal("3000.00")
    assert db_session.get(Account, destination.id).balance == Decimal("11000.00")


def test_execute_message_auto_selects_single_source_account_for_card_payment(db_session):
    source = Account(
        name="Enpara",
        type=AccountType.BANK,
        currency="TRY",
        balance=Decimal("5000.00"),
    )
    destination = Account(
        name="Ziraat",
        type=AccountType.CREDIT_CARD,
        currency="TRY",
        balance=Decimal("9000.00"),
        credit_limit=Decimal("25000.00"),
        statement_day=15,
        due_day=2,
    )
    db_session.add_all([source, destination])
    db_session.commit()

    service = make_execution_service(
        {
            "ziraat karta 490 odedim": """
            {"action":"payment","confidence":0.95,"missing_fields":[],"assistant_message":"Kart odemesi olarak algiladim.","transaction":{"amount":490,"account_name":"Ziraat","source_account_name":null,"destination_account_name":"Ziraat","category_name":null,"description":"Kredi karti odemesi","occurred_at":"2026-03-09T12:00:00+00:00"},"event":null,"summary":null}
            """,
        }
    )

    result = service.execute_message(db_session, AIParseRequest(message="ziraat karta 490 odedim"))

    assert result.status == AIExecutionStatus.COMPLETED
    saved = db_session.get(Transfer, result.transfer_id)
    assert saved is not None
    assert saved.source_account_id == source.id
    assert saved.destination_account_id == destination.id


def test_execute_message_asks_for_source_when_multiple_cash_accounts_exist(db_session):
    db_session.add_all(
        [
            Account(name="Enpara", type=AccountType.BANK, currency="TRY", balance=Decimal("5000.00")),
            Account(name="Nakit", type=AccountType.CASH, currency="TRY", balance=Decimal("1200.00")),
            Account(
                name="Ziraat",
                type=AccountType.CREDIT_CARD,
                currency="TRY",
                balance=Decimal("9000.00"),
                credit_limit=Decimal("25000.00"),
            ),
        ]
    )
    db_session.commit()

    service = make_execution_service(
        {
            "ziraat karta 490 odedim": """
            {"action":"payment","confidence":0.95,"missing_fields":[],"assistant_message":"Kart odemesi olarak algiladim.","transaction":{"amount":490,"account_name":"Ziraat","source_account_name":null,"destination_account_name":"Ziraat","category_name":null,"description":"Kredi karti odemesi","occurred_at":"2026-03-09T12:00:00+00:00"},"event":null,"summary":null}
            """,
        }
    )

    result = service.execute_message(db_session, AIParseRequest(message="ziraat karta 490 odedim"))

    assert result.status == AIExecutionStatus.NEEDS_INPUT
    assert result.transfer_id is None
    assert result.missing_fields == ["source_account_name"]
    assert result.follow_up_question == "Odemeyi hangi hesaptan yaptin?"


def test_execute_message_creates_event_with_default_reminders(db_session):
    service = make_execution_service(
        {
            "yarin saat 11 toplanti": """
            {"action":"event","confidence":0.95,"missing_fields":[],"assistant_message":"Toplantiyi etkinlik olarak algiladim.","transaction":null,"event":{"title":"Toplanti","description":null,"starts_at":"2026-03-10T11:00:00+00:00","ends_at":null},"summary":null}
            """,
        }
    )

    result = service.execute_message(
        db_session,
        AIParseRequest(message="yarin saat 11 toplanti", device_id="device-a"),
    )

    assert result.status == AIExecutionStatus.COMPLETED
    created = db_session.get(Event, result.event_id)
    assert created is not None
    assert created.title == "Toplanti"
    assert created.device_id == "device-a"
    assert len(created.reminders) == 3


def test_execute_message_creates_all_day_event_without_default_reminders(db_session):
    service = make_execution_service(
        {
            "sali gunu aile bulusmasi ekle": """
            {"action":"event","confidence":0.91,"missing_fields":[],"assistant_message":"Bunu tum gun etkinlik olarak algiladim.","transaction":null,"event":{"title":"Aile Bulusmasi","description":"Saat belirtilmedi","starts_at":"2026-03-10T00:00:00+00:00","ends_at":null,"is_all_day":true,"is_recurring":false,"recurrence_days":[]},"summary":null}
            """,
        }
    )

    result = service.execute_message(
        db_session,
        AIParseRequest(message="sali gunu aile bulusmasi ekle", device_id="device-b"),
    )

    assert result.status == AIExecutionStatus.COMPLETED
    created = db_session.get(Event, result.event_id)
    assert created is not None
    assert created.title == "Aile Bulusmasi"
    assert created.is_all_day is True
    assert created.device_id == "device-b"
    assert created.starts_at.isoformat() == "2026-03-10T12:00:00"
    assert len(created.reminders) == 0


def test_execute_message_creates_recurring_rule_for_weekly_routine(db_session):
    service = make_execution_service(
        {
            "sali carsamba cuma spor rutini ekle": """
            {"action":"event","confidence":0.94,"missing_fields":[],"assistant_message":"Haftalik spor rutinini kaydettim.","transaction":null,"event":{"title":"Spor","description":"Haftalik rutin","starts_at":"2026-03-10T00:00:00+00:00","ends_at":null,"is_all_day":true,"is_recurring":true,"recurrence_days":[1,2,4]},"summary":null}
            """,
        }
    )

    result = service.execute_message(
        db_session,
        AIParseRequest(message="sali carsamba cuma spor rutini ekle", device_id="device-c"),
    )

    assert result.status == AIExecutionStatus.COMPLETED
    assert result.recurring_event_id is not None
    created = db_session.get(RecurringEvent, result.recurring_event_id)
    assert created is not None
    assert created.title == "Spor"
    assert created.weekdays == "1,2,4"
    assert created.is_all_day is True
    assert created.device_id == "device-c"


def test_execute_message_preserves_needs_input_for_incomplete_event(db_session):
    service = make_execution_service(
        {
            "yarin bir sey var": """
            {"action":"event","confidence":0.55,"missing_fields":[],"assistant_message":"Etkinlik olabilir ama baslik ve saat eksik.","transaction":null,"event":{"title":null,"description":null,"starts_at":null,"ends_at":null},"summary":null}
            """,
        }
    )

    result = service.execute_message(db_session, AIParseRequest(message="yarin bir sey var"))

    assert result.status == AIExecutionStatus.NEEDS_INPUT
    assert result.event_id is None
    assert result.missing_fields == ["title", "starts_at"]
    assert result.follow_up_question == "Etkinligin adi ne ve hangi gun veya tarihte olsun? Saat zorunlu degil."


def test_execute_message_marks_summary_as_unsupported(db_session):
    service = make_execution_service(
        {
            "bu ay ekstreyi goster": """
            {"action":"summary","confidence":0.93,"missing_fields":[],"assistant_message":"Bu aya ait ekstre istegi olarak algiladim.","transaction":null,"event":null,"summary":{"range":"month","metric":"statement","account_name":null}}
            """,
        }
    )

    result = service.execute_message(db_session, AIParseRequest(message="bu ay ekstreyi goster"))

    assert result.status == AIExecutionStatus.UNSUPPORTED
    assert result.transaction_id is None
    assert result.event_id is None
    assert result.follow_up_question is None


def test_clarification_flow_completes_transaction_after_missing_account_answer(db_session):
    db_session.add_all(
        [
            Account(name="Enpara", type=AccountType.BANK, currency="TRY", balance=Decimal("5000.00")),
            Account(name="Akbank", type=AccountType.CREDIT_CARD, currency="TRY", balance=Decimal("8000.00"), credit_limit=Decimal("20000.00")),
        ]
    )
    db_session.commit()

    service = make_execution_service(
        {
            "120 kahve": """
            {"action":"expense","confidence":0.94,"missing_fields":[],"assistant_message":"Kahve harcamasi olarak algiladim.","transaction":{"amount":120,"account_name":null,"category_name":"Kahve","description":"Kahve harcamasi","occurred_at":"2026-03-09T12:00:00+00:00"},"event":null,"summary":null}
            """,
            "Ilk mesaj: 120 kahve\nEk bilgi: enpara karti": """
            {"action":"expense","confidence":0.96,"missing_fields":[],"assistant_message":"Kahve harcamasini Enpara kartina kaydettim.","transaction":{"amount":120,"account_name":"Enpara","category_name":"Kahve","description":"Kahve harcamasi","occurred_at":"2026-03-09T12:00:00+00:00"},"event":null,"summary":null}
            """,
        }
    )

    first = service.execute_message(db_session, AIParseRequest(message="120 kahve"))
    assert first.status == AIExecutionStatus.NEEDS_INPUT

    second = service.continue_with_clarification(
        db_session,
        AIClarificationRequest(
            original_message="120 kahve",
            clarification="enpara karti",
        ),
    )

    assert second.status == AIExecutionStatus.COMPLETED
    saved = db_session.get(Transaction, second.transaction_id)
    assert saved is not None
    assert db_session.get(Account, saved.account_id).name == "Enpara"


def test_ai_execute_route_is_registered_on_app():
    paths = {route.path for route in app.routes}

    assert "/api/v1/ai/execute" in paths
    assert "/api/v1/ai/clarify" in paths
