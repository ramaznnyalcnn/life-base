import asyncio
from collections.abc import Generator
from pathlib import Path
from uuid import uuid4

import httpx
import pytest
from sqlalchemy import create_engine, event
from sqlalchemy.orm import Session, sessionmaker

from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models import Account, Event, Medication, PushSubscription, Transaction, Transfer
from app.services.auth import ensure_default_user


@pytest.fixture(autouse=True)
def setup_database() -> Generator[sessionmaker, None, None]:
    db_path = Path("/tmp") / f"lifeos-test-{uuid4().hex}.db"
    engine = create_engine(
        f"sqlite:///{db_path}",
        connect_args={"check_same_thread": False},
    )
    testing_session_local = sessionmaker(
        bind=engine,
        autoflush=False,
        autocommit=False,
        expire_on_commit=False,
    )

    def assign_default_owner(session: Session, flush_context, instances) -> None:
        for obj in session.new:
            if isinstance(obj, (Account, Event, Medication, PushSubscription, Transaction, Transfer)) and obj.user_id is None:
                obj.user_id = default_user_id

    def override_get_db() -> Generator[Session, None, None]:
        db = testing_session_local()
        try:
            yield db
        finally:
            db.close()

    Base.metadata.create_all(bind=engine)
    bootstrap_session = testing_session_local()
    default_user = ensure_default_user(bootstrap_session)
    default_user_id = default_user.id
    bootstrap_session.close()
    event.listen(testing_session_local, "before_flush", assign_default_owner)
    app.dependency_overrides[get_db] = override_get_db
    yield testing_session_local
    app.dependency_overrides.clear()
    event.remove(testing_session_local, "before_flush", assign_default_owner)
    engine.dispose()
    if db_path.exists():
        db_path.unlink()


@pytest.fixture
def db_session(setup_database) -> Generator[Session, None, None]:
    session = setup_database()
    try:
        yield session
    finally:
        session.close()


def api_request(method: str, url: str, **kwargs) -> httpx.Response:
    async def _call():
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            return await client.request(method, url, **kwargs)

    return asyncio.run(_call())
