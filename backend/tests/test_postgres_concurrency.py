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
