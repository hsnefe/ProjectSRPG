from datetime import date

import pytest

from api import config
from api.errors import ApiError
from domain import onboarding, wallet
from worlddata.attributes import (
    BASE_SKILL_VALUE, FIXED_STARTING_ATTRIBUTES, ROLE_BONUS_PER_SLOT,
)
from worlddata.teams import TIER2_TEAMS

# §5.1 C1's argument list, so a test that cares about one field names only it.
CAREER_KWARGS = {
    "first_name": "Efe",
    "last_name": "Kaan",
    "nationality": "TR",
    "position": "Orta saha",
    "role": "merkez_orta_saha",
    "target_team_id": "t_gal",
}


def _create(conn, **overrides):
    return onboarding.create_career(conn, **{**CAREER_KWARGS, **overrides})


def _count(conn, career_id, table, extra_sql="", params=()):
    row = conn.execute(
        f"SELECT COUNT(*) AS c FROM {table} WHERE career_id = ? {extra_sql}",
        (career_id, *params),
    ).fetchone()
    return row["c"]


def _attr(conn, career_id, key):
    return conn.execute(
        "SELECT value FROM player_attribute WHERE career_id = ? AND attribute_key = ?",
        (career_id, key),
    ).fetchone()["value"]


def test_create_career_writes_the_full_world(db_conn):
    career_id = _create(db_conn, seed=42)
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
    assert _count(db_conn, career_id, "player_attribute") == 12
    assert _count(db_conn, career_id, "player_contract") == 1
    assert _count(db_conn, career_id, "relationship") == 6
    assert _count(db_conn, career_id, "day_budget") == 2  # time, energy
    # §2 - exams are sat after creation, so a fresh career has none.
    assert _count(db_conn, career_id, "skill_exam_result") == 0


def test_create_career_records_identity_and_target(db_conn):
    career_id = _create(db_conn, seed=42)
    db_conn.commit()

    row = db_conn.execute(
        "SELECT name, first_name, last_name, nationality, position, role, target_team_id "
        "FROM player WHERE career_id = ?", (career_id,)
    ).fetchone()
    assert row["name"] == "Efe Kaan"
    assert row["first_name"] == "Efe"
    assert row["last_name"] == "Kaan"
    assert row["nationality"] == "TR"
    assert row["position"] == "Orta saha"
    assert row["role"] == "merkez_orta_saha"
    assert row["target_team_id"] == "t_gal"


def test_create_career_assigns_a_club_in_the_countrys_bottom_league(db_conn):
    """§3 - the starting club comes from the player's nationality, not from
    the request, and it is always in that country's lowest division."""
    career_id = _create(db_conn, seed=42)
    db_conn.commit()

    team_id = db_conn.execute(
        "SELECT team_id FROM player WHERE career_id = ?", (career_id,)
    ).fetchone()["team_id"]

    tier2_ids = {t["team_id"] for t in TIER2_TEAMS}
    assert team_id in tier2_ids

    # And the contract is signed with that same club, not the target.
    contract_team = db_conn.execute(
        "SELECT team_id FROM player_contract WHERE career_id = ?", (career_id,)
    ).fetchone()["team_id"]
    assert contract_team == team_id


def test_role_attributes_start_two_points_above_base(db_conn):
    """§2 - the role's two slots each add ROLE_BONUS_PER_SLOT on top of the
    taban değer. merkez_orta_saha spends both on passing, so passing is +4
    while the other three skills sit at base."""
    career_id = _create(db_conn, role="merkez_orta_saha", seed=1)
    db_conn.commit()

    assert _attr(db_conn, career_id, "passing") == BASE_SKILL_VALUE + 2 * ROLE_BONUS_PER_SLOT
    assert _attr(db_conn, career_id, "shooting") == BASE_SKILL_VALUE
    assert _attr(db_conn, career_id, "dribbling") == BASE_SKILL_VALUE
    assert _attr(db_conn, career_id, "tackling") == BASE_SKILL_VALUE


def test_role_with_two_different_slots_spreads_the_bonus(db_conn):
    career_id = _create(db_conn, position="Forvet", role="hedef_adam", seed=1)
    db_conn.commit()

    # hedef_adam = (shooting, passing)
    assert _attr(db_conn, career_id, "shooting") == BASE_SKILL_VALUE + ROLE_BONUS_PER_SLOT
    assert _attr(db_conn, career_id, "passing") == BASE_SKILL_VALUE + ROLE_BONUS_PER_SLOT
    assert _attr(db_conn, career_id, "dribbling") == BASE_SKILL_VALUE
    assert _attr(db_conn, career_id, "tackling") == BASE_SKILL_VALUE


def test_strength_and_flexibility_are_fixed_regardless_of_role(db_conn):
    """§2 - Güç and Esneklik start from a fixed value; no role touches them."""
    a = _create(db_conn, role="merkez_orta_saha", seed=1)
    b = _create(db_conn, position="Defans", role="stoper", seed=1)
    db_conn.commit()

    for career_id in (a, b):
        assert _attr(db_conn, career_id, "strength") == FIXED_STARTING_ATTRIBUTES["strength"]
        assert _attr(db_conn, career_id, "flexibility") == FIXED_STARTING_ATTRIBUTES["flexibility"]


def test_starting_money_and_condition_match_config(db_conn):
    career_id = _create(db_conn, seed=1)
    db_conn.commit()

    state = db_conn.execute(
        "SELECT money, condition FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()
    assert state["money"] == config.STARTING_MONEY
    assert state["condition"] == config.STARTING_CONDITION
    # INV-10: the daily value never exceeds its attribute ceiling.
    assert _attr(db_conn, career_id, "condition") == float(config.STARTING_CONDITION)


def test_relationships_start_at_their_per_kind_scores(db_conn):
    """§4's starting table, per kind — not one flat score for all six."""
    career_id = _create(db_conn, seed=1)
    db_conn.commit()

    scores = {
        r["relationship_id"]: r["score"]
        for r in db_conn.execute(
            "SELECT relationship_id, score FROM relationship WHERE career_id = ?", (career_id,)
        ).fetchall()
    }
    assert scores == {
        "coach": 70, "team": 50, "media": 10, "fans": 40, "partner": 0, "family": 0,
    }


def test_create_career_starting_balance_matches_ledger_inv19(db_conn):
    career_id = _create(db_conn, seed=1)
    db_conn.commit()

    assert wallet.get_balance(db_conn, career_id) == wallet.ledger_total(db_conn, career_id)


def test_create_career_rejects_invalid_position(db_conn):
    with pytest.raises(ApiError) as exc_info:
        _create(db_conn, position="Hücum kanadı", seed=1)
    assert exc_info.value.code == "invalid_request"


def test_create_career_rejects_goalkeeper_position(db_conn):
    with pytest.raises(ApiError) as exc_info:
        _create(db_conn, position="Kaleci", seed=1)
    assert exc_info.value.code == "invalid_request"


def test_create_career_rejects_role_from_another_position(db_conn):
    with pytest.raises(ApiError) as exc_info:
        _create(db_conn, position="Defans", role="firsatci_forvet", seed=1)
    assert exc_info.value.code == "invalid_request"


def test_create_career_rejects_unknown_nationality(db_conn):
    with pytest.raises(ApiError) as exc_info:
        _create(db_conn, nationality="DE", seed=1)
    assert exc_info.value.code == "invalid_request"


def test_create_career_rejects_blank_names(db_conn):
    for field in ("first_name", "last_name"):
        with pytest.raises(ApiError) as exc_info:
            _create(db_conn, **{field: "  ", "seed": 1})
        assert exc_info.value.code == "invalid_request"


def test_create_career_cup_round1_pairs_every_team_once(db_conn):
    career_id = _create(db_conn, seed=7)
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
    id_a = _create(db_conn, first_name="A", seed=99)
    db_conn.commit()
    id_b = _create(db_conn, first_name="B", seed=99)
    db_conn.commit()

    def first_round_pairs(career_id):
        rows = db_conn.execute(
            "SELECT home_team_id, away_team_id FROM fixture "
            "WHERE career_id = ? AND competition_id = 'c_lig2' AND round_no = 1 "
            "ORDER BY home_team_id",
            (career_id,),
        ).fetchall()
        return [(r["home_team_id"], r["away_team_id"]) for r in rows]

    def assigned_team(career_id):
        return db_conn.execute(
            "SELECT team_id FROM player WHERE career_id = ?", (career_id,)
        ).fetchone()["team_id"]

    assert first_round_pairs(id_a) == first_round_pairs(id_b)
    # §3's assignment draws from the same seeded rng, so it repeats too.
    assert assigned_team(id_a) == assigned_team(id_b)


def test_career_opens_a_week_before_the_first_league_round(db_conn):
    """§6.1 - the career starts on a preparation week, so a new player gets
    a full day loop before their first match instead of kicking off on day
    one."""
    career_id = _create(db_conn, seed=7)
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
    career_id = _create(db_conn, seed=7)
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
