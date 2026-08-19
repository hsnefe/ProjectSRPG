import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pytest

from db.connection import get_connection
from db.migrate import apply_migrations


@pytest.fixture
def db_conn():
    """A fresh, fully-migrated in-memory database, isolated per test."""
    conn = get_connection(":memory:")
    apply_migrations(conn)
    yield conn
    conn.close()


@pytest.fixture
def career_id(db_conn):
    """A minimal career + career_state row (money=0) for domain-module
    tests that don't need a full C1 career-creation flow."""
    cid = "car_test0000"
    db_conn.execute(
        "INSERT INTO career (career_id, created_at, seed, schema_version) VALUES (?, ?, ?, ?)",
        (cid, "2026-01-01T00:00:00+03:00", 1, 1),
    )
    db_conn.execute(
        "INSERT INTO career_state (career_id, current_date, season_id, money, condition) "
        "VALUES (?, ?, ?, ?, ?)",
        (cid, "2026-01-01", "25/26", 0, 72),
    )
    db_conn.commit()
    return cid
