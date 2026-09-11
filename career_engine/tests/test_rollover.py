"""§11.5/§11.6 — S1 rollover and S2 summary.

Playing a real 34-round season through `advance` + M2 would take several
hundred HTTP calls per test. These drive the world to the boundary directly
instead — the fixtures are marked played with real scores, which is exactly
the state a played season leaves behind, and the rollover reads nothing else.
"""
import datetime as _dt
import random

import pytest

from api import config
from db.connection import get_connection
from domain import onboarding, season
from tests.conftest import create_career
from worlddata.competitions import BIRINCI_LIG, COMPETITION_RULES, SUPER_LIG


def _db():
    return get_connection(config.DB_PATH)


def _finish_the_season(career_id, season_id=None, seed=7):
    """Plays every fixture of the season with a reproducible scoreline, then
    parks game_date past the end. Leaves the career exactly where a real
    season leaves it: nothing scheduled, nothing in progress."""
    conn = _db()
    try:
        season_id = season_id or conn.execute(
            "SELECT season_id FROM season WHERE career_id = ? ORDER BY starts_on DESC LIMIT 1",
            (career_id,),
        ).fetchone()["season_id"]
        rows = conn.execute(
            "SELECT fixture_id FROM fixture WHERE career_id = ? AND season_id = ?",
            (career_id, season_id),
        ).fetchall()
        rng = random.Random(seed)
        for row in rows:
            conn.execute(
                "UPDATE fixture SET status = 'played', home_score = ?, away_score = ? "
                "WHERE career_id = ? AND fixture_id = ?",
                (rng.randint(0, 4), rng.randint(0, 3), career_id, row["fixture_id"]),
            )
        ends_on = conn.execute(
            "SELECT ends_on FROM season WHERE career_id = ? AND season_id = ?",
            (career_id, season_id),
        ).fetchone()["ends_on"]
        after = (_dt.date.fromisoformat(ends_on) + _dt.timedelta(days=1)).isoformat()
        conn.execute(
            "UPDATE career_state SET game_date = ? WHERE career_id = ?", (after, career_id)
        )
        conn.commit()
        return season_id
    finally:
        conn.close()


def _entries(career_id, season_id, competition_id):
    conn = _db()
    try:
        return {
            r["team_id"] for r in conn.execute(
                "SELECT team_id FROM competition_entry WHERE career_id = ? "
                "AND season_id = ? AND competition_id = ?",
                (career_id, season_id, competition_id),
            ).fetchall()
        }
    finally:
        conn.close()


@pytest.fixture
def finished_career(api_client, mock_engine):
    career_id = create_career(api_client)["career_id"]
    season_id = _finish_the_season(career_id)
    return career_id, season_id


# --- preconditions --------------------------------------------------------

def test_rollover_is_refused_mid_season(api_client, mock_engine):
    career_id = create_career(api_client)["career_id"]
    resp = api_client.post(f"/careers/{career_id}/season/rollover")
    assert resp.status_code == 409
    assert resp.json()["code"] == "season_not_finished"


def test_rollover_is_refused_with_one_fixture_left(api_client, mock_engine):
    """INV-13 — every competition must finish before promotion is decided."""
    career_id = create_career(api_client)["career_id"]
    season_id = _finish_the_season(career_id)
    conn = _db()
    try:
        left = conn.execute(
            "SELECT fixture_id FROM fixture WHERE career_id = ? AND season_id = ? LIMIT 1",
            (career_id, season_id),
        ).fetchone()["fixture_id"]
        conn.execute(
            "UPDATE fixture SET status = 'scheduled' WHERE career_id = ? AND fixture_id = ?",
            (career_id, left),
        )
        conn.commit()
    finally:
        conn.close()

    resp = api_client.post(f"/careers/{career_id}/season/rollover")
    assert resp.status_code == 409
    assert resp.json()["code"] == "season_not_finished"
    assert "1 fixture" in resp.json()["message"]


def test_advance_asks_for_the_rollover_at_the_boundary(api_client, finished_career):
    career_id, _ = finished_career
    resp = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})
    assert resp.status_code == 409
    assert resp.json()["code"] == "season_rollover_required"


# --- the rollover itself --------------------------------------------------

def test_rollover_opens_the_next_season(api_client, finished_career):
    career_id, previous = finished_career

    resp = api_client.post(f"/careers/{career_id}/season/rollover")
    assert resp.status_code == 200, resp.text
    body = resp.json()

    assert body["previous_season_id"] == previous
    assert body["new_season_id"] == season.calendar_for(
        onboarding.FIRST_SEASON_OPENING_YEAR + 1
    ).season_id
    # D47 — the rollover does not move the clock; the summer is played.
    assert body["career_state"]["season_phase"] == season.SUMMER_TRANSFER_WINDOW
    assert body["news_created"]


def test_the_new_season_has_a_full_fixture_list(api_client, finished_career):
    career_id, previous = finished_career
    new_season = api_client.post(
        f"/careers/{career_id}/season/rollover"
    ).json()["new_season_id"]

    conn = _db()
    try:
        counts = {
            r["competition_id"]: r["n"] for r in conn.execute(
                "SELECT competition_id, COUNT(*) AS n FROM fixture "
                "WHERE career_id = ? AND season_id = ? GROUP BY competition_id",
                (career_id, new_season),
            ).fetchall()
        }
        assert counts[SUPER_LIG] == 18 * 17      # 34 rounds x 9 fixtures
        assert counts[BIRINCI_LIG] == 14 * 13    # 26 rounds x 7 fixtures
        assert counts["c_kupa"] == 16            # round 1, drawn immediately

        # INV-33 holds for the new season too.
        break_row = conn.execute(
            "SELECT winter_break_from, winter_break_to FROM season "
            "WHERE career_id = ? AND season_id = ?",
            (career_id, new_season),
        ).fetchone()
        clash = conn.execute(
            "SELECT COUNT(*) AS n FROM fixture f "
            "JOIN competition c ON c.career_id = f.career_id "
            "AND c.competition_id = f.competition_id "
            "WHERE f.career_id = ? AND f.season_id = ? AND c.kind = 'league' "
            "AND substr(f.kickoff_at, 1, 10) BETWEEN ? AND ?",
            (career_id, new_season, break_row["winter_break_from"], break_row["winter_break_to"]),
        ).fetchone()["n"]
        assert clash == 0
    finally:
        conn.close()


def test_promotion_and_relegation_swap_exactly_three(api_client, finished_career):
    career_id, previous = finished_career
    new_season = api_client.post(
        f"/careers/{career_id}/season/rollover"
    ).json()["new_season_id"]

    old_top = _entries(career_id, previous, SUPER_LIG)
    old_second = _entries(career_id, previous, BIRINCI_LIG)
    new_top = _entries(career_id, new_season, SUPER_LIG)
    new_second = _entries(career_id, new_season, BIRINCI_LIG)

    promoted = COMPETITION_RULES[BIRINCI_LIG]["promote_count"]
    assert len(new_top - old_top) == promoted
    assert len(old_top - new_top) == promoted
    assert new_top - old_top <= old_second
    assert old_top - new_top <= new_second


def test_league_sizes_never_change(api_client, finished_career):
    """INV-34 — promotions equal relegations, so the rosters stay 18 and 14."""
    career_id, previous = finished_career
    new_season = api_client.post(
        f"/careers/{career_id}/season/rollover"
    ).json()["new_season_id"]

    assert len(_entries(career_id, new_season, SUPER_LIG)) == 18
    assert len(_entries(career_id, new_season, BIRINCI_LIG)) == 14


def test_every_team_lands_in_exactly_one_league(api_client, finished_career):
    """INV-37 — the complement of INV-14."""
    career_id, _ = finished_career
    new_season = api_client.post(
        f"/careers/{career_id}/season/rollover"
    ).json()["new_season_id"]

    top = _entries(career_id, new_season, SUPER_LIG)
    second = _entries(career_id, new_season, BIRINCI_LIG)
    assert not (top & second)
    assert len(top | second) == 32


def test_the_champion_is_recorded_with_its_continental_place(api_client, finished_career):
    career_id, previous = finished_career
    api_client.post(f"/careers/{career_id}/season/rollover")

    conn = _db()
    try:
        champion = conn.execute(
            "SELECT * FROM season_result WHERE career_id = ? AND season_id = ? "
            "AND competition_id = ? AND is_champion = 1",
            (career_id, previous, SUPER_LIG),
        ).fetchone()
        assert champion["final_rank"] == 1
        # Süper Lig's placeholder score of 45 buys two places (§11.4).
        assert champion["continental"] == 1

        continental = conn.execute(
            "SELECT COUNT(*) AS n FROM season_result WHERE career_id = ? AND season_id = ? "
            "AND competition_id = ? AND continental = 1",
            (career_id, previous, SUPER_LIG),
        ).fetchone()["n"]
        assert continental == 2

        # 1. Lig scores 5 — nobody goes.
        none_from_second = conn.execute(
            "SELECT COUNT(*) AS n FROM season_result WHERE career_id = ? AND season_id = ? "
            "AND competition_id = ? AND continental = 1",
            (career_id, previous, BIRINCI_LIG),
        ).fetchone()["n"]
        assert none_from_second == 0
    finally:
        conn.close()


def test_the_new_fixture_list_is_announced_as_news(api_client, finished_career):
    """P6 — the player finds out through the news layer, not by trawling the
    calendar."""
    career_id, _ = finished_career
    body = api_client.post(f"/careers/{career_id}/season/rollover").json()

    news = api_client.get(f"/careers/{career_id}/news").json()["items"]
    titles = [n["title"] for n in news]
    assert any("fikstürü çekildi" in t for t in titles)
    assert len(body["news_created"]) >= 2  # champion, promotion table, fixtures


def test_the_career_can_advance_again_after_the_rollover(api_client, finished_career):
    """The whole point: the season boundary stops being a wall."""
    career_id, _ = finished_career
    api_client.post(f"/careers/{career_id}/season/rollover")

    resp = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})
    assert resp.status_code == 200
    assert resp.json()["days_advanced"] == 1


def test_rolling_over_twice_is_refused(api_client, finished_career):
    career_id, _ = finished_career
    assert api_client.post(f"/careers/{career_id}/season/rollover").status_code == 200

    again = api_client.post(f"/careers/{career_id}/season/rollover")
    assert again.status_code == 409
    assert again.json()["code"] == "season_not_finished"


def test_two_seasons_in_a_row(api_client, finished_career):
    """INV-7 across a boundary, and the cup's season-scoped queries under
    real conditions: season two's round 1 must not see season one's."""
    career_id, first = finished_career
    second = api_client.post(
        f"/careers/{career_id}/season/rollover"
    ).json()["new_season_id"]

    _finish_the_season(career_id, second, seed=11)
    third = api_client.post(f"/careers/{career_id}/season/rollover")
    assert third.status_code == 200, third.text
    assert third.json()["previous_season_id"] == second
    assert len(_entries(career_id, third.json()["new_season_id"], SUPER_LIG)) == 18


# --- S2 -------------------------------------------------------------------

def test_summary_reports_the_finished_season(api_client, finished_career):
    career_id, previous = finished_career
    api_client.post(f"/careers/{career_id}/season/rollover")

    body = api_client.get(f"/careers/{career_id}/season/summary").json()
    assert body["season_id"] == previous
    assert {lg["competition"]["competition_id"] for lg in body["leagues"]} == {
        SUPER_LIG, BIRINCI_LIG
    }
    # The cup has no table — same reason W2 answers no_standings for it.
    assert "c_kupa" not in {lg["competition"]["competition_id"] for lg in body["leagues"]}

    top = next(lg for lg in body["leagues"] if lg["competition"]["competition_id"] == SUPER_LIG)
    assert top["champion"] is not None
    assert len(top["rows"]) == 18
    assert top["rows"][0]["final_rank"] == 1
    assert "champion" in top["rows"][0]["outcomes"]
    assert top["rows"][0]["played"] == 34
    assert body["continental_slots"] == {SUPER_LIG: 2, BIRINCI_LIG: 0}


def test_summary_of_an_unfinished_season_is_refused(api_client, mock_engine):
    career_id = create_career(api_client)["career_id"]
    resp = api_client.get(f"/careers/{career_id}/season/summary")
    assert resp.status_code == 409
    assert resp.json()["code"] == "season_not_finished"


def test_summary_can_be_asked_for_a_named_season(api_client, finished_career):
    career_id, previous = finished_career
    api_client.post(f"/careers/{career_id}/season/rollover")

    body = api_client.get(
        f"/careers/{career_id}/season/summary", params={"season": previous}
    ).json()
    assert body["season_id"] == previous


def test_points_come_out_of_the_table_not_a_second_source(api_client, finished_career):
    """INV-2 — the standings are always derivable from `fixture`; the frozen
    result carries the verdict, not the numbers."""
    career_id, previous = finished_career
    api_client.post(f"/careers/{career_id}/season/rollover")

    summary = api_client.get(f"/careers/{career_id}/season/summary").json()
    top = next(lg for lg in summary["leagues"] if lg["competition"]["competition_id"] == SUPER_LIG)
    for row in top["rows"]:
        assert row["points"] == row["won"] * 3 + row["drawn"]
        assert row["played"] == row["won"] + row["drawn"] + row["lost"]
        assert row["goal_difference"] == row["goals_for"] - row["goals_against"]
