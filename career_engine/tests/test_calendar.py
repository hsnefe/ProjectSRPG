"""§5.3 W5 - the calendar endpoint and domain/calendar.py."""
import datetime as _dt

import pytest

from api import config
from domain import calendar as calendar_domain
from tests.conftest import new_career, play_users_match


@pytest.fixture
def career(api_client):
    career_id, team_id = new_career(api_client)
    return career_id, team_id


def marks_on(body, date):
    day = next((d for d in body["days"] if d["date"] == date), None)
    return day["marks"] if day else []


def kinds_on(body, date):
    return {m["kind"] for m in marks_on(body, date)}


# --- month_bounds ---------------------------------------------------------

@pytest.mark.parametrize("date,expected", [
    ("2026-08-19", ("2026-08-01", "2026-08-31")),
    ("2027-02-14", ("2027-02-01", "2027-02-28")),   # short month
    ("2028-02-01", ("2028-02-01", "2028-02-29")),   # leap year
    ("2026-12-31", ("2026-12-01", "2026-12-31")),   # year boundary
])
def test_month_bounds(date, expected):
    assert calendar_domain.month_bounds(date) == expected


# --- W5 -------------------------------------------------------------------

def test_the_default_range_is_the_month_the_career_is_in(api_client, career):
    career_id, _ = career
    body = api_client.get(f"/careers/{career_id}/calendar").json()

    assert body["today"] == "2026-08-01"
    assert body["from"] == "2026-08-01"
    assert body["to"] == "2026-08-31"
    assert body["season"] == {
        "season_id": "25/26", "starts_on": "2026-08-01", "ends_on": "2027-05-31",
    }


def test_only_days_with_something_on_them_are_returned(api_client, career):
    """A 31-day month sends the handful of days that carry a mark; FE draws
    the empty grid from from/to, which it needs anyway for the offsets."""
    career_id, _ = career
    body = api_client.get(f"/careers/{career_id}/calendar").json()

    assert len(body["days"]) < 31
    assert all(d["marks"] for d in body["days"])
    assert [d["date"] for d in body["days"]] == sorted(d["date"] for d in body["days"])


def test_every_wage_day_in_range_is_marked(api_client, career):
    """Computed from config.WAGE_WEEKDAY — the same constant §6.5 pays on,
    so the grid and the ledger cannot disagree about payday."""
    career_id, _ = career
    body = api_client.get(f"/careers/{career_id}/calendar").json()

    wage_days = {d["date"] for d in body["days"] if "wage" in kinds_on(body, d["date"])}
    expected = set()
    day = _dt.date.fromisoformat(body["from"])
    last = _dt.date.fromisoformat(body["to"])
    while day <= last:
        if day.weekday() == config.WAGE_WEEKDAY:
            expected.add(day.isoformat())
        day += _dt.timedelta(days=1)

    assert wage_days == expected
    assert len(expected) >= 4


def test_the_users_own_fixtures_are_marked_with_both_sides(api_client, career):
    """League round 1 is the Saturday a week after the season opens
    (onboarding.LEAGUE_STARTS_ON), and the mark carries both TeamRefs — the
    colours a grid paints the day with ride inside them."""
    career_id, team_id = career
    body = api_client.get(f"/careers/{career_id}/calendar").json()

    match_marks = [m for d in body["days"] for m in d["marks"] if m["kind"] == "match"]
    assert match_marks, "the opening month must contain at least one fixture"

    for mark in match_marks:
        assert mark["is_user_match"] is True
        assert team_id in (mark["home"]["team_id"], mark["away"]["team_id"])
        assert "color_primary" in mark["home"]
        assert mark["competition"]["name"]
        assert mark["status"] == "scheduled"
        assert mark["score"] is None


def test_a_played_fixture_carries_its_score(api_client, career, mock_engine):
    career_id, _ = career
    api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"})
    # §6.1 D57 - the match day fixture must be played (M1 -> M2) before it
    # shows up as 'played'; advancing without playing it no longer does this.
    play_users_match(api_client, career_id, home_goals=1, away_goals=1)

    body = api_client.get(f"/careers/{career_id}/calendar").json()
    played = [
        m for d in body["days"] for m in d["marks"]
        if m["kind"] == "match" and m["status"] == "played"
    ]
    assert played
    assert played[0]["score"] == {"home": 1, "away": 1}


def test_an_undrawn_cup_round_is_on_the_grid_before_anyone_knows_the_opponent(
    api_client, career
):
    """Rounds are scheduled before they are drawn, which is exactly why they
    need their own mark: there is no fixture to derive one from yet."""
    career_id, _ = career
    body = api_client.get(f"/careers/{career_id}/calendar?from=2026-08-01&to=2026-09-30").json()

    cup = [m for d in body["days"] for m in d["marks"] if m["kind"] == "cup_round"]
    assert cup
    assert all(m["drawn"] is False for m in cup)
    assert all(m["stage"] for m in cup)


def test_the_season_end_only_shows_up_on_its_own_page(api_client, career):
    career_id, _ = career
    august = api_client.get(f"/careers/{career_id}/calendar").json()
    assert not any(
        m["kind"] == "season_end" for d in august["days"] for m in d["marks"]
    )
    assert "season_start" in kinds_on(august, "2026-08-01")

    may = api_client.get(f"/careers/{career_id}/calendar?from=2027-05-01&to=2027-05-31").json()
    assert "season_end" in kinds_on(may, "2027-05-31")


def test_the_contract_expiry_is_marked_on_its_page(api_client, career):
    career_id, _ = career
    contract = api_client.get(f"/careers/{career_id}/player/contract").json()
    expires_at = contract["expires_at"]
    first, last = calendar_domain.month_bounds(expires_at)

    body = api_client.get(f"/careers/{career_id}/calendar?from={first}&to={last}").json()
    assert "contract_expiry" in kinds_on(body, expires_at)


def test_an_over_long_range_is_refused(api_client, career):
    career_id, _ = career
    resp = api_client.get(f"/careers/{career_id}/calendar?from=2026-08-01&to=2027-05-31")
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_request"


def test_a_backwards_range_is_refused(api_client, career):
    career_id, _ = career
    resp = api_client.get(f"/careers/{career_id}/calendar?from=2026-09-01&to=2026-08-01")
    assert resp.status_code == 422


def test_a_malformed_date_is_refused(api_client, career):
    career_id, _ = career
    resp = api_client.get(f"/careers/{career_id}/calendar?from=agustos&to=2026-08-31")
    assert resp.status_code == 422


def test_an_unknown_career_is_a_404(api_client):
    resp = api_client.get("/careers/car_nope/calendar")
    assert resp.status_code == 404
    assert resp.json()["code"] == "career_not_found"
