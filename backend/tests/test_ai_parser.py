import json
from pathlib import Path
from datetime import datetime, timezone

import httpx
import pytest
from fastapi import HTTPException

from app.api.routes.ai import parse_message
from app.main import app
from app.schemas import AIAction, AIParseRequest, SummaryMetric, SummaryRange
from app.services.ai_parser import AIParserService


REPO_ROOT = Path(__file__).resolve().parents[2]


class FakeGateway:
    def __init__(self, responses: dict[tuple[str, str], str], models: list[str] | None = None):
        self.responses = responses
        self.calls: list[tuple[str, str, dict]] = []
        self.prompts: list[str] = []
        self.settings = type(
            "Settings",
            (),
            {
                "openrouter_models": models or ["stepfun/step-3.5-flash:free"],
                "openrouter_model": (models or ["stepfun/step-3.5-flash:free"])[0],
            },
        )()

    def complete(self, model: str, system_prompt: str, user_message: str, response_schema: dict) -> str:
        self.calls.append((model, user_message, response_schema))
        self.prompts.append(system_prompt)
        if (model, user_message) not in self.responses:
            raise httpx.ConnectError("simulated fallback")
        response = self.responses[(model, user_message)]
        if isinstance(response, list):
            return response.pop(0)
        return response


def test_preclassifier_and_parser_prompts_contain_core_business_rules():
    gateway = FakeGateway({})
    service = AIParserService(gateway, now_provider=lambda: datetime(2026, 3, 9, 12, 0, tzinfo=timezone.utc))

    classifier_prompt = service.build_preclassification_prompt(
        datetime(2026, 3, 9, 12, 0, tzinfo=timezone.utc)
    )
    parser_prompt = service.build_parser_prompt(
        AIAction.PAYMENT,
        datetime(2026, 3, 9, 12, 0, tzinfo=timezone.utc),
    )

    assert "STAGE: PRECLASSIFY" in classifier_prompt
    assert "kart borcu" in classifier_prompt
    assert "STAGE: PARSE_PAYMENT" in parser_prompt
    assert '"action": "expense|income|payment|event|summary|unknown"' in parser_prompt
    assert 'missing_fields icine mutlaka "amount" ekle' in parser_prompt


@pytest.mark.parametrize(
    ("message", "expected_action"),
    [
        ("kart borcuna 3000 attim", AIAction.PAYMENT),
        ("yarin 14:30 disci", AIAction.EVENT),
        ("bu ay ekstreyi goster", AIAction.SUMMARY),
        ("maas geldi 65000", AIAction.INCOME),
        ("350 tl migros", AIAction.EXPENSE),
    ],
)
def test_heuristic_preclassifier_catches_high_signal_messages(message, expected_action):
    assert AIParserService.heuristic_preclassify(message) == expected_action


def test_extract_json_supports_markdown_wrapped_payload():
    payload = AIParserService.extract_json(
        """```json
        {"action":"unknown","confidence":0.4,"missing_fields":[],"assistant_message":"Belirsiz.","transaction":null,"event":null,"summary":null}
        ```"""
    )

    assert payload["action"] == "unknown"


def test_parse_message_route_returns_structured_expense_result():
    gateway = FakeGateway(
        {
            ("stepfun/step-3.5-flash:free", "bugun 450 tl market harcadim"): """
            {
              "action": "expense",
              "confidence": 0.98,
              "missing_fields": [],
              "assistant_message": "450 TL market harcamasi olarak algiladim.",
              "transaction": {
                "amount": 450,
                "account_name": null,
                "category_name": "Market",
                "description": "Market harcamasi",
                "occurred_at": "2026-03-09T12:00:00+00:00"
              },
              "event": null,
              "summary": null
            }
            """,
        }
    )
    service = AIParserService(gateway, now_provider=lambda: datetime(2026, 3, 9, 12, 0, tzinfo=timezone.utc))

    result = parse_message(AIParseRequest(message="bugun 450 tl market harcadim"), service)

    assert result.action == AIAction.EXPENSE
    assert result.transaction is not None
    assert str(result.transaction.amount) == "450"
    assert result.transaction.category_name == "Market"
    assert gateway.calls[0][1] == "bugun 450 tl market harcadim"
    assert gateway.calls[0][0] == "stepfun/step-3.5-flash:free"
    assert gateway.calls[0][2]["type"] == "object"


def test_parse_message_route_supports_multiple_turkish_prompt_shapes():
    now = datetime(2026, 3, 9, 12, 0, tzinfo=timezone.utc)
    gateway = FakeGateway(
        {
            ("stepfun/step-3.5-flash:free", "maas yatti 65000"): """
            {"action":"income","confidence":0.97,"missing_fields":[],"assistant_message":"Maas geliri olarak algiladim.","transaction":{"amount":65000,"account_name":null,"category_name":"Maas","description":"Maas geliri","occurred_at":"2026-03-09T12:00:00+00:00"},"event":null,"summary":null}
            """,
            ("stepfun/step-3.5-flash:free", "vakif karta 5000 odeme yaptim"): """
            {"action":"payment","confidence":0.95,"missing_fields":[],"assistant_message":"Kart odemesi olarak algiladim.","transaction":{"amount":5000,"account_name":"Vakif Kart","category_name":null,"description":"Kredi karti odemesi","occurred_at":"2026-03-09T12:00:00+00:00"},"event":null,"summary":null}
            """,
            ("stepfun/step-3.5-flash:free", "yarin 14:30 disci randevum var"): """
            {"action":"event","confidence":0.94,"missing_fields":[],"assistant_message":"Etkinlik olarak algiladim.","transaction":null,"event":{"title":"Disci Randevusu","description":null,"starts_at":"2026-03-10T14:30:00+00:00","ends_at":null},"summary":null}
            """,
            ("stepfun/step-3.5-flash:free", "bu hafta ne kadar harcadim"): """
            {"action":"summary","confidence":0.96,"missing_fields":[],"assistant_message":"Haftalik harcama ozeti istegi olarak algiladim.","transaction":null,"event":null,"summary":{"range":"week","metric":"expense","account_name":null}}
            """,
            ("stepfun/step-3.5-flash:free", "bu ay ekstreyi goster"): """
            {"action":"summary","confidence":0.96,"missing_fields":[],"assistant_message":"Aylik ekstre istegi olarak algiladim.","transaction":null,"event":null,"summary":{"range":"month","metric":"statement","account_name":null}}
            """,
            ("stepfun/step-3.5-flash:free", "bir seyler oldu ama tam anlatamadim"): """
            {"action":"unknown","confidence":0.31,"missing_fields":["action"],"assistant_message":"Mesaji netlestirmen gerekiyor.","transaction":null,"event":null,"summary":null}
            """,
        }
    )
    service = AIParserService(gateway, now_provider=lambda: now)

    income = service.parse(AIParseRequest(message="maas yatti 65000"))
    payment = service.parse(AIParseRequest(message="vakif karta 5000 odeme yaptim"))
    event = service.parse(AIParseRequest(message="yarin 14:30 disci randevum var"))
    weekly = service.parse(AIParseRequest(message="bu hafta ne kadar harcadim"))
    statement = service.parse(AIParseRequest(message="bu ay ekstreyi goster"))
    unknown = service.parse(AIParseRequest(message="bir seyler oldu ama tam anlatamadim"))

    assert income.action == AIAction.INCOME
    assert payment.action == AIAction.PAYMENT
    assert event.action == AIAction.EVENT
    assert weekly.summary is not None and weekly.summary.range == SummaryRange.WEEK
    assert weekly.summary.metric == SummaryMetric.EXPENSE
    assert statement.summary is not None and statement.summary.metric == SummaryMetric.STATEMENT
    assert unknown.action == AIAction.UNKNOWN
    assert unknown.missing_fields == ["action"]


@pytest.mark.parametrize(
    ("message", "model_payload", "expected_action", "expected_field", "expected_value"),
    [
        (
            "350 tl migros",
            """{"action":"expense","confidence":0.97,"missing_fields":[],"assistant_message":"Harcama olarak algiladim.","transaction":{"amount":350,"account_name":null,"category_name":"Market","description":"Migros harcamasi","occurred_at":"2026-03-09T12:00:00+00:00"},"event":null,"summary":null}""",
            AIAction.EXPENSE,
            "category_name",
            "Market",
        ),
        (
            "120 kahve",
            """{"action":"expense","confidence":0.95,"missing_fields":[],"assistant_message":"Kahve harcamasi olarak algiladim.","transaction":{"amount":120,"account_name":null,"category_name":"Kahve","description":"Kahve harcamasi","occurred_at":"2026-03-09T12:00:00+00:00"},"event":null,"summary":null}""",
            AIAction.EXPENSE,
            "amount",
            "120",
        ),
        (
            "is bankasi kartimla 2400 yemek odedim",
            """{"action":"expense","confidence":0.94,"missing_fields":[],"assistant_message":"Kart harcamasi olarak algiladim.","transaction":{"amount":2400,"account_name":"Is Bankasi Karti","category_name":"Yemek","description":"Yemek harcamasi","occurred_at":"2026-03-09T12:00:00+00:00"},"event":null,"summary":null}""",
            AIAction.EXPENSE,
            "account_name",
            "Is Bankasi Karti",
        ),
        (
            "kart borcuna 3000 attim",
            """{"action":"payment","confidence":0.96,"missing_fields":[],"assistant_message":"Kart odemesi olarak algiladim.","transaction":{"amount":3000,"account_name":null,"category_name":null,"description":"Kredi karti odemesi","occurred_at":"2026-03-09T12:00:00+00:00"},"event":null,"summary":null}""",
            AIAction.PAYMENT,
            "description",
            "Kredi karti odemesi",
        ),
        (
            "enparaya 5000 odeme yaptim",
            """{"action":"payment","confidence":0.95,"missing_fields":[],"assistant_message":"Kart odemesi olarak algiladim.","transaction":{"amount":5000,"account_name":"Enpara","category_name":null,"description":"Kredi karti odemesi","occurred_at":"2026-03-09T12:00:00+00:00"},"event":null,"summary":null}""",
            AIAction.PAYMENT,
            "account_name",
            "Enpara",
        ),
        (
            "yarin saat 11 toplanti",
            """{"action":"event","confidence":0.95,"missing_fields":[],"assistant_message":"Etkinlik olarak algiladim.","transaction":null,"event":{"title":"Toplanti","description":null,"starts_at":"2026-03-10T11:00:00+00:00","ends_at":null},"summary":null}""",
            AIAction.EVENT,
            "title",
            "Toplanti",
        ),
        (
            "cuma 14:00 disci",
            """{"action":"event","confidence":0.92,"missing_fields":[],"assistant_message":"Etkinlik olarak algiladim.","transaction":null,"event":{"title":"Disci","description":null,"starts_at":"2026-03-13T14:00:00+00:00","ends_at":null},"summary":null}""",
            AIAction.EVENT,
            "starts_at",
            "2026-03-13T14:00:00+00:00",
        ),
    ],
)
def test_parser_handles_high_value_daily_scenarios(message, model_payload, expected_action, expected_field, expected_value):
    gateway = FakeGateway(
        {
            ("stepfun/step-3.5-flash:free", message): model_payload,
        }
    )
    service = AIParserService(gateway, now_provider=lambda: datetime(2026, 3, 9, 12, 0, tzinfo=timezone.utc))

    result = service.parse(AIParseRequest(message=message))

    assert result.action == expected_action
    if result.transaction is not None:
        actual_value = getattr(result.transaction, expected_field)
    else:
        actual_value = getattr(result.event, expected_field)
    if hasattr(actual_value, "isoformat"):
        assert actual_value.isoformat() == expected_value
    else:
        assert str(actual_value) == expected_value


@pytest.mark.parametrize(
    ("message", "model_payload", "expected_action", "expected_missing"),
    [
        (
            "maas geldi",
            """{"action":"income","confidence":0.74,"missing_fields":[],"assistant_message":"Gelir olarak algiladim ama tutar eksik.","transaction":{"amount":null,"account_name":null,"category_name":"Maas","description":"Maas geliri","occurred_at":"2026-03-09T12:00:00+00:00"},"event":null,"summary":null}""",
            AIAction.INCOME,
            ["amount"],
        ),
        (
            "markete gittim",
            """{"action":"expense","confidence":0.68,"missing_fields":[],"assistant_message":"Harcama gibi gorunuyor ama tutar eksik.","transaction":{"amount":null,"account_name":null,"category_name":"Market","description":"Market harcamasi","occurred_at":"2026-03-09T12:00:00+00:00"},"event":null,"summary":null}""",
            AIAction.EXPENSE,
            ["amount"],
        ),
        (
            "yarin toplanti var",
            """{"action":"event","confidence":0.71,"missing_fields":[],"assistant_message":"Etkinlik gibi gorunuyor ama saat eksik.","transaction":null,"event":{"title":"Toplanti","description":null,"starts_at":null,"ends_at":null},"summary":null}""",
            AIAction.EVENT,
            ["starts_at"],
        ),
        (
            "yarin bir sey var",
            """{"action":"event","confidence":0.55,"missing_fields":[],"assistant_message":"Etkinlik olabilir ama baslik ve saat eksik.","transaction":null,"event":{"title":null,"description":null,"starts_at":null,"ends_at":null},"summary":null}""",
            AIAction.EVENT,
            ["title", "starts_at"],
        ),
    ],
)
def test_parser_marks_missing_fields_for_incomplete_operational_messages(
    message,
    model_payload,
    expected_action,
    expected_missing,
):
    gateway = FakeGateway({("stepfun/step-3.5-flash:free", message): model_payload})
    service = AIParserService(gateway, now_provider=lambda: datetime(2026, 3, 9, 12, 0, tzinfo=timezone.utc))

    result = service.parse(AIParseRequest(message=message))

    assert result.action == expected_action
    assert result.missing_fields == expected_missing


def test_parser_rejects_transaction_action_without_transaction_payload():
    gateway = FakeGateway(
        {
            ("stepfun/step-3.5-flash:free", "bozuk harcama"): """
            {"action":"expense","confidence":0.88,"missing_fields":[],"assistant_message":"Harcama olarak algiladim.","transaction":null,"event":null,"summary":null}
            """,
        }
    )
    service = AIParserService(gateway)

    with pytest.raises(ValueError):
        service.parse(AIParseRequest(message="bozuk harcama"))


def test_parser_rejects_event_action_without_event_payload():
    gateway = FakeGateway(
        {
            ("stepfun/step-3.5-flash:free", "bozuk etkinlik"): """
            {"action":"event","confidence":0.82,"missing_fields":[],"assistant_message":"Etkinlik olarak algiladim.","transaction":null,"event":null,"summary":null}
            """,
        }
    )
    service = AIParserService(gateway)

    with pytest.raises(ValueError):
        service.parse(AIParseRequest(message="bozuk etkinlik"))


def test_ai_route_is_registered_on_app():
    paths = {route.path for route in app.routes}

    assert "/api/v1/ai/parse" in paths


def test_parse_message_returns_502_for_invalid_ai_payload():
    gateway = FakeGateway({("stepfun/step-3.5-flash:free", "hatali cevap"): '{"action":"expense"}'})
    service = AIParserService(gateway)

    with pytest.raises(HTTPException) as exc:
        parse_message(AIParseRequest(message="hatali cevap"), service)

    assert exc.value.status_code == 502


def test_parser_tries_multiple_free_models_in_order():
    gateway = FakeGateway(
        {
            ("arcee-ai/trinity-large-preview:free", "nakit akisi ne durumda"): """
            {"action":"summary","confidence":0.94,"missing_fields":[],"assistant_message":"Nakit akisi ozeti olarak algiladim.","transaction":null,"event":null,"summary":{"range":"month","metric":"cashflow","account_name":null}}
            """
        },
        models=[
            "stepfun/step-3.5-flash:free",
            "arcee-ai/trinity-large-preview:free",
            "openrouter/free",
        ],
    )
    service = AIParserService(gateway, now_provider=lambda: datetime(2026, 3, 9, 12, 0, tzinfo=timezone.utc))

    result = service.parse(AIParseRequest(message="nakit akisi ne durumda"))

    assert result.summary is not None
    assert result.summary.metric == SummaryMetric.CASHFLOW
    assert [call[0] for call in gateway.calls] == [
        "stepfun/step-3.5-flash:free",
        "arcee-ai/trinity-large-preview:free",
    ]


def test_classifier_falls_back_to_model_when_heuristic_is_uncertain():
    gateway = FakeGateway(
        {
            ("stepfun/step-3.5-flash:free", "asagidaki isi plana ekle"): """
            {"action":"event","confidence":0.73}
            """,
        }
    )
    service = AIParserService(gateway, now_provider=lambda: datetime(2026, 3, 9, 12, 0, tzinfo=timezone.utc))

    action = service.classify_action("asagidaki isi plana ekle", datetime(2026, 3, 9, 12, 0, tzinfo=timezone.utc))

    assert action == AIAction.EVENT
    assert gateway.calls[0][1] == "asagidaki isi plana ekle"
    assert "STAGE: PRECLASSIFY" in gateway.prompts[0]


def test_golden_dataset_matches_expected_actions_and_missing_fields():
    now = datetime(2026, 3, 9, 12, 0, tzinfo=timezone.utc)
    fixture_path = REPO_ROOT / "backend" / "tests" / "fixtures" / "ai_golden_cases.json"
    cases = json.loads(fixture_path.read_text())

    responses = {}
    for case in cases:
        responses[("stepfun/step-3.5-flash:free", case["message"])] = case["model_payload"]

    gateway = FakeGateway(responses)
    service = AIParserService(gateway, now_provider=lambda: now)

    for case in cases:
        result = service.parse(AIParseRequest(message=case["message"]))
        assert result.action.value == case["expected"]["action"]
        assert result.missing_fields == case["expected"]["missing_fields"]
