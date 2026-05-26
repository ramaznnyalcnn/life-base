from datetime import datetime, timezone
from decimal import Decimal

from app.api.routes.wallet import list_card_statements
from app.main import app
from app.models import Account, AccountType
from app.schemas import TransactionCreate, TransferCreate
from app.services.finance import create_transaction
from app.services.transfers import create_transfer
from app.services.wallet import build_card_statements


def seed_card_statement_state(db_session):
    card = Account(
        name="Akbank Platinum",
        type=AccountType.CREDIT_CARD,
        currency="TRY",
        balance=Decimal("22000.00"),
        credit_limit=Decimal("40000.00"),
        statement_day=20,
        due_day=5,
        issuer="Akbank",
    )
    db_session.add(card)
    db_session.commit()
    db_session.refresh(card)

    create_transaction(
        db_session,
        TransactionCreate(
            account_id=card.id,
            category_name="Market",
            type="expense",
            amount="1800.00",
            description="Mart market",
            occurred_at=datetime(2026, 3, 9, 9, 0, tzinfo=timezone.utc),
        ),
    )
    create_transaction(
        db_session,
        TransactionCreate(
            account_id=card.id,
            category_name="Yemek",
            type="expense",
            amount="700.00",
            description="Aksam yemegi",
            occurred_at=datetime(2026, 3, 10, 19, 0, tzinfo=timezone.utc),
        ),
    )
    create_transaction(
        db_session,
        TransactionCreate(
            account_id=card.id,
            category_name="Kart Odemesi",
            type="payment",
            amount="500.00",
            description="Karti odedim",
            occurred_at=datetime(2026, 3, 11, 10, 0, tzinfo=timezone.utc),
        ),
    )

    return card


def test_build_card_statements_computes_current_cycle_and_auto_reset(db_session):
    card = seed_card_statement_state(db_session)

    statements = build_card_statements(
        db_session,
        now=datetime(2026, 3, 9, 12, 0, tzinfo=timezone.utc),
    )

    assert len(statements) == 1
    statement = statements[0]
    assert statement.account_id == card.id
    assert statement.statement_month.isoformat() == "2026-03-01"
    assert statement.period_start.isoformat() == "2026-02-21"
    assert statement.period_end.isoformat() == "2026-03-20"
    assert statement.due_date.isoformat() == "2026-04-05"
    assert statement.auto_resets_at.isoformat() == "2026-03-21T00:00:00+00:00"
    assert statement.statement_amount == Decimal("2500.00")
    assert statement.payment_activity == Decimal("500.00")
    assert statement.transaction_count == 3


def test_build_card_statements_moves_to_next_bucket_after_cutoff(db_session):
    seed_card_statement_state(db_session)

    statements = build_card_statements(
        db_session,
        now=datetime(2026, 3, 25, 12, 0, tzinfo=timezone.utc),
    )

    assert statements[0].statement_month.isoformat() == "2026-04-01"
    assert statements[0].period_start.isoformat() == "2026-03-21"
    assert statements[0].period_end.isoformat() == "2026-04-20"
    assert statements[0].auto_resets_at.isoformat() == "2026-04-21T00:00:00+00:00"
    assert statements[0].statement_amount == Decimal("0.00")


def test_statements_route_is_registered_and_returns_payload(db_session):
    card = seed_card_statement_state(db_session)

    payload = list_card_statements(db_session)

    assert len(payload) == 1
    assert payload[0].account_id == card.id

    paths = {route.path for route in app.routes}
    assert "/api/v1/wallet/statements" in paths


def test_build_card_statements_includes_transfer_payments(db_session):
    card = seed_card_statement_state(db_session)
    bank = Account(
        name="Enpara",
        type=AccountType.BANK,
        currency="TRY",
        balance=Decimal("9000.00"),
    )
    db_session.add(bank)
    db_session.commit()
    db_session.refresh(bank)

    create_transfer(
        db_session,
        TransferCreate(
            source_account_id=bank.id,
            destination_account_id=card.id,
            amount="490.00",
            description="Kart transfer odemesi",
            occurred_at=datetime(2026, 3, 12, 9, 0, tzinfo=timezone.utc),
        ),
    )

    statements = build_card_statements(
        db_session,
        now=datetime(2026, 3, 14, 12, 0, tzinfo=timezone.utc),
    )

    assert statements[0].payment_activity == Decimal("990.00")
