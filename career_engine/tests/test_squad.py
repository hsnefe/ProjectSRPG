"""§12.2 — first eleven / bench / out."""
import pytest

from domain import squad
from tests.conftest import advance_to_match_day, create_career


# `db_conn` is a different database from the one `api_client` talks to (that
# one is a per-test tmp file, monkeypatched into config.DB_PATH). These open
# the client's database the way conftest's grant_money/set_attribute do.

def _api_db():
    from api import config
    from db.connection import get_connection
    return get_connection(config.DB_PATH)


def _fixture_row(career_id, fixture_id):
    conn = _api_db()
    try:
        return conn.execute(
            "SELECT * FROM fixture WHERE career_id = ? AND fixture_id = ?",
            (career_id, fixture_id),
        ).fetchone()
    finally:
        conn.close()


def _drop_from_squad(career_id, fixture_id):
    """Puts the fixture back to 'scheduled' with the user left out — the one
    state M1 cannot produce on demand, since the roll is seeded."""
    conn = _api_db()
    try:
        conn.execute(
            "UPDATE fixture SET status = 'scheduled', user_squad_status = 'out' "
            "WHERE career_id = ? AND fixture_id = ?",
            (career_id, fixture_id),
        )
        conn.commit()
    finally:
        conn.close()


def _season_stat(career_id):
    conn = _api_db()
    try:
        return conn.execute(
            "SELECT appearances, starts, minutes FROM player_season_stat "
            "WHERE career_id = ? AND player_id = 'p_user'",
            (career_id,),
        ).fetchone()
    finally:
        conn.close()


# --- the pure part: thresholds without a database -------------------------

def test_a_fresh_career_starts():
    """condition 100, trust 50, coach 70 — the opening of a career must look
    the way it always did. Losing your place is something that happens to
    you, not a coin flip on day one."""
    score = squad.selection_score(condition=100, trust=50, coach_score=70, jitter=0)
    assert score == pytest.approx(76.5)
    assert squad.classify(score) == squad.FIRST_ELEVEN


def test_a_broken_relationship_costs_the_shirt():
    benched = squad.selection_score(condition=60, trust=20, coach_score=25, jitter=0)
    assert squad.classify(benched) == squad.BENCH

    dropped = squad.selection_score(condition=30, trust=5, coach_score=5, jitter=0)
    assert squad.classify(dropped) == squad.OUT


def test_condition_leads_but_trust_is_not_decoration():
    """Two players the coach rates identically; the one he trusts starts."""
    trusted = squad.selection_score(condition=70, trust=90, coach_score=50, jitter=0)
    distrusted = squad.selection_score(condition=70, trust=10, coach_score=50, jitter=0)
    assert trusted - distrusted == pytest.approx(squad.TRUST_WEIGHT * 80)
    assert squad.classify(trusted) == squad.FIRST_ELEVEN
    assert squad.classify(distrusted) == squad.BENCH


def test_bench_counts_as_playing_but_out_does_not():
    assert squad.plays(squad.FIRST_ELEVEN)
    assert squad.plays(squad.BENCH)
    assert not squad.plays(squad.OUT)


# --- the stored part ------------------------------------------------------

def test_status_is_decided_once_and_sticks(api_client, mock_engine):
    """Two callers have to agree about the same match (T1's event list and
    T3's gate), so the decision is written the first time anything asks."""
    career_id = create_career(api_client)["career_id"]
    advance_to_match_day(api_client, career_id)

    first = api_client.get(f"/careers/{career_id}/matches/next")
    assert first.status_code == 200
    fixture_id = first.json()["fixture_id"]
    status = first.json()["squad_status"]
    assert status in (squad.FIRST_ELEVEN, squad.BENCH)

    assert _fixture_row(career_id, fixture_id)["user_squad_status"] == status


def test_a_fresh_career_is_in_the_first_eleven(api_client, mock_engine):
    career_id = create_career(api_client)["career_id"]
    advance_to_match_day(api_client, career_id)

    body = api_client.get(f"/careers/{career_id}/matches/next").json()
    assert body["squad_status"] == squad.FIRST_ELEVEN


def test_being_left_out_hands_the_fixture_to_the_background_sim(api_client, mock_engine):
    """A fixture the user is out of must not stay 'scheduled' forever — the
    match-day gate would then lock the career and the season could never
    finish."""
    career_id = create_career(api_client)["career_id"]
    advance_to_match_day(api_client, career_id)
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    _drop_from_squad(career_id, fixture_id)

    # M1 refuses: it is not the user's match to play.
    resp = api_client.get(f"/careers/{career_id}/matches/next")
    assert resp.status_code == 409
    assert resp.json()["code"] == "not_match_day"

    # And advance is not blocked by it.
    advanced = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})
    assert advanced.status_code == 200

    assert _fixture_row(career_id, fixture_id)["status"] == "played"


def test_day_endpoint_reports_no_match_when_left_out(api_client, mock_engine):
    career_id = create_career(api_client)["career_id"]
    advance_to_match_day(api_client, career_id)
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]
    _drop_from_squad(career_id, fixture_id)

    day = api_client.get(f"/careers/{career_id}/day").json()
    assert day["is_match_day"] is False
    assert not [e for e in day["events"] if e["kind"] == "match"]


# --- M2: starts and minutes are no longer the same number -----------------

def _result_body(fixture_id, **extra):
    from tests.test_matches_router import _valid_result_body
    body = _valid_result_body(fixture_id)
    body["interventions"] = []
    body.update(extra)
    return body


def test_a_substitute_records_an_appearance_but_not_a_start(api_client, mock_engine):
    career_id = create_career(api_client)["career_id"]
    advance_to_match_day(api_client, career_id)
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    resp = api_client.post(
        f"/careers/{career_id}/matches/{fixture_id}/result",
        json=_result_body(fixture_id, started=False, minutes_played=22),
    )
    assert resp.status_code == 200
    delta = resp.json()["player_stat_delta"]
    assert delta == {
        "appearances": 1, "starts": 0, "goals": 0, "assists": 0, "minutes": 22,
    }

    row = _season_stat(career_id)
    assert (row["appearances"], row["starts"], row["minutes"]) == (1, 0, 22)


def test_being_substituted_off_is_a_start_with_fewer_minutes(api_client, mock_engine):
    career_id = create_career(api_client)["career_id"]
    advance_to_match_day(api_client, career_id)
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    body = api_client.post(
        f"/careers/{career_id}/matches/{fixture_id}/result",
        json=_result_body(fixture_id, started=True, minutes_played=61),
    ).json()

    assert body["player_stat_delta"]["starts"] == 1
    assert body["player_stat_delta"]["minutes"] == 61


def test_an_unused_substitute_earns_no_appearance_bonus(api_client, mock_engine):
    """The clause pays for appearing. Ninety minutes on the bench is not
    what it is for."""
    career_id = create_career(api_client)["career_id"]
    advance_to_match_day(api_client, career_id)
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    body = api_client.post(
        f"/careers/{career_id}/matches/{fixture_id}/result",
        json=_result_body(fixture_id, started=False, minutes_played=0),
    ).json()

    kinds = {e["kind"] for e in body["ledger_entries"]}
    assert "appearance_bonus" not in kinds
    assert body["player_stat_delta"]["minutes"] == 0


def test_a_body_without_squad_fields_still_means_a_full_start(api_client, mock_engine):
    """Backwards compatibility: the pre-§12.2 shape is a start of 95."""
    career_id = create_career(api_client)["career_id"]
    advance_to_match_day(api_client, career_id)
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    body = api_client.post(
        f"/careers/{career_id}/matches/{fixture_id}/result",
        json=_result_body(fixture_id),
    ).json()

    assert body["player_stat_delta"]["starts"] == 1
    assert body["player_stat_delta"]["minutes"] == 95


@pytest.mark.parametrize(
    "extra",
    [
        {"started": True, "minutes_played": 0},   # a starter who played nothing
        {"minutes_played": 96},                   # past full time
        {"minutes_played": -1},
        {"started": "yes"},
    ],
)
def test_impossible_participation_is_refused(api_client, mock_engine, extra):
    career_id = create_career(api_client)["career_id"]
    advance_to_match_day(api_client, career_id)
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    resp = api_client.post(
        f"/careers/{career_id}/matches/{fixture_id}/result",
        json=_result_body(fixture_id, **extra),
    )
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_match_result"
