from datetime import date

import pytest

from api.errors import ApiError
from domain import onboarding, wallet
from worlddata.teams import TIER1_TEAMS


def _count(conn, career_id, table, extra_sql="", params=()):
    row = conn.execute(
        f"SELECT COUNT(*) AS c FROM {table} WHERE career_id = ? {extra_sql}",
        (career_id, *params),
    ).fetchone()
    return row["c"]


def test_create_career_writes_the_full_world(db_conn):
    career_id = onboarding.create_career(db_conn, "Efe Kaan", "Orta saha", "t_ykz", seed=42)
    db_conn.commit()

    assert _count(db_conn, career_id, "team") == 32
    assert _count(db_conn, career_id, "competition") == 3
    assert _count(db_conn, career_id, "competition_rule") == 2
    # 32 league entries (each team enters its own tier) + 32 cup entries
    # (every team plays the cup too) — competition_entry is exhaustive
    # across all competition kinds, not league-only.
    assert _count(db_conn, career_id, "competition_entry") == 64
    assert _count(db_conn, career_id, "season") == 1
    # §7: 34 + 26 + 5 = 65 rounds; 306 + 182 + 16 (cup round 1) = 504 fixtures.
    assert _count(db_conn, career_id, "competition_round") == 65
    assert _count(db_conn, career_id, "fixture") == 504
    assert _count(db_conn, career_id, "player") == 1
    assert _count(db_conn, career_id, "player_attribute") == 11
    assert _count(db_conn, career_id, "player_contract") == 1
    assert _count(db_conn, career_id, "relationship") == 5
    assert _count(db_conn, career_id, "day_budget") == 2  # time, energy


def test_create_career_starting_balance_matches_ledger_inv19(db_conn):
    career_id = onboarding.create_career(db_conn, "Efe Kaan", "Orta saha", "t_ykz", seed=1)
    db_conn.commit()

    assert wallet.get_balance(db_conn, career_id) == wallet.ledger_total(db_conn, career_id)


def test_create_career_rejects_tier1_club(db_conn):
    tier1_id = TIER1_TEAMS[0]["team_id"]
    with pytest.raises(ApiError) as exc_info:
        onboarding.create_career(db_conn, "Efe Kaan", "Orta saha", tier1_id, seed=1)
    assert exc_info.value.code == "invalid_request"


def test_create_career_rejects_invalid_position(db_conn):
    with pytest.raises(ApiError) as exc_info:
        onboarding.create_career(db_conn, "Efe Kaan", "Hücum kanadı", "t_ykz", seed=1)
    assert exc_info.value.code == "invalid_request"


def test_create_career_cup_round1_pairs_every_team_once(db_conn):
    career_id = onboarding.create_career(db_conn, "Efe Kaan", "Orta saha", "t_ykz", seed=7)
    db_conn.commit()

    rows = db_conn.execute(
        "SELECT home_team_id, away_team_id FROM fixture "
        "WHERE career_id = ? AND competition_id = 'c_kupa' AND round_no = 1",
        (career_id,),
    ).fetchall()
    assert len(rows) == 16
    teams = [t for row in rows for t in (row["home_team_id"], row["away_team_id"])]
    assert len(set(teams)) == 32


def test_create_career_is_deterministic_for_same_seed(db_conn):
    id_a = onboarding.create_career(db_conn, "A", "Orta saha", "t_ykz", seed=99)
    db_conn.commit()
    id_b = onboarding.create_career(db_conn, "B", "Orta saha", "t_ykz", seed=99)
    db_conn.commit()

    def first_round_pairs(career_id):
        rows = db_conn.execute(
            "SELECT home_team_id, away_team_id FROM fixture "
            "WHERE career_id = ? AND competition_id = 'c_lig2' AND round_no = 1 "
            "ORDER BY home_team_id",
            (career_id,),
        ).fetchall()
        return [(r["home_team_id"], r["away_team_id"]) for r in rows]

    assert first_round_pairs(id_a) == first_round_pairs(id_b)


def test_career_opens_a_week_before_the_first_league_round(db_conn):
    """§6.1 - the career starts on a preparation week, so a new player gets
    a full day loop before their first match instead of kicking off on day
    one."""
    career_id = onboarding.create_career(db_conn, "Efe Kaan", "Orta saha", "t_ykz", seed=7)
    db_conn.commit()

    game_date = db_conn.execute(
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"]
    first_kickoff = db_conn.execute(
        "SELECT MIN(kickoff_at) AS k FROM fixture WHERE career_id = ?", (career_id,)
    ).fetchone()["k"]

    assert game_date == onboarding.SEASON_STARTS_ON
    assert first_kickoff[:10] == onboarding.LEAGUE_STARTS_ON
    gap = date.fromisoformat(first_kickoff[:10]) - date.fromisoformat(game_date)
    assert gap.days == 7


def test_no_team_is_ever_drawn_into_two_fixtures_on_one_day(db_conn):
    """The league runs on Saturdays and the cup midweek, so M1's "today's
    fixture" query can never face two candidates. Cup rounds past the first
    aren't drawn yet, so this covers round 1 plus every league round."""
    career_id = onboarding.create_career(db_conn, "Efe Kaan", "Orta saha", "t_ykz", seed=7)
    db_conn.commit()

    rows = db_conn.execute(
        "SELECT kickoff_at, home_team_id, away_team_id FROM fixture WHERE career_id = ?",
        (career_id,),
    ).fetchall()
    seen = set()
    for row in rows:
        for team_id in (row["home_team_id"], row["away_team_id"]):
            key = (row["kickoff_at"][:10], team_id)
            assert key not in seen, f"{team_id} has two fixtures on {key[0]}"
            seen.add(key)

    # And the two calendars never share a day in the first place.
    league_days = {
        r["kickoff_at"][:10] for r in db_conn.execute(
            "SELECT kickoff_at FROM fixture WHERE career_id = ? AND competition_id != 'c_kupa'",
            (career_id,),
        ).fetchall()
    }
    assert {date.fromisoformat(d).weekday() for d in league_days} == {5}  # Saturday
    cup_days = {
        r["scheduled_on"] for r in db_conn.execute(
            "SELECT scheduled_on FROM competition_round WHERE career_id = ? AND competition_id = 'c_kupa'",
            (career_id,),
        ).fetchall()
    }
    assert {date.fromisoformat(d).weekday() for d in cup_days} == {2}   # Wednesday
    assert cup_days.isdisjoint(league_days)
