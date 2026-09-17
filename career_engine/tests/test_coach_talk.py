"""§12.1 M4 — the pre-match conversation with the coach."""
import pytest

from tests.conftest import advance_to_match_day, create_career, new_career
from worlddata.positions import (
    ROLES, instruction_for_role, position_group_for_role, role_belongs_to_position,
    roles_for_position,
)


@pytest.fixture
def match_day_career(api_client, mock_engine):
    """A career sitting ON its first match day — M4 is pinned to the
    fixture's own day, so every test here walks the preparation week first."""
    body = create_career(api_client)
    career_id = body["career_id"]
    advance_to_match_day(api_client, career_id)
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]
    return career_id, fixture_id


def _coach(api_client, career_id) -> dict:
    return api_client.get(f"/careers/{career_id}/relationships/coach").json()


def _talk(api_client, career_id, fixture_id, topic, value=None):
    body = {"topic": topic}
    if value is not None:
        body["value"] = value
    return api_client.post(f"/careers/{career_id}/matches/{fixture_id}/coach-talk", json=body)


# --- trust: the field that was dead until now -----------------------------

def test_accepting_the_philosophy_raises_trust_and_score(api_client, match_day_career):
    career_id, fixture_id = match_day_career
    before = _coach(api_client, career_id)
    assert before["traits"]["trust"] == 50.0  # the seeded default

    resp = _talk(api_client, career_id, fixture_id, "philosophy_accept")
    assert resp.status_code == 200, resp.text
    body = resp.json()

    trust = next(c for c in body["trait_changes"] if c["key"] == "trust")
    assert trust["before"] == 50.0
    assert trust["after"] == 56.0
    assert body["relationship_changes"][0]["delta"] == 2
    assert body["granted"] is None  # not a request topic

    after = _coach(api_client, career_id)
    assert after["traits"]["trust"] == 56.0
    assert after["score"] == before["score"] + 2


def test_rejecting_the_philosophy_costs_trust_and_condition(api_client, match_day_career):
    career_id, fixture_id = match_day_career
    condition_before = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["condition"]

    body = _talk(api_client, career_id, fixture_id, "philosophy_reject").json()

    trust = next(c for c in body["trait_changes"] if c["key"] == "trust")
    assert trust["after"] == 42.0
    assert body["relationship_changes"][0]["delta"] == -3
    assert body["condition_after"] == condition_before - 2


def test_trust_is_clamped_and_reports_the_applied_delta(db_conn, career_id, seeded_relationship):
    """apply_trait_delta reports the delta it actually applied, not the one
    it was asked for — the same honesty rule apply_delta follows for the
    score. Driven at the domain level: walking trust to 100 through the API
    would need twenty match days and would be testing the calendar."""
    from domain import relationships

    relationship_id = seeded_relationship

    relationships.apply_trait_delta(db_conn, career_id, relationship_id, trust=500.0)
    assert relationships.get_traits(db_conn, career_id, relationship_id)["trust"] == 100.0

    changes = relationships.apply_trait_delta(db_conn, career_id, relationship_id, trust=10.0)
    assert changes[0]["before"] == 100.0
    assert changes[0]["after"] == 100.0
    assert changes[0]["delta"] == 0.0

    relationships.apply_trait_delta(db_conn, career_id, relationship_id, trust=-500.0)
    assert relationships.get_traits(db_conn, career_id, relationship_id)["trust"] == 0.0


def test_apply_trait_delta_rejects_unknown_and_non_numeric_traits(db_conn, career_id, seeded_relationship):
    from api.errors import ApiError
    from domain import relationships

    relationship_id = seeded_relationship

    with pytest.raises(ApiError):
        relationships.apply_trait_delta(db_conn, career_id, relationship_id, nonesuch=1)
    with pytest.raises(ApiError):
        relationships.apply_trait_delta(db_conn, career_id, relationship_id, hobbies=1)


# --- requests -------------------------------------------------------------

def test_role_request_resolves_the_same_way_every_time(api_client, match_day_career):
    """The roll is seeded on (career, fixture, topic) so INV-7 holds — and
    so a refusal cannot be re-rolled by retrying."""
    career_id, fixture_id = match_day_career
    # The hub (C3), not P1: only the hub echoes `role`.
    player = api_client.get(f"/careers/{career_id}").json()["player"]
    other = next(
        r for r in roles_for_position(player["position"])
        if r["role_id"] != player["role"]
    )

    body = _talk(api_client, career_id, fixture_id, "request_role", other["role_id"]).json()
    assert body["granted"] in (True, False)

    if body["granted"]:
        assert body["player"]["role"] == other["role_id"]
        assert api_client.get(f"/careers/{career_id}").json()["player"]["role"] == other["role_id"]
        # Getting your way spends capital.
        assert body["trait_changes"][0]["delta"] == -5.0
    else:
        assert body["player"] is None
        assert body["trait_changes"][0]["delta"] == -2.0
        assert body["relationship_changes"][0]["delta"] == -2


def test_position_request_carries_the_role_with_it(api_client, match_day_career):
    """Roles belong to exactly one position, so a granted position change
    would orphan the role. It moves to the new position's first role and
    the response says so."""
    career_id, fixture_id = match_day_career
    player = api_client.get(f"/careers/{career_id}/player").json()
    target = next(p for p in ("Defans", "Orta saha", "Forvet") if p != player["position"])

    body = _talk(api_client, career_id, fixture_id, "request_position", target).json()

    if body["granted"]:
        assert body["player"]["position"] == target
        assert role_belongs_to_position(body["player"]["role"], target)


def _api_db():
    """A different database from the one `api_client` talks to (a per-test
    tmp file, monkeypatched into config.DB_PATH) - `test_squad.py`'s own
    idiom for reaching in beneath the API."""
    from api import config
    from db.connection import get_connection
    return get_connection(config.DB_PATH)


def _frozen_instruction(career_id, fixture_id):
    """`fixture.user_match_instruction` straight from the row - SQL NULL if
    nothing has frozen it yet (§12.10 migration note)."""
    conn = _api_db()
    try:
        return conn.execute(
            "SELECT user_match_instruction FROM fixture WHERE career_id = ? AND fixture_id = ?",
            (career_id, fixture_id),
        ).fetchone()["user_match_instruction"]
    finally:
        conn.close()


def test_instruction_request_resolves_the_same_way_every_time(api_client, match_day_career):
    """Same idiom as the role/position requests (INV-7). `match_day_career`
    already called M1 once, so a second one would 409 `match_in_progress` -
    the current instruction is read from the frozen row instead (the same
    reason `test_role_request_resolves_the_same_way_every_time` reads the
    hub rather than P1)."""
    career_id, fixture_id = match_day_career
    current_focus = _frozen_instruction(career_id, fixture_id)
    other = next(v for v in ("attack", "defend", "tactical", "any") if v != current_focus)

    body = _talk(api_client, career_id, fixture_id, "request_instruction", other).json()
    assert body["granted"] in (True, False)

    if body["granted"]:
        assert body["coach_instruction"]["focus"] == (None if other == "any" else other)
        assert body["player"] is None
        assert body["trait_changes"][0]["delta"] == -5.0
        assert _frozen_instruction(career_id, fixture_id) == other
    else:
        assert body["coach_instruction"] is None
        assert body["trait_changes"][0]["delta"] == -2.0
        assert body["relationship_changes"][0]["delta"] == -2
        assert _frozen_instruction(career_id, fixture_id) == current_focus  # unchanged


def test_instruction_request_for_the_current_value_is_refused(api_client, match_day_career):
    career_id, fixture_id = match_day_career
    current_focus = _frozen_instruction(career_id, fixture_id)

    resp = _talk(api_client, career_id, fixture_id, "request_instruction", current_focus)
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_request"


def test_instruction_request_rejects_an_unknown_value(api_client, match_day_career):
    career_id, fixture_id = match_day_career
    resp = _talk(api_client, career_id, fixture_id, "request_instruction", "farketmez")
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_request"


def test_a_refused_instruction_request_leaves_no_frozen_default_behind(
    api_client, mock_engine,
):
    """§12.10 / INV-4 - the regression `peek` exists to prevent. M4 does not
    require M1 to have run first (nothing gates it on that), so this reaches
    the fixture through T1 (`/day`'s match-kind event) instead - unlike
    `match_day_career`, that does not freeze the instruction, which is the
    point: the validation gate must read the would-be default (via `peek`)
    without writing it, or a refused request would freeze a default as a
    side effect it was never granted.

    Retried across a handful of seeds because a fresh career's low starting
    trust/score (50/70) usually but not always refuses the first request
    (INV-7 makes each seed's own outcome deterministic, not the sweep's)."""
    for seed in range(1, 6):
        career_id, _team_id = new_career(api_client, seed=seed)
        advance_to_match_day(api_client, career_id)
        events = api_client.get(f"/careers/{career_id}/day").json()["events"]
        fixture_id = next(e["ref_id"] for e in events if e["kind"] == "match")

        assert _frozen_instruction(career_id, fixture_id) is None  # M1 never ran

        role = api_client.get(f"/careers/{career_id}").json()["player"]["role"]
        current_focus = instruction_for_role(role)
        other = next(v for v in ("attack", "defend", "tactical", "any") if v != current_focus)
        before_budget = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["day_budget"]

        body = _talk(api_client, career_id, fixture_id, "request_instruction", other).json()
        if body["granted"]:
            continue  # this seed doesn't exercise the refused branch

        after_budget = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["day_budget"]
        assert after_budget["time"] == before_budget["time"] - 25
        assert after_budget["energy"] == before_budget["energy"] - 3
        assert _frozen_instruction(career_id, fixture_id) is None  # peek() didn't freeze it
        return

    pytest.fail("no seed in range(1, 6) produced a refused request_instruction")


def test_a_granted_role_request_re_derives_the_instruction(api_client, mock_engine):
    """§12.10 - agreeing to move you to a role and still expecting the old
    role's instruction would be a contradiction the coach created himself.

    Swept across seeds for the same reason as the refused-request test
    above: a fixed career/fixture makes `_roll` deterministic (INV-7), so
    without a sweep this test would either always or never exercise the
    granted branch it exists to prove."""
    for seed in range(1, 6):
        career_id, _team_id = new_career(api_client, seed=seed)
        advance_to_match_day(api_client, career_id)
        events = api_client.get(f"/careers/{career_id}/day").json()["events"]
        fixture_id = next(e["ref_id"] for e in events if e["kind"] == "match")

        player = api_client.get(f"/careers/{career_id}").json()["player"]
        other = next(
            r for r in roles_for_position(player["position"])
            if r["role_id"] != player["role"]
            and r["instruction"] != instruction_for_role(player["role"])
        )

        body = _talk(api_client, career_id, fixture_id, "request_role", other["role_id"]).json()
        if not body["granted"]:
            continue  # this seed doesn't exercise the granted branch

        expected = instruction_for_role(other["role_id"])
        assert body["coach_instruction"]["focus"] == (None if expected == "any" else expected)
        assert _frozen_instruction(career_id, fixture_id) == expected
        return

    pytest.fail("no seed in range(1, 6) produced a granted request_role")


def test_role_from_another_position_is_refused(api_client, match_day_career):
    career_id, fixture_id = match_day_career
    player = api_client.get(f"/careers/{career_id}/player").json()
    foreign = next(r for r in ROLES if r["position"] != player["position"])

    resp = _talk(api_client, career_id, fixture_id, "request_role", foreign["role_id"])
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_request"


def test_request_without_a_value_is_refused(api_client, match_day_career):
    career_id, fixture_id = match_day_career
    resp = _talk(api_client, career_id, fixture_id, "request_role")
    assert resp.status_code == 422


def test_non_request_topic_rejects_a_value(api_client, match_day_career):
    career_id, fixture_id = match_day_career
    resp = _talk(api_client, career_id, fixture_id, "style_accept", "stoper")
    assert resp.status_code == 422


# --- gates ----------------------------------------------------------------

def test_one_conversation_per_match(api_client, match_day_career):
    career_id, fixture_id = match_day_career
    assert _talk(api_client, career_id, fixture_id, "style_accept").status_code == 200

    resp = _talk(api_client, career_id, fixture_id, "philosophy_accept")
    assert resp.status_code == 409
    assert resp.json()["code"] == "coach_talk_already_done"


def test_talking_before_match_day_is_refused(api_client, mock_engine):
    """A fresh career sits a week before its first fixture."""
    career_id = create_career(api_client)["career_id"]
    fixture_id = api_client.get(
        f"/careers/{career_id}/fixtures"
    ).json()["fixtures"][0]["fixture_id"]

    resp = _talk(api_client, career_id, fixture_id, "style_accept")
    assert resp.status_code == 409
    assert resp.json()["code"] == "not_match_day"


def test_unknown_fixture_is_404(api_client, match_day_career):
    career_id, _ = match_day_career
    resp = _talk(api_client, career_id, "f_nope", "style_accept")
    assert resp.status_code == 404
    assert resp.json()["code"] == "fixture_not_found"


def test_unknown_topic_is_rejected(api_client, match_day_career):
    career_id, fixture_id = match_day_career
    resp = api_client.post(
        f"/careers/{career_id}/matches/{fixture_id}/coach-talk",
        json={"topic": "insult_him"},
    )
    assert resp.status_code == 422


def test_talk_spends_the_day_budget(api_client, match_day_career):
    career_id, fixture_id = match_day_career
    before = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["day_budget"]

    body = _talk(api_client, career_id, fixture_id, "philosophy_accept").json()
    after = body["career_state"]["day_budget"]

    assert after["time"] == before["time"] - 20
    assert after["energy"] == before["energy"] - 2


# -- §12.14 position_group --------------------------------------------------

def test_granted_talk_reports_the_position_group(api_client, match_day_career):
    """§12.14 - M1's copy goes stale the moment a granted request moves the
    role, and the FE forwards this value to the engine's /start. So every
    non-null `coach_instruction` carries it, whether the role moved or not."""
    career_id, fixture_id = match_day_career
    player = api_client.get(f"/careers/{career_id}").json()["player"]
    expected = position_group_for_role(player["role"])
    assert expected is not None, "fixture career has no role"

    current_focus = _frozen_instruction(career_id, fixture_id)
    other = next(v for v in ("attack", "defend", "tactical", "any") if v != current_focus)
    body = _talk(api_client, career_id, fixture_id, "request_instruction", other).json()

    if body["granted"]:
        # request_instruction never touches the role, so the group is unchanged.
        assert body["coach_instruction"]["position_group"] == expected
    else:
        assert body["coach_instruction"] is None


def test_granted_role_change_moves_the_position_group_with_it(
    api_client, match_day_career, monkeypatch,
):
    """A granted request_role can cross group boundaries (merkez_orta_saha is
    MC, ofansif_orta_saha is AMC) and the reported group must follow the new
    role, not the old one.

    The roll is forced rather than branched on: the seeded refusal is already
    covered by `test_role_request_resolves_the_same_way_every_time`, and the
    thing under test here only exists on the granted path - skipping it half
    the time would make the coverage depend on a career id."""
    from domain import coach_talk

    monkeypatch.setattr(coach_talk, "_roll", lambda *a, **k: 0.0)

    career_id, fixture_id = match_day_career
    player = api_client.get(f"/careers/{career_id}").json()["player"]
    before = position_group_for_role(player["role"])
    other = next(
        r for r in ROLES
        if r["position"] == player["position"] and position_group_for_role(r["role_id"]) != before
    )

    body = _talk(api_client, career_id, fixture_id, "request_role", other["role_id"]).json()
    assert body["granted"] is True
    assert body["player"]["role"] == other["role_id"]

    after = position_group_for_role(other["role_id"])
    assert after != before
    assert body["coach_instruction"]["position_group"] == after
