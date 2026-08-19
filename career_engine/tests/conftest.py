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


@pytest.fixture
def player_id(db_conn, career_id):
    """A minimal player row. player_attribute has a real FK to this
    (CONTRACT.md §3.2), so any test writing attributes needs it first."""
    pid = "p_user"
    db_conn.execute(
        "INSERT INTO player (career_id, player_id, name, position, birth_date, team_id, is_user) "
        "VALUES (?, ?, 'Efe Kaan', 'Orta saha', '2004-08-19', 't_ykz', 1)",
        (career_id, pid),
    )
    db_conn.commit()
    return pid


@pytest.fixture
def seeded_relationship(db_conn, career_id):
    """One 'coach' relationship row at score=50, no traits yet — the
    starting point most relationship-module tests build on."""
    db_conn.execute(
        "INSERT INTO relationship "
        "(career_id, relationship_id, kind, category, score, person_name, contact_name) "
        "VALUES (?, 'coach', 'coach', 'Antrenör', 50, 'Mert Aydın', 'Mert Hoca')",
        (career_id,),
    )
    db_conn.commit()
    return "coach"
