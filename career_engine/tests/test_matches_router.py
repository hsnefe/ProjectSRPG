import pytest

from api import config
from worlddata.formations import FORMATION_IDS
from tests.conftest import advance_to_match_day, create_career


@pytest.fixture
def created_career(api_client, mock_engine):
    """A career sitting ON its first match day — M1 only hands out today's
    fixture (§6.1), so every test here has to walk the preparation week
    first, exactly like the player does."""
    body = create_career(api_client)
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


def test_get_next_match_names_the_user_teams_formation(api_client, created_career):
    """Diziliş bir kariyer kavramı: yanıtta var, motora giden gövdede yok."""
    career_id = created_career["career_id"]
    body = api_client.get(f"/careers/{career_id}/matches/next").json()

    assert body["formation_id"] in FORMATION_IDS
    assert "formation" not in str(body["engine_payload"])


def test_get_next_match_is_refused_before_the_match_day(api_client, mock_engine):
    """§6.1 - a fresh career opens on a preparation week, so M1 has nothing
    to hand out yet and says how far off the match is."""
    career_id = create_career(api_client)["career_id"]

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
    assert body["player_stat_delta"] == {
        "appearances": 1, "starts": 1, "goals": 1, "assists": 0, "minutes": 95,
    }
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


def test_post_result_accepts_asist_outcome_for_graded4_action(api_client, created_career, mock_engine):
    """Regression test: a stale catalog used to reject any 'asist' outcome
    with a 422, discarding the whole match result. finish_power is
    graded4 (great/asist/good/bad) since match_engine v1.4."""
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    body = _valid_result_body(fixture_id)
    body["interventions"][0]["outcome_key"] = "asist"
    resp = api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=body)
    assert resp.status_code == 200


def test_post_result_credits_counter_attack_and_penalty_win_goals(api_client, created_career, mock_engine):
    """Both action_keys were silently uncredited before the catalog fix -
    counter_attack wasn't in the old minigame-action set at all, and
    penalty_win's best outcome ('success') was never mapped to a goal."""
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    body = _valid_result_body(fixture_id, home_goals=2, away_goals=0)
    body["interventions"] = [
        {"minute": 20, "action_key": "counter_attack", "outcome_key": "great"},
        {"minute": 70, "action_key": "penalty_win", "outcome_key": "success"},
    ]
    resp = api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=body)
    assert resp.status_code == 200
    assert resp.json()["player_stat_delta"]["goals"] == 2


def test_post_result_credits_assist_not_goal(api_client, created_career, mock_engine):
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    body = _valid_result_body(fixture_id)
    body["interventions"] = [
        {"minute": 63, "action_key": "finish_power", "outcome_key": "asist"},
    ]
    resp = api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=body)
    assert resp.status_code == 200
    delta = resp.json()["player_stat_delta"]
    assert delta["assists"] == 1
    assert delta["goals"] == 0


def test_post_result_includes_relationship_changes(api_client, created_career, mock_engine):
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    resp = api_client.post(
        f"/careers/{career_id}/matches/{fixture_id}/result",
        json=_valid_result_body(fixture_id),
    )
    assert resp.status_code == 200
    changes = resp.json()["relationship_changes"]
    assert [c["relationship_id"] for c in changes] == ["coach", "team", "fans", "media"]
    for c in changes:
        assert -5 <= c["delta"] <= 5
        assert c["after"] == c["before"] + c["delta"]


def _coach_delta_for(api_client, *, team_cards=(0, 0), user_cards=None):
    """Posts one won match and returns the coach delta it produced. Each
    call needs its own career because M2 may only be posted once per
    fixture (INV-6)."""
    career_id = create_career(api_client)["career_id"]
    advance_to_match_day(api_client, career_id)
    nxt = api_client.get(f"/careers/{career_id}/matches/next").json()
    side, fixture_id = nxt["user_side"], nxt["fixture_id"]

    body = _valid_result_body(
        fixture_id,
        home_goals=2 if side == "home" else 0,
        away_goals=0 if side == "home" else 2,
    )
    body["interventions"] = []
    yellow, red = team_cards
    body["stats"][side]["yellow_cards"] = yellow
    body["stats"][side]["red_cards"] = red
    if user_cards is not None:
        body["user_cards"] = user_cards

    resp = api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=body)
    assert resp.status_code == 200, resp.text
    return next(
        c for c in resp.json()["relationship_changes"] if c["relationship_id"] == "coach"
    )["delta"]


def test_teammate_cards_do_not_change_coach_delta(api_client, mock_engine):
    """A team-mate's sending-off lives in `stats[user_side]` - the whole
    team's block - not in the user's own discipline. M2 used to read it as
    if it were the player's, so a clean match cost coach -2 / team -1 /
    media -2 because somebody else walked, and the team's third yellow
    (routine) fired the booking penalty nearly every game."""
    clean = _coach_delta_for(api_client, team_cards=(0, 0))
    teammates_booked = _coach_delta_for(api_client, team_cards=(3, 1))

    assert teammates_booked == clean


def test_user_own_red_card_lowers_coach_delta(api_client, mock_engine):
    """The other half of the split: the player's OWN card still costs."""
    clean = _coach_delta_for(api_client, user_cards={"yellow": 0, "red": 0})
    sent_off = _coach_delta_for(api_client, user_cards={"yellow": 0, "red": 1})

    assert sent_off == clean - 2


def test_post_result_rejects_malformed_user_cards(api_client, created_career, mock_engine):
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    body = _valid_result_body(fixture_id)
    body["user_cards"] = {"yellow": 0, "red": 3}  # a player cannot be sent off twice
    resp = api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=body)
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_match_result"


def test_post_result_relationship_deltas_react_to_result(api_client, mock_engine):
    """fans should swing positive on a win and negative on a loss -
    a coarse but real behavioral check, not just a shape assertion."""
    win_id = create_career(api_client)["career_id"]
    advance_to_match_day(api_client, win_id)
    win_next = api_client.get(f"/careers/{win_id}/matches/next").json()
    win_side = win_next["user_side"]
    win_fixture_id = win_next["fixture_id"]
    win_body = _valid_result_body(
        win_fixture_id,
        home_goals=2 if win_side == "home" else 0,
        away_goals=0 if win_side == "home" else 2,
    )
    win_body["interventions"] = []
    win_resp = api_client.post(f"/careers/{win_id}/matches/{win_fixture_id}/result", json=win_body)
    assert win_resp.status_code == 200
    win_fans = next(c for c in win_resp.json()["relationship_changes"] if c["relationship_id"] == "fans")

    loss_id = create_career(api_client)["career_id"]
    advance_to_match_day(api_client, loss_id)
    loss_next = api_client.get(f"/careers/{loss_id}/matches/next").json()
    loss_side = loss_next["user_side"]
    loss_fixture_id = loss_next["fixture_id"]
    loss_body = _valid_result_body(
        loss_fixture_id,
        home_goals=0 if loss_side == "home" else 2,
        away_goals=2 if loss_side == "home" else 0,
    )
    loss_body["interventions"] = []
    loss_resp = api_client.post(f"/careers/{loss_id}/matches/{loss_fixture_id}/result", json=loss_body)
    assert loss_resp.status_code == 200
    loss_fans = next(c for c in loss_resp.json()["relationship_changes"] if c["relationship_id"] == "fans")

    assert win_fans["delta"] > 0
    assert loss_fans["delta"] < 0


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

    # Anything above the pre-match condition (config.STARTING_CONDITION) is
    # rejected — +1 is enough to prove the boundary.
    body = _valid_result_body(fixture_id, condition=config.STARTING_CONDITION + 1)
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
