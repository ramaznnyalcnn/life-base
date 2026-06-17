from sqlalchemy import select

from app.models import Account, Category, AccountType
from app.services.bootstrap import DEFAULT_CATEGORIES, ensure_default_cash_account, ensure_default_categories


def test_default_categories_seed_once(db_session):
    created = ensure_default_categories(db_session)
    created_again = ensure_default_categories(db_session)

    rows = db_session.scalars(select(Category).order_by(Category.name)).all()

    assert created == len(DEFAULT_CATEGORIES)
    assert created_again == 0
    assert len(rows) == len(DEFAULT_CATEGORIES)
    assert any(category.name == "Maas" for category in rows)


def test_default_cash_account_seed_once(db_session):
    created = ensure_default_cash_account(db_session)
    created_again = ensure_default_cash_account(db_session)

    rows = db_session.scalars(select(Account).order_by(Account.id)).all()

    assert created.id == created_again.id
    assert len(rows) == 1
    assert rows[0].name == "Nakit"
    assert rows[0].type == AccountType.CASH
