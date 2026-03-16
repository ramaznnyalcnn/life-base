from datetime import datetime, timezone
from decimal import Decimal

from app.api.routes.wallet import get_wallet_summary
from app.main import app
from app.models import Account, AccountType
from app.schemas import TransactionCreate, TransferCreate
from app.services.finance import create_transaction
from app.services.transfers import create_transfer
from app.services.wallet import build_wallet_summary


def seed_wallet_state(db_session):
    accounts = [
        Account(
            name="Nakit",
            type=AccountType.CASH,
            currency="TRY",
            balance=Decimal("1500.00"),
        ),
        Account(
            name="Enpara",
            type=AccountType.BANK,
            currency="TRY",
            balance=Decimal("24000.00"),
        ),
        Account(
            name="Akbank Platinum",
            type=AccountType.CREDIT_CARD,
            currency="TRY",
            balance=Decimal("18000.00"),
            credit_limit=Decimal("40000.00"),
            statement_day=25,
            due_day=5,
            issuer="Akbank",
        ),
    ]
    db_session.add_all(accounts)
    db_session.commit()
    for account in accounts:
        db_session.refresh(account)

    create_transaction(
        db_session,
        TransactionCreate(
            account_id=accounts[1].id,
            category_name="Freelance",
            type="income",
            amount="2000.00",
            description="Subat geliri",
            occurred_at=datetime(2026, 2, 15, 9, 0, tzinfo=timezone.utc),
        ),
    )
    create_transaction(
        db_session,
        TransactionCreate(
            account_id=accounts[0].id,
            category_name="Yemek",
            type="expense",
            amount="700.00",
            description="Subat gideri",
            occurred_at=datetime(2026, 2, 16, 12, 0, tzinfo=timezone.utc),
        ),
    )
    create_transaction(
        db_session,
        TransactionCreate(
            account_id=accounts[1].id,
            category_name="Maas",
            type="income",
            amount="9000.00",
            description="Gecen yil geliri",
            occurred_at=datetime(2025, 7, 1, 9, 0, tzinfo=timezone.utc),
        ),
    )
    create_transaction(
        db_session,
        TransactionCreate(
            account_id=accounts[0].id,
            category_name="Fatura",
            type="expense",
            amount="4000.00",
            description="Gecen yil gideri",
            occurred_at=datetime(2025, 7, 2, 12, 0, tzinfo=timezone.utc),
        ),
    )
    create_transaction(
        db_session,
        TransactionCreate(
            account_id=accounts[1].id,
            category_name="Maas",
            type="income",
            amount="5000.00",
            description="Mart maasi",
            occurred_at=datetime(2026, 3, 9, 9, 0, tzinfo=timezone.utc),
        ),
    )
    create_transaction(
        db_session,
        TransactionCreate(
            account_id=accounts[2].id,
            category_name="Market",
            type="expense",
            amount="2000.00",
            description="Haftalik market",
            occurred_at=datetime(2026, 3, 9, 10, 0, tzinfo=timezone.utc),
        ),
    )

    return accounts


def test_build_wallet_summary_returns_mobile_dashboard_metrics(db_session):
    accounts = seed_wallet_state(db_session)

    summary = build_wallet_summary(
        db_session,
        now=datetime(2026, 3, 9, 12, 0, tzinfo=timezone.utc),
    )

    assert summary.liquid_balance == Decimal("36800.00")
    assert summary.total_credit_limit == Decimal("40000.00")
    assert summary.total_card_available == Decimal("16000.00")
    assert summary.total_card_used == Decimal("24000.00")
    assert summary.net_worth == Decimal("12800.00")
    assert summary.previous_month_net == Decimal("1300.00")
    assert summary.previous_year_net == Decimal("5000.00")
    assert summary.active_account_count == 3
    assert summary.active_card_count == 1
    assert summary.weekly_flow.total_income == Decimal("5000.00")
    assert summary.weekly_flow.total_expense == Decimal("2000.00")
    assert summary.monthly_flow.transaction_count == 2

    card = next(item for item in summary.accounts if item.id == accounts[2].id)
    assert card.used_credit == Decimal("24000.00")
    assert card.available_credit == Decimal("16000.00")
    assert card.utilization_ratio == Decimal("0.6000")


def test_wallet_summary_endpoint_returns_dashboard_payload(db_session):
    seed_wallet_state(db_session)

    payload = get_wallet_summary(db_session)

    assert payload.liquid_balance == Decimal("36800.00")
    assert payload.total_card_used == Decimal("24000.00")
    assert isinstance(payload.previous_month_net, Decimal)
    assert isinstance(payload.previous_year_net, Decimal)
    assert payload.previous_month_net >= Decimal("0.00")
    assert payload.previous_year_net >= Decimal("0.00")
    assert len(payload.accounts) == 3


def test_wallet_summary_creates_default_cash_account_on_empty_state(db_session):
    payload = get_wallet_summary(db_session)

    assert payload.liquid_balance == Decimal("0.00")
    assert payload.total_card_used == Decimal("0.00")
    assert payload.weekly_flow.total_income == Decimal("0.00")
    assert payload.monthly_flow.total_expense == Decimal("0.00")
    assert len(payload.accounts) == 1
    assert payload.accounts[0].name == "Nakit"


def test_wallet_summary_counts_card_payment_transfers_separately(db_session):
    accounts = seed_wallet_state(db_session)

    create_transfer(
        db_session,
        TransferCreate(
            source_account_id=accounts[1].id,
            destination_account_id=accounts[2].id,
            amount="490.00",
            description="Kart odemesi",
            occurred_at=datetime(2026, 3, 9, 14, 0, tzinfo=timezone.utc),
        ),
    )

    summary = build_wallet_summary(
        db_session,
        now=datetime(2026, 3, 9, 15, 0, tzinfo=timezone.utc),
    )

    assert summary.monthly_flow.total_expense == Decimal("2000.00")
    assert summary.monthly_flow.total_payments == Decimal("490.00")
    assert summary.net_worth == Decimal("12800.00")


def test_wallet_route_is_registered_on_app():
    paths = {route.path for route in app.routes}

    assert "/api/v1/wallet/summary" in paths
