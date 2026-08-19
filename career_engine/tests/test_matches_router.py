import pytest

from api import config
from tests.conftest import advance_to_match_day


@pytest.fixture
def created_career(api_client, mock_engine):
    """A career sitting ON its first match day — M1 only hands out today's
    fixture (§6.1), so every test here has to walk the preparation week
    first, exactly like the player does."""
    body = api_client.post(
        "/careers",
        json={"player_name": "Efe Kaan", "position": "Orta saha", "team_id": "t_ykz", "seed": 42},
    ).json()
    advance_to_match_day(api_client, body["career_id"])
    return body


def _stats(goals=0):
    return {
        "goals": goals, "shots": 10, "shots_on_target": 4, "corners": 5,
        "dangerous_attacks": 8, "total_attacks": 20, "yellow_cards": 1,
        "red_cards": 0, "penalties": 0, "penalty_goals": 0, "fouls": 6,
        "substitutions": 2, "possession_ticks": 50,
    }


def _valid_result_body(fixture_id, home_goals=1, away_goals=0, condition=54):
    return {
        "match_id": "m_test_0001",
        "score": {"home": home_goals, "away": away_goals},
        "stats": {"home": _stats(home_goals), "away": _stats(away_goals)},
        "final_possession_home": 53.1,
        "final_condition": condition,
        "interventions": [
            {"minute": 63, "action_key": "finish_power", "outcome_key": "great"},
            {"minute": 78, "action_key": "long_shot", "outcome_key": "bad"},
        ],
    }


# --- M1 ---------------------------------------------------------------

def test_get_next_match_returns_engine_payload(api_client, created_career):
    career_id = created_career["career_id"]
    resp = api_client.get(f"/careers/{career_id}/matches/next")
    assert resp.status_code == 200
    body = resp.json()

    assert body["fixture_id"]
    payload = body["engine_payload"]
    assert set(payload["teams"]["home"].keys()) == {"name", "mentality", "attack", "midfield", "defense", "goalkeeper"}
    assert payload["user_condition"] == config.STARTING_CONDITION
    assert "client_seed" in payload
    assert "stamina" not in str(payload)  # D39 — never in the team blocks


def test_get_next_match_is_refused_before_the_match_day(api_client, mock_engine):
    """§6.1 - a fresh career opens on a preparation week, so M1 has nothing
    to hand out yet and says how far off the match is."""
    career_id = api_client.post(
        "/careers",
        json={"player_name": "Efe Kaan", "position": "Orta saha", "team_id": "t_ykz", "seed": 42},
    ).json()["career_id"]

    resp = api_client.get(f"/careers/{career_id}/matches/next")
    assert resp.status_code == 409
    assert resp.json()["code"] == "not_match_day"
    assert "2026-08-08" in resp.json()["message"]
    assert "7 day(s)" in resp.json()["message"]


def test_get_next_match_is_refused_again_the_day_after_a_match(api_client, created_career, mock_engine):
    """The gate is what makes the week a week: having played today's match,
    the user can't immediately queue up the next one."""
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]
    api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=_valid_result_body(fixture_id))

    resp = api_client.get(f"/careers/{career_id}/matches/next")
    assert resp.status_code == 409
    assert resp.json()["code"] == "not_match_day"


def test_get_next_match_marks_in_progress_and_blocks_second_call(api_client, created_career):
    career_id = created_career["career_id"]
    first = api_client.get(f"/careers/{career_id}/matches/next")
    assert first.status_code == 200

    second = api_client.get(f"/careers/{career_id}/matches/next")
    assert second.status_code == 409
    assert second.json()["code"] == "match_in_progress"


# --- M2 -----------------------------------------------------------------

def test_post_result_applies_everything(api_client, created_career, mock_engine):
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    resp = api_client.post(
        f"/careers/{career_id}/matches/{fixture_id}/result",
        json=_valid_result_body(fixture_id),
    )
    assert resp.status_code == 200
    body = resp.json()

    assert body["fixture"]["status"] == "played"
    assert body["player_stat_delta"] == {"appearances": 1, "goals": 1, "minutes": 95}
    assert body["career_state"]["condition"] == 54
    kinds = {e["kind"] for e in body["ledger_entries"]}
    assert "appearance_bonus" in kinds
    assert "goal_bonus" in kinds
    assert len(body["news_created"]) == 1
    assert body["standing_delta"]["rank_before"] is not None
    # `other_results` is empty here because the day loop already ran that
    # day's other fixtures on arrival (§6.7 INV-12: everything up to the
    # world's today has been played). It only fills when a fixture of that
    # date is still scheduled — e.g. a cup tie drawn the same morning.
    assert body["other_results"] == []


def test_post_result_already_played_errors(api_client, created_career, mock_engine):
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]
    api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=_valid_result_body(fixture_id))

    resp = api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=_valid_result_body(fixture_id))
    assert resp.status_code == 409
    assert resp.json()["code"] == "fixture_already_played"


def test_post_result_rejects_incomplete_stats(api_client, created_career):
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    body = _valid_result_body(fixture_id)
    del body["stats"]["home"]["fouls"]  # only 12 keys now
    resp = api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=body)
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_match_result"


def test_post_result_rejects_score_stats_mismatch(api_client, created_career):
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    body = _valid_result_body(fixture_id, home_goals=2)
    body["score"]["home"] = 3  # now disagrees with stats.home.goals == 2
    resp = api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=body)
    assert resp.status_code == 422


def test_post_result_rejects_unknown_action_key(api_client, created_career):
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    body = _valid_result_body(fixture_id)
    body["interventions"][0]["action_key"] = "bicycle_kick"
    resp = api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=body)
    assert resp.status_code == 422


def test_post_result_rejects_wrong_outcome_for_schema(api_client, created_career):
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    body = _valid_result_body(fixture_id)
    body["interventions"][0]["outcome_key"] = "success"  # finish_power is graded, not binary
    resp = api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=body)
    assert resp.status_code == 422


def test_post_result_rejects_non_increasing_minutes(api_client, created_career):
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    body = _valid_result_body(fixture_id)
    body["interventions"][1]["minute"] = 60  # earlier than the first (63)
    resp = api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=body)
    assert resp.status_code == 422


def test_post_result_rejects_condition_above_pre_match(api_client, created_career):
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    body = _valid_result_body(fixture_id, condition=90)  # pre-match was 64
    resp = api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=body)
    assert resp.status_code == 422


def test_post_result_failure_changes_nothing(api_client, created_career):
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]
    before = api_client.get(f"/careers/{career_id}/player").json()["career_state"]

    body = _valid_result_body(fixture_id)
    body["interventions"][0]["action_key"] = "bicycle_kick"
    api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=body)

    after = api_client.get(f"/careers/{career_id}/player").json()["career_state"]
    assert before == after


# --- M3 -----------------------------------------------------------------

def test_abandon_reverts_and_allows_fresh_payload(api_client, created_career):
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    resp = api_client.post(f"/careers/{career_id}/matches/{fixture_id}/abandon")
    assert resp.status_code == 200
    assert resp.json()["fixture"]["status"] == "scheduled"

    again = api_client.get(f"/careers/{career_id}/matches/next")
    assert again.status_code == 200
    assert again.json()["fixture_id"] == fixture_id


def test_abandon_not_in_progress_errors(api_client, created_career):
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]
    api_client.post(f"/careers/{career_id}/matches/{fixture_id}/abandon")  # -> scheduled

    resp = api_client.post(f"/careers/{career_id}/matches/{fixture_id}/abandon")  # already scheduled
    assert resp.status_code == 409
    assert resp.json()["code"] == "fixture_not_in_progress"
