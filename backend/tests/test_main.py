from psycopg.errors import UndefinedColumn
from sqlalchemy.exc import ProgrammingError

from app.main import _database_error_detail, _is_missing_column_error


def test_missing_column_errors_are_detected_as_schema_mismatches():
    exc = ProgrammingError(
        "SELECT events.is_important FROM events",
        {},
        UndefinedColumn('column "events.is_important" does not exist'),
    )

    assert _is_missing_column_error(exc) is True
    assert "alembic -c alembic.ini upgrade head" in _database_error_detail(exc)


def test_other_programming_errors_keep_generic_message():
    exc = ProgrammingError("SELECT 1", {}, Exception("syntax error"))

    assert _is_missing_column_error(exc) is False
    assert _database_error_detail(exc) == "Veritabani sorgusu calisirken beklenmeyen bir hata olustu."
