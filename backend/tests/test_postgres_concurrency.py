"""Concurrency checks that need real row locking (SQLite serializes everything).

Run against a migrated Postgres:
    LIFEBASE_TEST_POSTGRES_URL=postgresql+psycopg://... pytest tests/test_postgres_concurrency.py
"""

import os
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker

from app.models import SyncDocument, User
from app.schemas.sync import SyncChange
from app.services.sync import push_changes

POSTGRES_URL = os.environ.get("LIFEBASE_TEST_POSTGRES_URL")
pytestmark = pytest.mark.skipif(not POSTGRES_URL, reason="LIFEBASE_TEST_POSTGRES_URL not set")

T0 = datetime(2026, 10, 9, 12, 0, tzinfo=timezone.utc)


@pytest.fixture
def pg_sessions():
    engine = create_engine(POSTGRES_URL, pool_size=10)
    factory = sessionmaker(bind=engine, expire_on_commit=False)
    with factory() as session:
        user = User(email=f"sync-{uuid4().hex}@lifeos.local", display_name="Sync")
        session.add(user)
        session.commit()
        user_id = user.id
    yield factory, user_id
    engine.dispose()


def test_parallel_pushes_get_unique_sequence_numbers(pg_sessions):
    factory, user_id = pg_sessions

    def device(index: int):
        changes = [
            SyncChange(collection="events", id=f"d{index}-{n}", updated_at=T0, body={"n": n}) for n in range(20)
        ]
        # Every device also edits one shared document at a different time.
        changes.append(SyncChange(collection="events", id="shared", updated_at=T0 + timedelta(seconds=index), body={"by": index}))
        with factory() as session:
            push_changes(session, user_id, changes)
            session.commit()

    with ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(device, range(8)))

    with factory() as session:
        rows = session.scalars(select(SyncDocument).where(SyncDocument.user_id == user_id)).all()
        seqs = sorted(row.seq for row in rows)
        shared = next(row for row in rows if row.doc_id == "shared")

    assert len(rows) == 8 * 20 + 1
    # Distinct, and no number handed out twice even under contention.
    assert len(set(seqs)) == len(seqs)
    assert seqs[-1] <= 8 * 21
    # Last writer wins regardless of the order the requests landed in.
    assert shared.body == {"by": 7}


# Wallet ----------------------------------------------------------------

from decimal import Decimal  # noqa: E402

from app.models import Account, Household, HouseholdMember, Transaction, WalletChange  # noqa: E402
from app.operations.catalog import build_operation_registry  # noqa: E402
from app.operations.executor import EntityVersionConflictError, OperationExecutor  # noqa: E402
from app.schemas.operation_inputs import OperationInput  # noqa: E402
from app.services.reconcile import find_drift  # noqa: E402

EXECUTOR = OperationExecutor(build_operation_registry())


def _run(factory, user_id, key, **values):
    with factory() as session:
        payload = OperationInput.model_validate({"request_id": str(uuid4()), "operation_key": key, **values})
        return EXECUTOR.execute(session, payload, user_id=user_id)


@pytest.fixture
def household(pg_sessions):
    """Two members of one household and a shared card owned by the first."""
    factory, owner_id = pg_sessions
    with factory() as session:
        partner = User(email=f"partner-{uuid4().hex}@lifeos.local", display_name="Partner")
        home = Household(name="Ev")
        session.add_all([partner, home])
        session.flush()
        session.add_all([
            HouseholdMember(household_id=home.id, user_id=owner_id, role="owner"),
            HouseholdMember(household_id=home.id, user_id=partner.id),
        ])
        session.commit()
        partner_id, household_id = partner.id, home.id
    card = f"card-{uuid4().hex}"
    _run(factory, owner_id, "wallet.account.save", account={
        "id": card, "name": "Ortak kart", "type": "credit_card", "visibility": "shared", "credit_limit": "100000",
    })
    return factory, owner_id, partner_id, household_id, card


def test_parallel_expenses_on_a_shared_card_all_land(household):
    factory, owner_id, partner_id, household_id, card = household
    amounts = [Decimal(f"{n}.25") for n in range(1, 41)]

    def spend(index):
        user = owner_id if index % 2 else partner_id
        _run(factory, user, "wallet.transaction.save", id=f"{card}-t{index}", account_id=card, kind="expense",
             amount=str(amounts[index]), occurred_at="2026-10-09T12:00:00+03:00")

    with ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(spend, range(len(amounts))))

    with factory() as session:
        account = session.scalar(select(Account).where(Account.client_id == card))
        count = len(session.scalars(select(Transaction).where(Transaction.account_id == account.id)).all())
        seqs = sorted(session.scalars(select(WalletChange.seq).where(WalletChange.scope == f"h:{household_id}")).all())
        drift = [d for d in find_drift(session) if d.account_id == account.id]

    assert account.balance == -sum(amounts)
    assert count == len(amounts)
    assert seqs == list(range(1, len(seqs) + 1)), "numbers are handed out without gaps or repeats"
    assert drift == []


def test_concurrent_edits_of_one_expense_let_exactly_one_win(household):
    factory, owner_id, partner_id, _, card = household
    tx = f"{card}-edit"
    _run(factory, owner_id, "wallet.transaction.save", id=tx, account_id=card, kind="expense", amount="100",
         occurred_at="2026-10-09T12:00:00+03:00")

    def edit(args):
        user, amount = args
        try:
            _run(factory, user, "wallet.transaction.save", id=tx, account_id=card, kind="expense", amount=amount,
                 occurred_at="2026-10-09T12:00:00+03:00", expected_version=1)
            return "ok"
        except EntityVersionConflictError as conflict:
            return conflict.current["amount"]

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(edit, [(owner_id, "150"), (partner_id, "175")]))

    assert results.count("ok") == 1
    loser = next(result for result in results if result != "ok")
    with factory() as session:
        account = session.scalar(select(Account).where(Account.client_id == card))
    # The loser was shown the winner's amount, and the balance holds the winner only.
    assert account.balance == -Decimal(loser)


def test_opposite_transfers_do_not_deadlock(household):
    factory, owner_id, _, _, card = household
    bank = f"bank-{uuid4().hex}"
    _run(factory, owner_id, "wallet.account.save", account={"id": bank, "name": f"Banka {bank[-6:]}", "type": "bank",
                                                           "opening_balance": "1000"})

    def move(index):
        source, target = (bank, card) if index % 2 else (card, bank)
        _run(factory, owner_id, "wallet.transfer.save", id=f"{bank}-m{index}", from_account_id=source,
             to_account_id=target, amount="10", occurred_at="2026-10-09T12:00:00+03:00")

    with ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(move, range(40)))

    with factory() as session:
        balance = session.scalar(select(Account.balance).where(Account.client_id == bank))
    assert balance == Decimal("1000.00")
