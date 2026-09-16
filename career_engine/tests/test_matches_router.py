import pytest

from api import config
from domain import onboarding
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


def test_get_next_match_carries_the_coach_instruction_outside_engine_payload(
    api_client, created_career,
):
    """§12.10 - CAREER_PAYLOAD's role is 'merkez_orta_saha', whose default
    instruction is 'tactical' (worlddata/positions.py). Motor rol kavramını
    bilmiyor, o yüzden `engine_payload`'ın dışında (`formation_id` ile aynı
    gerekçe)."""
    career_id = created_career["career_id"]
    body = api_client.get(f"/careers/{career_id}/matches/next").json()

    instruction = body["coach_instruction"]
    assert instruction["focus"] == "tactical"
    assert instruction["label"] == "Taktik"
    assert instruction["role_id"] == "merkez_orta_saha"
    assert instruction["role_name"] == "Merkez Orta Saha"
    assert instruction["position"] == "Orta saha"
    assert instruction["source"] == "role"
    assert "coach_instruction" not in str(body["engine_payload"])


def test_get_next_match_is_refused_before_the_match_day(api_client, mock_engine):
    """§6.1 - a fresh career opens on a preparation week, so M1 has nothing
    to hand out yet and says how far off the match is."""
    career_id = create_career(api_client)["career_id"]

    resp = api_client.get(f"/careers/{career_id}/matches/next")
    assert resp.status_code == 409
    assert resp.json()["code"] == "not_match_day"
    assert onboarding.FIRST_SEASON.league_starts_on.isoformat() in resp.json()["message"]
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


def _coach_delta_for(api_client, *, team_cards=(0, 0), user_cards=None, tactical_compliance=None):
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
    if tactical_compliance is not None:
        body["tactical_compliance"] = tactical_compliance

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


def test_tactical_compliance_bands_the_coach_delta(api_client, mock_engine):
    """§12.10 - three bands, not a continuous curve (see
    domain.matches._compliance_term). Compared against a body that omits
    the field entirely, which is the "not measured" baseline (term 0),
    same as the 0.50-0.80 dead band."""
    unmeasured = _coach_delta_for(api_client)
    high = _coach_delta_for(api_client, tactical_compliance=0.95)
    mid = _coach_delta_for(api_client, tactical_compliance=0.65)
    low = _coach_delta_for(api_client, tactical_compliance=0.20)

    assert high == unmeasured + 1
    assert mid == unmeasured
    assert low == unmeasured - 2


def test_post_result_rejects_tactical_compliance_out_of_range(api_client, created_career, mock_engine):
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    body = _valid_result_body(fixture_id)
    body["tactical_compliance"] = 1.5
    resp = api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=body)
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_match_result"


def test_post_result_rejects_tactical_compliance_as_a_bool(api_client, created_career, mock_engine):
    """bool subclasses int in Python; a bare (int, float) isinstance check
    would let `True` slip through and then pass 0.0 <= True <= 1.0 too."""
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    body = _valid_result_body(fixture_id)
    body["tactical_compliance"] = True
    resp = api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=body)
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_match_result"


def test_post_result_rejects_tactical_compliance_with_zero_minutes(api_client, created_career, mock_engine):
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    body = _valid_result_body(fixture_id)
    body["started"] = False
    body["minutes_played"] = 0
    body["tactical_compliance"] = 0.9
    resp = api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=body)
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_match_result"


def test_tactical_fit_moves_a_quarter_of_the_way_and_is_reported(api_client, created_career, mock_engine):
    """§12.10 - `tactical_fit` starts at 0.5 (relationships.py's CoachTraits
    default) and was dead data until now. A single match pulls it a quarter
    of the way toward the reported ratio, never all the way."""
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    before = api_client.get(f"/careers/{career_id}/relationships/coach").json()
    assert before["traits"]["tactical_fit"] == 0.5

    body = _valid_result_body(fixture_id)
    body["tactical_compliance"] = 1.0
    resp = api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=body)
    assert resp.status_code == 200, resp.text

    trait_changes = resp.json()["trait_changes"]
    fit = next(c for c in trait_changes if c["key"] == "tactical_fit")
    assert fit["before"] == 0.5
    assert fit["after"] == pytest.approx(0.625)  # 0.5 + 0.25 * (1.0 - 0.5)

    after = api_client.get(f"/careers/{career_id}/relationships/coach").json()
    assert after["traits"]["tactical_fit"] == pytest.approx(0.625)


def test_tactical_fit_is_untouched_when_compliance_is_not_reported(api_client, created_career, mock_engine):
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    resp = api_client.post(
        f"/careers/{career_id}/matches/{fixture_id}/result",
        json=_valid_result_body(fixture_id),
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["trait_changes"] == []

    after = api_client.get(f"/careers/{career_id}/relationships/coach").json()
    assert after["traits"]["tactical_fit"] == 0.5


def test_tactical_fit_accumulates_across_two_matches_without_exceeding_one(
    api_client, created_career, mock_engine,
):
    """A running pull, not a one-shot delta: two fully-compliant matches in
    a row should move `tactical_fit` twice (0.5 -> 0.625 -> 0.71875), each
    time a quarter of the remaining distance to 1.0 - never all the way,
    and never past 1.0 (relationships.TRAIT_BOUNDS clamps regardless)."""
    career_id = created_career["career_id"]
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    body = _valid_result_body(fixture_id)
    body["tactical_compliance"] = 1.0
    resp = api_client.post(f"/careers/{career_id}/matches/{fixture_id}/result", json=body)
    assert resp.status_code == 200, resp.text

    advance_to_match_day(api_client, career_id)
    next_fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]
    body2 = _valid_result_body(next_fixture_id)
    body2["tactical_compliance"] = 1.0
    resp2 = api_client.post(
        f"/careers/{career_id}/matches/{next_fixture_id}/result", json=body2,
    )
    assert resp2.status_code == 200, resp2.text

    fit = next(c for c in resp2.json()["trait_changes"] if c["key"] == "tactical_fit")
    assert fit["before"] == pytest.approx(0.625)
    assert fit["after"] == pytest.approx(0.71875)
    assert fit["after"] <= 1.0


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
