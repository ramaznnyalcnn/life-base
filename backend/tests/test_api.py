from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import select

from app.api.routes.accounts import create_account, list_accounts, update_account
from app.api.routes.transactions import (
    create_transaction_endpoint,
    delete_transaction_endpoint,
    get_transaction_summary,
    list_transactions,
    update_transaction_endpoint,
)
from app.main import app
from app.models import Account, AccountType, Category, Transaction
from app.schemas import AccountCreate, AccountUpdate, SummaryPeriod, TransactionCreate, TransactionUpdate
from app.services.bootstrap import ensure_default_categories


def test_accounts_api_create_list_and_update(db_session):
    created = create_account(
        AccountCreate(
            name="Akbank Platinum",
            type="credit_card",
            currency="TRY",
            balance="12500.00",
            credit_limit="40000.00",
            statement_day=25,
            due_day=5,
            issuer="Akbank",
            is_active=True,
        ),
        db_session,
    )

    assert created.name == "Akbank Platinum"
    assert created.statement_day == 25

    rows = list_accounts(db_session)
    assert len(rows) == 2
    assert any(row.name == "Nakit" for row in rows)

    updated = update_account(
        created.id,
        AccountUpdate(balance="15000.00", issuer="Akbank Private"),
        db_session,
    )
    assert updated.balance == Decimal("15000.00")
    assert updated.issuer == "Akbank Private"


def test_transactions_api_creates_transaction_updates_balance_and_summary(db_session):
    occurred_at = datetime.now(timezone.utc)
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
    db_session.refresh(account)
    ensure_default_categories(db_session)

    transaction = create_transaction_endpoint(
        TransactionCreate(
            account_id=account.id,
            category_name="Market",
            type="expense",
            amount="750.00",
            description="Haftalik market",
            occurred_at=occurred_at,
        ),
        db_session,
    )

    assert transaction.statement_month is not None

    refreshed_account = db_session.get(Account, account.id)
    assert refreshed_account.balance == Decimal("9250.00")

    tx_rows = list_transactions(db_session)
    assert len(tx_rows) == 1

    summary = get_transaction_summary(SummaryPeriod.MONTH, db_session)
    assert summary.transaction_count == 1
    assert summary.total_expense == Decimal("750.00")
    assert summary.net_flow == Decimal("-750.00")


def test_transactions_api_creates_user_category_when_missing(db_session):
    account = Account(
        name="Nakit",
        type=AccountType.CASH,
        currency="TRY",
        balance=Decimal("2000.00"),
    )
    db_session.add(account)
    db_session.commit()
    db_session.refresh(account)

    transaction = create_transaction_endpoint(
        TransactionCreate(
            account_id=account.id,
            category_name="Kahve",
            type="expense",
            amount="120.00",
            description="Calisma kahvesi",
        ),
        db_session,
    )

    assert transaction.id is not None
    category = db_session.scalar(select(Category).where(Category.name == "Kahve"))
    assert category is not None
    assert category.is_system is False


def test_transactions_api_filters_updates_and_deletes(db_session):
    account = Account(
        name="Enpara",
        type=AccountType.BANK,
        currency="TRY",
        balance=Decimal("5000.00"),
    )
    db_session.add(account)
    db_session.commit()
    db_session.refresh(account)

    first = create_transaction_endpoint(
        TransactionCreate(
            account_id=account.id,
            category_name="Kahve",
            type="expense",
            amount="120.00",
            description="Kahve",
        ),
        db_session,
    )
    create_transaction_endpoint(
        TransactionCreate(
            account_id=account.id,
            category_name="Maas",
            type="income",
            amount="2500.00",
            description="Maas",
        ),
        db_session,
    )

    filtered = list_transactions(account_id=account.id, type="expense", search="kah", db=db_session)
    assert len(filtered) == 1
    assert filtered[0].id == first.id

    updated = update_transaction_endpoint(
        first.id,
        TransactionUpdate(amount="200.00", description="Kahve guncel", category_name="Kafe", note="Ofis ici"),
        db_session,
    )
    assert updated.amount == Decimal("200.00")
    assert updated.category_name == "Kafe"
    assert updated.note == "Ofis ici"
    assert db_session.get(Account, account.id).balance == Decimal("7300.00")

    delete_transaction_endpoint(first.id, db_session)
    assert db_session.get(Account, account.id).balance == Decimal("7500.00")
    assert db_session.get(Transaction, first.id) is None


def test_api_routes_are_registered_on_app():
    paths = {route.path for route in app.routes}

    assert "/api/v1/accounts" in paths
    assert "/api/v1/transactions" in paths
    assert "/api/v1/transactions/summary" in paths
    assert "/api/v1/transactions/{transaction_id}" in paths
