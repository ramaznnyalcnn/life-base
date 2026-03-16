"""Bootstrap and seed helpers."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Account, AccountType, Category, CategoryType
from app.services.auth import ensure_default_user


DEFAULT_CATEGORIES: tuple[tuple[str, CategoryType, bool], ...] = (
    ("Market", CategoryType.EXPENSE, True),
    ("Yeme Icmek", CategoryType.EXPENSE, True),
    ("Ulasim", CategoryType.EXPENSE, True),
    ("Faturalar", CategoryType.EXPENSE, True),
    ("Abonelik", CategoryType.EXPENSE, True),
    ("Saglik", CategoryType.EXPENSE, True),
    ("Diger Gider", CategoryType.EXPENSE, True),
    ("Maas", CategoryType.INCOME, True),
    ("Serbest Gelir", CategoryType.INCOME, True),
    ("Iade", CategoryType.INCOME, True),
    ("Diger Gelir", CategoryType.INCOME, True),
)


def ensure_default_categories(session: Session) -> int:
    """Insert default categories once and only once."""

    existing_names = set(
        session.scalars(select(Category.name).where(Category.is_system.is_(True), Category.user_id.is_(None))).all()
    )
    created = 0

    for name, category_type, is_system in DEFAULT_CATEGORIES:
        if name in existing_names:
            continue
        session.add(Category(name=name, type=category_type, is_system=is_system))
        created += 1

    if created:
        session.commit()

    return created


def ensure_default_cash_account(session: Session, user_id: int | None = None) -> Account:
    """Guarantee a single default cash account for first-run flows."""
    owner_id = user_id if user_id is not None else ensure_default_user(session).id

    existing = session.scalar(
        select(Account).where(
            Account.user_id == owner_id,
            Account.name == "Nakit",
        )
    )
    if existing is not None:
        return existing

    account = Account(
        user_id=owner_id,
        name="Nakit",
        type=AccountType.CASH,
        currency="TRY",
        balance=0,
        issuer="Varsayilan",
        is_active=True,
    )
    session.add(account)
    session.commit()
    session.refresh(account)
    return account
