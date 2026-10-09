"""Wallet v3: client-id operations, households, the pull feed and reconciliation."""

from datetime import date
from decimal import Decimal
from uuid import uuid4

from sqlalchemy import select, update

from app.models import Account, Category, CategoryType, Transaction, User
from app.operations.wallet import add_months, split_amount
from app.services.auth import ensure_default_user, issue_access_token
from app.services.reconcile import find_drift, fix_drift
from tests.conftest import api_request


def op(key: str, *, headers=None, request_id=None, **values):
    return api_request("POST", "/api/v2/operations/execute", headers=headers, json={
        "request_id": request_id or str(uuid4()),
        "operation_key": key,
        **values,
    })


def pull(since=0, scope=None, headers=None):
    params = {"since": since}
    if scope:
        params["scope"] = scope
    response = api_request("GET", "/api/v3/wallet/pull", params=params, headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


def save_account(account_id, *, headers=None, expected_version=None, **fields):
    account = {"id": account_id, "name": account_id.title(), "type": "bank", **fields}
    response = op("wallet.account.save", headers=headers, account=account, expected_version=expected_version)
    assert response.status_code == 200, response.text
    return response


def expense(tx_id, account_id, amount, *, headers=None, at="2026-10-09T12:00:00+03:00", **extra):
    return op("wallet.transaction.save", headers=headers, id=tx_id, account_id=account_id, kind="expense",
              amount=amount, occurred_at=at, **extra)


def balances(data):
    return {account["id"]: Decimal(account["balance"]) for account in data["accounts"]}


def second_user(setup_database, email="partner@example.com", name="Partner"):
    with setup_database() as session:
        user = User(email=email, display_name=name)
        session.add(user)
        session.flush()
        _, token = issue_access_token(session, user, label="test")
        session.commit()
        return user.id, {"Authorization": f"Bearer {token}"}


def market_id(setup_database):
    with setup_database() as session:
        category = Category(name="Market", type=CategoryType.EXPENSE, is_system=True)
        session.add(category)
        session.commit()
        return category.id


def test_amounts_split_into_kurus_with_the_rest_on_the_first_part():
    assert split_amount(Decimal("1000.00"), 3) == [Decimal("333.34"), Decimal("333.33"), Decimal("333.33")]
    assert sum(split_amount(Decimal("99.99"), 7)) == Decimal("99.99")
    from datetime import datetime

    assert add_months(datetime(2026, 1, 31, 12), 1) == datetime(2026, 2, 28, 12)


def test_account_and_expense_round_trip_and_replay_applies_once(setup_database):
    save_account("bank", opening_balance="1000")
    category_id = market_id(setup_database)
    request_id = str(uuid4())
    first = expense("t1", "bank", "125.45", request_id=request_id, note="Haftalık alışveriş", category_id=category_id)
    replay = expense("t1", "bank", "125.45", request_id=request_id, note="Haftalık alışveriş", category_id=category_id)
    reused = expense("t1", "bank", "99", request_id=request_id, category_id=category_id)

    assert first.status_code == 200
    assert replay.status_code == 200 and replay.json()["replayed"] is True
    assert reused.status_code == 409

    data = pull()
    assert balances(data)["bank"] == Decimal("874.55")
    [tx] = data["transactions"]
    assert tx["note"] == "Haftalık alışveriş" and tx["category"] == "Market" and tx["account_id"] == "bank"
    assert data["reset"] is True and data["scope"].startswith("u:")


def test_editing_moves_the_effect_and_stale_versions_get_the_current_record(setup_database):
    save_account("bank", opening_balance="1000")
    save_account("cash", type="cash", opening_balance="100")
    expense("t1", "bank", "50")

    moved = expense("t1", "cash", "30", expected_version=1)
    stale = expense("t1", "bank", "10", expected_version=1)

    assert moved.status_code == 200
    assert stale.status_code == 409
    current = stale.json()["detail"]["current"]
    assert current["account_id"] == "cash" and current["amount"] == "30.00" and current["version"] == 2
    after = balances(pull())
    assert (after["bank"], after["cash"]) == (Decimal("1000.00"), Decimal("70.00"))


def test_installments_split_over_statements_and_go_together(setup_database):
    save_account("card", type="credit_card", credit_limit="10000", statement_day=15, due_day=25)
    response = expense("buy", "card", "1000", installments=3, at="2026-10-20T10:00:00+03:00")
    assert response.status_code == 200

    data = pull()
    parts = sorted(data["transactions"], key=lambda t: t["installment_index"])
    assert [p["id"] for p in parts] == ["buy", "buy~2", "buy~3"]
    assert [p["amount"] for p in parts] == ["333.34", "333.33", "333.33"]
    assert [p["statement_month"] for p in parts] == ["2026-11-01", "2026-12-01", "2027-01-01"]
    assert balances(data)["card"] == Decimal("-1000.00")

    # Fewer installments drops the extra parts; deleting any part deletes the purchase.
    assert expense("buy", "card", "1000", installments=2, at="2026-10-20T10:00:00+03:00", expected_version=1).status_code == 200
    after_edit = pull(data["cursor"], data["scope"])
    assert {"kind": "transaction", "id": "buy~3"} in after_edit["deleted"]
    assert op("wallet.transaction.delete", id="buy~2").status_code == 200
    assert pull()["transactions"] == [] and balances(pull())["card"] == Decimal("0.00")

    income = op("wallet.transaction.save", id="x", account_id="card", kind="income", amount="10",
                occurred_at="2026-10-09T12:00:00+03:00", installments=2)
    assert income.status_code == 400
    save_account("bank")
    assert expense("y", "bank", "10", installments=2).status_code == 400


def test_card_payment_transfer_moves_money_and_can_be_undone(setup_database):
    save_account("bank", opening_balance="2000")
    save_account("card", type="credit_card", credit_limit="5000", statement_day=1)
    expense("t", "card", "800")
    pay = op("wallet.transfer.save", id="p1", from_account_id="bank", to_account_id="card", amount="500",
             occurred_at="2026-10-09T12:00:00+03:00")
    assert pay.status_code == 200
    after = balances(pull())
    assert (after["bank"], after["card"]) == (Decimal("1500.00"), Decimal("-300.00"))

    op("wallet.transfer.save", id="p1", from_account_id="bank", to_account_id="card", amount="800",
       occurred_at="2026-10-09T12:00:00+03:00", expected_version=1)
    assert balances(pull())["card"] == Decimal("0.00")
    op("wallet.transfer.delete", id="p1")
    assert balances(pull())["bank"] == Decimal("2000.00")
    assert op("wallet.transfer.save", id="p2", from_account_id="bank", to_account_id="bank", amount="1",
              occurred_at="2026-10-09T12:00:00+03:00").status_code == 400


def test_statement_marks_can_be_set_and_returned_to_automatic(setup_database):
    save_account("card", type="credit_card", statement_day=10)
    data = pull()
    assert op("wallet.statement.mark", account_id="card", month="2026-10-17", paid=True).status_code == 200
    changed = pull(data["cursor"], data["scope"])
    assert changed["statement_marks"] == [{"id": "card:2026-10", "account_id": "card", "month": "2026-10-01", "paid": True, "version": 1}]
    op("wallet.statement.mark", account_id="card", month="2026-10-01", paid=None)
    assert {"kind": "statement_mark", "id": "card:2026-10"} in pull(changed["cursor"], data["scope"])["deleted"]


def test_household_members_share_only_shared_accounts(setup_database):
    partner_id, partner = second_user(setup_database)
    outsider_id, outsider = second_user(setup_database, "out@example.com", "Out")

    assert save_account("own").status_code == 200
    shared_too_early = op("wallet.account.save", account={"id": "joint", "name": "Ortak", "type": "credit_card", "visibility": "shared"})
    assert shared_too_early.status_code == 400

    code = api_request("POST", "/api/v3/household/invites").json()["code"]
    joined = api_request("POST", "/api/v3/household/join", json={"code": code.lower()}, headers=partner)
    assert joined.status_code == 200
    assert [m["name"] for m in joined.json()["household"]["members"]][1] == "Partner"
    assert api_request("POST", "/api/v3/household/join", json={"code": code}, headers=outsider).status_code == 400

    save_account("joint", name="Ortak kart", type="credit_card", visibility="shared", credit_limit="20000")
    mine_before = pull()
    assert mine_before["scope"].startswith("h:")

    # The partner sees the shared card, not the personal account, and can spend on it.
    theirs = pull(headers=partner)
    assert [a["id"] for a in theirs["accounts"]] == ["joint"]
    assert expense("pt", "joint", "120", headers=partner).status_code == 200
    assert expense("px", "own", "1", headers=partner).status_code == 403
    assert expense("ox", "joint", "1", headers=outsider).status_code == 403
    assert op("wallet.account.save", headers=partner, account={"id": "joint", "name": "X", "type": "credit_card"}).status_code == 403

    # The owner pulls the partner's expense with its author.
    news = pull(mine_before["cursor"], mine_before["scope"])
    [tx] = news["transactions"]
    assert tx["id"] == "pt" and tx["created_by"] == partner_id
    assert balances(news)["joint"] == Decimal("-120.00")

    # Making it personal again hides it from the partner.
    partner_view = pull(headers=partner)
    save_account("joint", name="Ortak kart", type="credit_card", visibility="personal", credit_limit="20000", expected_version=1)
    hidden = pull(partner_view["cursor"], partner_view["scope"], headers=partner)
    assert {"kind": "account", "id": "joint"} in hidden["deleted"]


def test_leaving_keeps_the_leavers_shared_accounts_personal(setup_database):
    _, partner = second_user(setup_database)
    code = api_request("POST", "/api/v3/household/invites").json()["code"]
    api_request("POST", "/api/v3/household/join", json={"code": code}, headers=partner)
    save_account("joint", type="credit_card", visibility="shared")
    partner_view = pull(headers=partner)
    owner_scope = pull()["scope"]

    left = api_request("POST", "/api/v3/household/leave")

    assert left.json() == {"household": None}
    assert {"kind": "account", "id": "joint"} in pull(partner_view["cursor"], partner_view["scope"], headers=partner)["deleted"]
    mine = pull(5, owner_scope)
    assert mine["reset"] is True and mine["scope"].startswith("u:")
    assert [(a["id"], a["visibility"]) for a in mine["accounts"] if a["id"] == "joint"] == [("joint", "personal")]


def test_v1_writes_show_up_in_the_feed_and_balances_reconcile(setup_database):
    save_account("bank", opening_balance="500")
    data = pull()
    with setup_database() as session:
        account_id = session.scalar(select(Account.id).where(Account.client_id == "bank"))
    created = api_request("POST", "/api/v1/transactions", json={
        "account_id": account_id, "type": "expense", "amount": "40", "description": "Web", "category_name": "Market",
    })
    assert created.status_code in (200, 201), created.text
    news = pull(data["cursor"], data["scope"])
    assert len(news["transactions"]) == 1 and balances(news)["bank"] == Decimal("460.00")

    with setup_database() as session:
        assert find_drift(session) == []
        session.execute(update(Account).where(Account.id == account_id).values(balance=Decimal("999")))
        session.commit()
        [drift] = find_drift(session)
        assert drift.difference == Decimal("539.00")
        fix_drift(session)
        session.commit()
        assert find_drift(session) == []
        assert session.get(Account, account_id).balance == Decimal("460.00")


def test_manual_version_bump_does_not_double_count(setup_database):
    with setup_database() as session:
        owner = ensure_default_user(session)
        account = Account(user_id=owner.id, client_id="v", name="V", type="cash", balance=0)
        session.add(account)
        session.commit()
        account.name = "W"
        account.entity_version += 1  # what daily.py's _bump does
        session.commit()
        assert account.entity_version == 2
