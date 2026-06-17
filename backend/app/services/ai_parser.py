"""AI parsing service backed by OpenRouter."""

from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from textwrap import dedent

import httpx

from app.core.config import Settings, get_settings
from app.schemas import AIAction, AIParseRequest, AIParseResponse


class OpenRouterGateway:
    """Small OpenRouter client for structured parsing requests."""

    def __init__(self, settings: Settings, client: httpx.Client | None = None):
        self.settings = settings
        self.client = client or httpx.Client(timeout=30.0)

    def complete(self, model: str, system_prompt: str, user_message: str, response_schema: dict) -> str:
        """Send a chat completion request and return raw content."""

        if not self.settings.openrouter_api_key:
            raise RuntimeError("OpenRouter API anahtari tanimli degil.")

        response = self.client.post(
            f"{self.settings.openrouter_base_url}/chat/completions",
            headers={
                "Authorization": f"Bearer {self.settings.openrouter_api_key}",
                "Content-Type": "application/json",
                "HTTP-Referer": self.settings.web_app_url,
                "X-Title": self.settings.app_name,
            },
            json={
                "model": model,
                "temperature": 0,
                "plugins": [{"id": "response-healing"}],
                "provider": {
                    "require_parameters": True,
                },
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_message},
                ],
                "response_format": {"type": "json_object"},
            },
        )
        response.raise_for_status()
        payload = response.json()
        message = payload["choices"][0]["message"]
        content = message.get("content")
        if content:
            return content
        reasoning = message.get("reasoning")
        if reasoning and "{" in reasoning and "}" in reasoning:
            return reasoning[reasoning.find("{"): reasoning.rfind("}") + 1]
        raise ValueError(f"Model bos veya parse edilemez icerik dondu: {model}")


class AIParserService:
    """Build prompts, call the model, and normalize the response."""

    def __init__(
        self,
        gateway: OpenRouterGateway,
        now_provider=lambda: datetime.now(timezone.utc),
    ):
        self.gateway = gateway
        self.now_provider = now_provider

    @staticmethod
    def heuristic_preclassify(message: str) -> AIAction | None:
        """Cheap pre-classification before asking the model."""

        text = message.lower().strip()
        if not text:
            return AIAction.UNKNOWN

        payment_terms = [
            "kart borcu",
            "karta odeme",
            "odeme yaptim",
            "borcuna",
            "ekstre odedim",
            "kart odemesi",
        ]
        event_terms = [
            "yarin",
            "bugun saat",
            "cuma",
            "pazartesi",
            "sali",
            "carsamba",
            "persembe",
            "cumartesi",
            "pazar",
            "toplanti",
            "randevu",
            "etkinlik",
            "hatirlat",
            "rutin",
            "aliskanlik",
            "duzenli",
        ]
        summary_terms = [
            "ekstreyi goster",
            "bu ay ne kadar",
            "bu hafta ne kadar",
            "nakit akisi",
            "ozet",
            "durum",
            "harcama ozeti",
        ]
        income_terms = ["maas", "gelir", "para geldi", "yatti", "odendi bana"]

        if any(term in text for term in summary_terms):
            return AIAction.SUMMARY
        if any(term in text for term in payment_terms):
            return AIAction.PAYMENT
        if any(term in text for term in event_terms) and (
            ":" in text or "saat" in text or "yarin" in text or "cuma" in text
        ):
            return AIAction.EVENT
        if any(term in text for term in income_terms):
            return AIAction.INCOME
        if re.search(r"(\d+[.,]?\d*)\s*(tl|₺)", text) or re.search(r"\b\d{2,6}\b", text):
            return AIAction.EXPENSE
        return None

    @staticmethod
    def _classification_schema() -> dict:
        return {
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["expense", "income", "payment", "event", "summary", "unknown"],
                },
                "confidence": {"type": "number"},
            },
            "required": ["action", "confidence"],
            "additionalProperties": False,
        }

    def build_preclassification_prompt(self, now: datetime) -> str:
        """Return a cheap stage-1 classifier prompt."""

        return dedent(
            f"""
            STAGE: PRECLASSIFY
            Bugunun tarihi: {now.date().isoformat()}
            Simdiki zaman: {now.isoformat()}

            Kullanici mesajini yalnizca su aksiyonlardan birine ata:
            expense, income, payment, event, summary, unknown

            Kurallar:
            - Sadece JSON dondur.
            - "kart borcu", "odeme yaptim", "borcuna attim" => payment
            - tarih/saat/randevu/toplanti => event
            - maas/gelir => income
            - ekstre/ozet/ne kadar harcadim => summary
            - para cikisi ama odeme degilse => expense

            Cikti:
            {{
              "action": "expense|income|payment|event|summary|unknown",
              "confidence": 0.0
            }}
            """
        ).strip()

    def build_parser_prompt(self, action: AIAction, now: datetime) -> str:
        """Return a specialized parser prompt for a single action family."""

        family_rules = {
            AIAction.EXPENSE: """
            STAGE: PARSE_EXPENSE
            Sadece harcama mesaji parse et.
            Odak: amount, account_name, category_name, description, occurred_at.
            Kartla yapilan restoran/market/yemek vb islemler de expense'tir.
            """,
            AIAction.INCOME: """
            STAGE: PARSE_INCOME
            Sadece gelir mesaji parse et.
            Odak: amount, account_name, category_name, description, occurred_at.
            Maas, iade, serbest gelir gibi gelirleri ayir.
            """,
            AIAction.PAYMENT: """
            STAGE: PARSE_PAYMENT
            Sadece kart veya hesap odemesi parse et.
            "kart borcu", "karta odeme", "borcuna para attim" payment'tir.
            Bu niyet gercekte transfer olarak islenecegi icin
            source_account_name gonderen hesabi,
            destination_account_name ise odeme yapilan kart veya hesabi temsil eder.
            Eski uyumluluk icin destination bilinip baska alan yoksa account_name alanini da doldurabilirsin.
            Odak: amount, source_account_name, destination_account_name, description, occurred_at.
            """,
            AIAction.EVENT: """
            STAGE: PARSE_EVENT
            Sadece etkinlik ve hatirlatma niyetini parse et.
            Odak: title, description, starts_at, ends_at, is_all_day, is_recurring, recurrence_days.
            Saat net degilse ama gun/tarih veya rutin bilgisi varsa etkinligi yine parse et.
            Bu durumda is_all_day=true yap, ends_at=null don ve starts_at alanini ilk uygun gunun
            tarihine ayarla. Saat gerekmiyorsa 00:00 yerine gunu temsil eden bir tum-gun kaydi olarak dusun.
            Haftalik rutinlerde is_recurring=true yap ve recurrence_days alanina gunleri
            0=Pazartesi, 1=Sali, 2=Carsamba, 3=Persembe, 4=Cuma, 5=Cumartesi, 6=Pazar seklinde yaz.
            Reminder niyeti varsa bunu event olarak yorumla.
            """,
            AIAction.SUMMARY: """
            STAGE: PARSE_SUMMARY
            Sadece ozet/ekstre/bakiye sorularini parse et.
            """,
            AIAction.UNKNOWN: """
            STAGE: PARSE_UNKNOWN
            Mesaj net degilse unknown don.
            """,
        }
        return dedent(
            f"""
            {family_rules[action].strip()}
            Bugunun tarihi: {now.date().isoformat()}
            Simdiki zaman: {now.isoformat()}

            Ortak kurallar:
            - Her zaman Turkce cevap ver.
            - Sadece gecerli JSON dondur.
            - Uydurma bilgi yazma.
            - Eksik bilgi varsa missing_fields listesine ekle.
            - Hesap veya kart adi geciyorsa oldugu gibi koru.
            - Harcama, gelir ve payment icin amount yoksa missing_fields icine mutlaka "amount" ekle.
            - Event icin baslik yoksa "title", gun veya tarih hic yoksa "starts_at" missing_fields icine eklenmeli.
            - Tekrarlayan rutinlerde gunler belirsizse "recurrence_days" missing_fields icine eklenmeli.
            - Event icin ends_at zorunlu degil, eksik diye isteme.
            - confidence alani 0 ile 1 arasinda olmali.

            JSON semasi:
            {{
              "action": "expense|income|payment|event|summary|unknown",
              "confidence": 0.0,
              "missing_fields": [],
              "assistant_message": "Kisa Turkce cevap",
              "transaction": {{
                "amount": 0,
                "account_name": "string veya null",
                "source_account_name": "string veya null",
                "destination_account_name": "string veya null",
                "category_name": "string veya null",
                "description": "string veya null",
                "occurred_at": "ISO datetime veya null"
              }},
              "event": {{
                "title": "string veya null",
                "description": "string veya null",
                "starts_at": "ISO datetime veya null",
                "ends_at": "ISO datetime veya null",
                "is_all_day": true,
                "is_recurring": true,
                "recurrence_days": [0, 2, 4]
              }},
              "summary": {{
                "range": "today|week|month|all",
                "metric": "expense|cashflow|balance|statement",
                "account_name": "string veya null"
              }}
            }}
            """
        ).strip()

    def classify_action(self, message: str, now: datetime) -> AIAction:
        """Choose the parser family using heuristics first, then a cheap model call."""

        heuristic = self.heuristic_preclassify(message)
        if heuristic is not None:
            return heuristic

        prompt = self.build_preclassification_prompt(now)
        schema = self._classification_schema()
        models = self.gateway.settings.openrouter_models or [self.gateway.settings.openrouter_model]
        errors: list[str] = []

        for model in models:
            try:
                raw = self.gateway.complete(model, prompt, message, schema)
                payload = self.extract_json(raw)
                return AIAction(payload["action"])
            except (httpx.RequestError, httpx.HTTPStatusError, ValueError, KeyError) as exc:
                errors.append(f"{model}: {exc}")
                continue

        raise RuntimeError("On siniflandirma basarisiz oldu. " + " | ".join(errors))

    @staticmethod
    def extract_json(raw_text: str) -> dict:
        """Extract and decode JSON from raw model text."""

        cleaned = raw_text.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.replace("```json", "").replace("```", "").strip()
        return json.loads(cleaned)

    @staticmethod
    def _ensure_missing_field(response: AIParseResponse, field_name: str) -> None:
        if field_name not in response.missing_fields:
            response.missing_fields.append(field_name)

    def normalize_response(self, response: AIParseResponse) -> AIParseResponse:
        """Enforce a stable contract on top of model output."""

        if response.action in {AIAction.EXPENSE, AIAction.INCOME, AIAction.PAYMENT}:
            if response.transaction is None:
                raise ValueError("Transaction payload eksik.")
            if response.transaction.amount is None:
                self._ensure_missing_field(response, "amount")
            if not response.transaction.description:
                self._ensure_missing_field(response, "description")

        if response.action == AIAction.EVENT:
            if response.event is None:
                raise ValueError("Event payload eksik.")
            if not response.event.title:
                self._ensure_missing_field(response, "title")
            if response.event.starts_at is None:
                self._ensure_missing_field(response, "starts_at")
            if response.event.is_recurring and not response.event.recurrence_days:
                self._ensure_missing_field(response, "recurrence_days")
            response.missing_fields = [field for field in response.missing_fields if field != "ends_at"]

        if response.action == AIAction.SUMMARY and response.summary is None:
            raise ValueError("Summary payload eksik.")

        if response.action == AIAction.UNKNOWN:
            response.transaction = None
            response.event = None
            response.summary = None

        response.missing_fields = list(dict.fromkeys(response.missing_fields))
        return response

    def parse(self, request: AIParseRequest) -> AIParseResponse:
        """Parse user text into structured domain intent."""

        now = request.current_time or self.now_provider()
        action = self.classify_action(request.message, now)
        system_prompt = self.build_parser_prompt(action, now)
        response_schema = AIParseResponse.model_json_schema()
        models = self.gateway.settings.openrouter_models or [self.gateway.settings.openrouter_model]
        errors: list[str] = []
        validation_errors: list[str] = []

        for model in models:
            try:
                raw_content = self.gateway.complete(model, system_prompt, request.message, response_schema)
                payload = self.extract_json(raw_content)
                parsed = AIParseResponse.model_validate(payload)
                return self.normalize_response(parsed)
            except (httpx.RequestError, httpx.HTTPStatusError) as exc:
                errors.append(f"{model}: {exc}")
                continue
            except ValueError as exc:
                validation_errors.append(f"{model}: {exc}")
                continue

        if validation_errors:
            raise ValueError(" | ".join(validation_errors))
        raise RuntimeError("OpenRouter parse cagrisi basarisiz oldu. " + " | ".join(errors))


def get_ai_parser_service() -> AIParserService:
    """Default dependency factory for the API layer."""

    settings = get_settings()
    return AIParserService(OpenRouterGateway(settings))
