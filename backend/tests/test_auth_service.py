from app.services.auth import (
    authenticate_access_token,
    authenticate_user_password,
    ensure_default_user,
    get_or_create_user,
    hash_access_token,
    verify_password,
    issue_access_token,
)


def test_ensure_default_user_is_idempotent(db_session):
    first = ensure_default_user(db_session)
    second = ensure_default_user(db_session)

    assert first.id == second.id


def test_issue_and_authenticate_access_token(db_session):
    user = get_or_create_user(
        db_session,
        email="owner@example.com",
        display_name="Owner",
    )
    token, raw_token = issue_access_token(
        db_session,
        user,
        label="Test token",
        raw_token="fixed-secret-token",
    )

    assert token.token_hash == hash_access_token("fixed-secret-token")

    authenticated = authenticate_access_token(db_session, raw_token)

    assert authenticated is not None
    assert authenticated.id == user.id


def test_password_hash_and_login_flow(db_session):
    user = get_or_create_user(
        db_session,
        email="owner@example.com",
        display_name="Owner",
        password="super-secret-password",
    )

    assert verify_password("super-secret-password", user.password_hash)

    authenticated = authenticate_user_password(
        db_session,
        email="owner@example.com",
        password="super-secret-password",
    )

    assert authenticated is not None
    assert authenticated.id == user.id
