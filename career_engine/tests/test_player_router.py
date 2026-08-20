import pytest

from api import config
from api.config import ATTRIBUTE_KEYS
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
    assert body["weekly_wage"] == 3500
    assert body["appearance_bonus"] == 500
    assert body["goal_bonus"] == 1000
    assert body["release_clause"] == 250000
    assert body["days_until_expiry"] > 0
