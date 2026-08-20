import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pytest
from fastapi.testclient import TestClient

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
        "INSERT INTO career_state (career_id, game_date, season_id, money, condition) "
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


_FAKE_STATS = {
    "goals": 1, "shots": 10, "shots_on_target": 4, "corners": 5,
    "dangerous_attacks": 8, "total_attacks": 20, "yellow_cards": 1,
    "red_cards": 0, "penalties": 0, "penalty_goals": 0, "fouls": 6,
    "substitutions": 2, "possession_ticks": 50,
}


@pytest.fixture
def mock_engine(monkeypatch):
    """Stands in for domain.engine_client.simulate_batch() so T3's
    background-sim tests don't need a live match_engine server on :8000
    (the real E12 endpoint exists — see match_engine's
    api/routers/simulate_batch.py — this just keeps the suite offline).
    Every match comes back 1-1."""
    def _fake_simulate_batch(matches):
        return [
            {
                "ref": m["ref"], "score": {"home": 1, "away": 1},
                "stats": {"home": dict(_FAKE_STATS), "away": dict(_FAKE_STATS)},
                "final_possession_home": 50.0,
            }
            for m in matches
        ]

    monkeypatch.setattr("domain.engine_client.simulate_batch", _fake_simulate_batch)


@pytest.fixture
def api_client(tmp_path, monkeypatch):
    """A FastAPI TestClient wired to a fresh, migrated SQLite file per
    test. config.DB_PATH is read dynamically (not bound at import time) by
    both the startup migration hook and api/deps.get_db(), specifically so
    monkeypatching it here redirects every request this client makes."""
    db_path = tmp_path / "test_career_engine.db"
    monkeypatch.setattr("api.config.DB_PATH", db_path)

    from api.app import app

    with TestClient(app) as client:
        yield client


# §5.1 C1's request body, in one place: create_career takes six required
# fields now and the starting club is assigned rather than passed, so every
# router test that wants a career goes through here instead of repeating the
# payload — and reads the club it actually got out of the response.
CAREER_PAYLOAD = {
    "first_name": "Efe",
    "last_name": "Kaan",
    "nationality": "TR",
    "position": "Orta saha",
    "role": "merkez_orta_saha",
    "target_team_id": "t_gal",
    "seed": 42,
}


def create_career(api_client, **overrides) -> dict:
    """POSTs /careers and returns the hub body. Overrides merge into
    CAREER_PAYLOAD, so a test that cares about one field names only it."""
    payload = {**CAREER_PAYLOAD, **overrides}
    resp = api_client.post("/careers", json=payload)
    assert resp.status_code == 201, resp.json()
    return resp.json()


def new_career(api_client, **overrides):
    """(career_id, team_id) for the common case. team_id is whatever §3
    assigned — no test may assume a particular club."""
    body = create_career(api_client, **overrides)
    return body["career_id"], body["player"]["team"]["team_id"]


def grant_money(career_id, amount, reason="test:top-up") -> None:
    """§4 starts a career at STARTING_MONEY (100), which is deliberate but
    leaves it unable to afford anything in the shop. Tests that exercise
    spending credit themselves first — through wallet.apply() rather than a
    bare UPDATE, so INV-19 (ledger total == balance) still holds afterwards."""
    from api import config
    from db.connection import get_connection
    from domain import wallet

    conn = get_connection(config.DB_PATH)
    try:
        wallet.apply(conn, career_id, amount, "sale", reason, "2026-08-01")
        conn.commit()
    finally:
        conn.close()


def advance_to_match_day(api_client, career_id, max_calls=10) -> dict:
    """Walks the day loop until the user's own fixture is today, the way a
    player does. A new career opens on a preparation week
    (onboarding.LEAGUE_STARTS_ON is a week after the season starts) and M1
    only hands out today's fixture (§6.1), so any test that wants to play a
    match has to get there first. Needs the `mock_engine` fixture, since
    advancing simulates the day's other fixtures.

    Returns the T1 body for the match day it stopped on."""
    for _ in range(max_calls):
        day = api_client.get(f"/careers/{career_id}/day").json()
        if day["is_match_day"]:
            return day
        resp = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"})
        assert resp.status_code == 200, resp.json()
    raise AssertionError(f"no match day reached for {career_id} in {max_calls} advances")
