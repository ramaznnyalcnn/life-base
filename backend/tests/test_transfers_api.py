from datetime import datetime, timezone
from decimal import Decimal

from app.api.routes.transfers import (
    create_transfer_endpoint,
    delete_transfer_endpoint,
    list_transfers_endpoint,
    update_transfer_endpoint,
)
from app.main import app
from app.models import Account, AccountType, Transfer
from app.schemas import TransferCreate, TransferUpdate


def seed_accounts(db_session):
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
        balance=Decimal("10000.00"),
        credit_limit=Decimal("25000.00"),
        statement_day=10,
        due_day=20,
    )
    db_session.add_all([source, destination])
    db_session.commit()
    db_session.refresh(source)
    db_session.refresh(destination)
    return source, destination


def test_transfers_api_creates_lists_updates_and_deletes_transfer(db_session):
    source, destination = seed_accounts(db_session)

    created = create_transfer_endpoint(
        TransferCreate(
            source_account_id=source.id,
            destination_account_id=destination.id,
            amount="490.00",
            description="Kredi karti odemesi",
            occurred_at=datetime(2026, 3, 14, 12, 0, tzinfo=timezone.utc),
        ),
        db_session,
    )

    assert created.id is not None
    assert created.source_account_name == "Enpara"
    assert created.destination_account_name == "Ziraat"
    assert db_session.get(Account, source.id).balance == Decimal("4510.00")
    assert db_session.get(Account, destination.id).balance == Decimal("10490.00")

    rows = list_transfers_endpoint(db=db_session)
    assert len(rows) == 1

    updated = update_transfer_endpoint(
        created.id,
        TransferUpdate(amount="500.00", description="Kart odemesi guncel"),
        db_session,
    )

    assert updated.amount == Decimal("500.00")
    assert updated.description == "Kart odemesi guncel"
    assert db_session.get(Account, source.id).balance == Decimal("4500.00")
    assert db_session.get(Account, destination.id).balance == Decimal("10500.00")

    delete_transfer_endpoint(created.id, db_session)

    assert db_session.get(Account, source.id).balance == Decimal("5000.00")
    assert db_session.get(Account, destination.id).balance == Decimal("10000.00")
    assert db_session.get(Transfer, created.id) is None


def test_transfer_routes_are_registered_on_app():
    paths = {route.path for route in app.routes}

    assert "/api/v1/transfers" in paths
    assert "/api/v1/transfers/{transfer_id}" in paths
