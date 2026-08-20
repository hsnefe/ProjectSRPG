"""§3 - finding a country's bottom league and picking a club in it."""
import random

import pytest

from api.errors import ApiError
from domain import onboarding, team_assignment
from worlddata.positions import POSITIONS, ROLES, roles_for_position
from worlddata.teams import TIER1_TEAMS, TIER2_TEAMS

CAREER_KWARGS = {
    "first_name": "Efe", "last_name": "Kaan", "nationality": "TR",
    "position": "Orta saha", "role": "merkez_orta_saha", "target_team_id": "t_gal",
}


@pytest.fixture
def seeded_world(db_conn):
    """A career whose world tables are populated, which is all the assignment
    functions read."""
    career_id = onboarding.create_career(db_conn, seed=3, **CAREER_KWARGS)
    db_conn.commit()
    return career_id


def test_lowest_league_is_the_highest_tier_number(db_conn, seeded_world):
    """tier counts downward — 1 is the top flight — so the bottom league is
    the largest tier, found by query rather than by knowing 'c_lig2'."""
    assert team_assignment.find_lowest_league(db_conn, seeded_world, "TR") == "c_lig2"


def test_lowest_league_ignores_cups(db_conn, seeded_world):
    """The cup's tier is NULL and it isn't part of the pyramid."""
    assert team_assignment.find_lowest_league(db_conn, seeded_world, "TR") != "c_kupa"


def test_unknown_country_has_no_league(db_conn, seeded_world):
    assert team_assignment.find_lowest_league(db_conn, seeded_world, "DE") is None


def test_league_team_ids_returns_that_leagues_clubs(db_conn, seeded_world):
    ids = team_assignment.league_team_ids(db_conn, seeded_world, onboarding.SEASON_ID, "c_lig2")
    assert set(ids) == {t["team_id"] for t in TIER2_TEAMS}
    assert ids == sorted(ids)  # stable order keeps a seeded pick reproducible


def test_assignment_never_picks_a_top_flight_club(db_conn, seeded_world):
    tier1_ids = {t["team_id"] for t in TIER1_TEAMS}
    for seed in range(25):
        team_id = team_assignment.assign_starting_team(
            db_conn, seeded_world, onboarding.SEASON_ID, "TR", random.Random(seed)
        )
        assert team_id not in tier1_ids


def test_default_strategy_draws_from_the_weaker_half(db_conn, seeded_world):
    """"Uygun alt takımlar" — the division's stronger half is never assigned,
    so there is always somewhere to climb."""
    ids = team_assignment.league_team_ids(db_conn, seeded_world, onboarding.SEASON_ID, "c_lig2")
    ranked = sorted(ids, key=lambda t: (team_assignment._overall(db_conn, seeded_world, t), t))
    weaker_half = set(ranked[: len(ranked) // 2])

    picks = {
        team_assignment.assign_starting_team(
            db_conn, seeded_world, onboarding.SEASON_ID, "TR", random.Random(seed)
        )
        for seed in range(40)
    }
    assert picks <= weaker_half
    assert len(picks) > 1  # it really does vary, it isn't pinned to one club


def test_strategy_is_swappable(db_conn, seeded_world):
    ids = team_assignment.league_team_ids(db_conn, seeded_world, onboarding.SEASON_ID, "c_lig2")
    weakest = min(ids, key=lambda t: (team_assignment._overall(db_conn, seeded_world, t), t))

    picked = team_assignment.assign_starting_team(
        db_conn, seeded_world, onboarding.SEASON_ID, "TR", random.Random(1),
        strategy="weakest_club",
    )
    assert picked == weakest


def test_unknown_strategy_errors(db_conn, seeded_world):
    with pytest.raises(ApiError) as exc_info:
        team_assignment.assign_starting_team(
            db_conn, seeded_world, onboarding.SEASON_ID, "TR", random.Random(1),
            strategy="coin_flip",
        )
    assert exc_info.value.code == "invalid_request"


def test_country_without_a_league_errors(db_conn, seeded_world):
    with pytest.raises(ApiError) as exc_info:
        team_assignment.assign_starting_team(
            db_conn, seeded_world, onboarding.SEASON_ID, "DE", random.Random(1)
        )
    assert exc_info.value.code == "invalid_request"


# --- position/role catalog -------------------------------------------------

def test_every_role_belongs_to_a_listed_position():
    assert {r["position"] for r in ROLES} == set(POSITIONS)


def test_goalkeeper_has_no_roles_in_v1():
    assert "Kaleci" not in POSITIONS
    assert roles_for_position("Kaleci") == []


def test_every_position_has_at_least_one_role():
    assert all(roles_for_position(p) for p in POSITIONS)
