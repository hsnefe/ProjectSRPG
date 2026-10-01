import pytest

from api import config
from api.config import ATTRIBUTE_KEYS, TACTIC_KEYS
from tests.conftest import create_career


@pytest.fixture
def created_career(api_client):
    return create_career(api_client)


def test_get_player_returns_every_attribute(api_client, created_career):
    resp = api_client.get(f"/careers/{created_career['career_id']}/player")
    assert resp.status_code == 200
    body = resp.json()

    assert body["player_id"] == "p_user"
    assert body["name"] == "Efe Kaan"
    assert len(body["attributes"]) == len(ATTRIBUTE_KEYS)
    keys = {a["key"] for a in body["attributes"]}
    assert keys == set(ATTRIBUTE_KEYS)
    assert "tackling" in keys

    condition_attr = next(a for a in body["attributes"] if a["key"] == "condition")
    assert condition_attr["family"] == "saha"
    # INV-10: the attribute is career_state.condition's ceiling, so the two
    # start equal.
    assert condition_attr["value"] == float(config.STARTING_CONDITION)


def test_get_player_returns_every_tactic_untrained(api_client, created_career):
    # INV-55: a fresh career's tactics[] has exactly len(TACTIC_KEYS) rows,
    # every one at 0.0 — same "always N rows" shape as attributes[].
    body = api_client.get(f"/careers/{created_career['career_id']}/player").json()
    assert body["tactics"] == [{"key": key, "value": 0.0} for key in TACTIC_KEYS]


def test_get_player_fame_defaults_to_zero(api_client, created_career):
    body = api_client.get(f"/careers/{created_career['career_id']}/player").json()
    assert body["fame"] == [{"scope": "overall", "value": 0.0}]


def test_get_player_market_value_is_none_for_fresh_career(api_client, created_career):
    # AÇIK-8: no formula yet, and a brand-new career has no value_history
    # snapshot either — market_value should be null, not a fabricated number.
    body = api_client.get(f"/careers/{created_career['career_id']}/player").json()
    assert body["market_value"] is None


def test_get_player_404_for_unknown_career(api_client):
    resp = api_client.get("/careers/car_doesnotexist/player")
    assert resp.status_code == 404


def test_get_player_stats_empty_for_fresh_career(api_client, created_career):
    resp = api_client.get(f"/careers/{created_career['career_id']}/player/stats")
    assert resp.status_code == 200
    body = resp.json()
    assert body["rows"] == []
    assert body["value_history"] == []


def test_get_player_contract_matches_starting_values(api_client, created_career):
    resp = api_client.get(f"/careers/{created_career['career_id']}/player/contract")
    assert resp.status_code == 200
    body = resp.json()

    # §3 assigns the club, so the contract is with whatever it picked.
    assert body["team"]["team_id"] == created_career["player"]["team"]["team_id"]
    assert body["weekly_wage"] == config.STARTING_WEEKLY_WAGE
    assert body["appearance_bonus"] == config.STARTING_APPEARANCE_BONUS
    assert body["goal_bonus"] == config.STARTING_GOAL_BONUS
    assert body["release_clause"] == config.STARTING_RELEASE_CLAUSE
    assert body["days_until_expiry"] > 0


# --- D43: the derived level -----------------------------------------------

def test_get_player_ships_a_level_alongside_every_value(api_client, created_career):
    """FE tests `level >= requires[key]`, so P1 has to carry the derived
    number — otherwise FE would have to re-implement the scale (D43)."""
    from domain import attributes

    body = api_client.get(f"/careers/{created_career['career_id']}/player").json()
    for attr in body["attributes"]:
        assert attr["level"] == attributes.level(attr["value"])
        assert 0 <= attr["level"] <= 10


def test_get_player_levels_match_the_fresh_kişi_values(api_client, created_career):
    body = api_client.get(f"/careers/{created_career['career_id']}/player").json()
    levels = {a["key"]: a["level"] for a in body["attributes"]}
    for key in ("charisma", "empathy", "courage", "intelligence", "discipline"):
        assert levels[key] == 0   # a new career starts every social skill at 0


def test_get_player_level_follows_the_value_after_training(api_client, created_career):
    from tests.conftest import set_attribute

    career_id = created_career["career_id"]
    set_attribute(career_id, "courage", 59.9)
    body = api_client.get(f"/careers/{career_id}/player").json()
    assert next(a for a in body["attributes"] if a["key"] == "courage")["level"] == 5

    set_attribute(career_id, "courage", 60.0)
    body = api_client.get(f"/careers/{career_id}/player").json()
    assert next(a for a in body["attributes"] if a["key"] == "courage")["level"] == 6
