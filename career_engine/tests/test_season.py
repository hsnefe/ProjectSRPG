"""§11.1/§11.2 — the derived season calendar and the phase that comes out of it."""
import datetime as _dt

import pytest

from domain import onboarding, scheduling, season
from tests.conftest import create_career


# --- §11.1's own worked example -------------------------------------------

def test_the_26_27_calendar_matches_the_contract():
    """§11.1 prints this table; if the derivation drifts from it, one of the
    two is wrong and this test says which."""
    c = season.calendar_for(2026)

    assert c.season_id == "26/27"
    assert c.league_starts_on.isoformat() == "2026-08-29"   # last Saturday of August
    assert c.starts_on.isoformat() == "2026-08-22"          # minus a preparation week
    assert c.cup_starts_on.isoformat() == "2026-09-02"      # the Wednesday after
    assert c.winter_break_from.isoformat() == "2027-01-01"
    assert c.winter_break_to.isoformat() == "2027-01-31"
    assert c.ends_on.isoformat() == "2027-06-05"            # first Saturday of June


@pytest.mark.parametrize("year", range(2024, 2041))
def test_every_season_opens_and_closes_on_a_saturday(year):
    c = season.calendar_for(year)
    assert c.league_starts_on.weekday() == season.SATURDAY
    assert c.starts_on.weekday() == season.SATURDAY
    assert c.ends_on.weekday() == season.SATURDAY
    assert c.cup_starts_on.weekday() == 2  # Wednesday, never a league day
    assert c.league_starts_on.month == 8
    assert c.ends_on.month == 6


@pytest.mark.parametrize("year", range(2024, 2041))
def test_seasons_never_overlap(year):
    this_one = season.calendar_for(year)
    next_one = season.calendar_for(year + 1)
    assert this_one.ends_on < next_one.starts_on


def test_season_id_derives_from_the_opening_year():
    assert season.calendar_for(2026).season_id == "26/27"
    assert season.calendar_for(2029).season_id == "29/30"
    # The century roll is the interesting one.
    assert season.calendar_for(2099).season_id == "99/00"


# --- INV-33: no league round lands in the winter break --------------------

@pytest.mark.parametrize("team_count", [18, 14])
def test_no_league_round_falls_in_the_winter_break(team_count):
    c = season.calendar_for(2026)
    ids = [f"t{i}" for i in range(team_count)]
    rounds, fixtures = scheduling.generate_league_season(
        "car_x", c.season_id, "c_lig1", ids, c.league_starts_on.isoformat(),
        skip_from=c.winter_break_from.isoformat(),
        skip_to=c.winter_break_to.isoformat(),
    )

    assert len(rounds) == 2 * (team_count - 1)
    for r in rounds:
        assert not (
            c.winter_break_from.isoformat() <= r["scheduled_on"] <= c.winter_break_to.isoformat()
        ), f"round {r['round_no']} landed in the break"
    for f in fixtures:
        assert not (
            c.winter_break_from.isoformat() <= f["kickoff_at"][:10] <= c.winter_break_to.isoformat()
        )


def test_the_whole_league_season_fits_before_it_ends():
    """§11.1 checks this by hand for 18 teams: r34 on 22 May, before 5 June."""
    c = season.calendar_for(2026)
    ids = [f"t{i}" for i in range(18)]
    rounds, _ = scheduling.generate_league_season(
        "car_x", c.season_id, "c_lig1", ids, c.league_starts_on.isoformat(),
        skip_from=c.winter_break_from.isoformat(),
        skip_to=c.winter_break_to.isoformat(),
    )
    assert rounds[0]["scheduled_on"] == "2026-08-29"
    assert rounds[17]["scheduled_on"] == "2026-12-26"   # r18, last before the break
    assert rounds[18]["scheduled_on"] == "2027-02-06"   # r19, first after it
    assert rounds[-1]["scheduled_on"] == "2027-05-22"
    assert rounds[-1]["scheduled_on"] < c.ends_on.isoformat()


def test_rounds_stay_weekly_across_the_break():
    """The shift is carried, not recomputed per round: every gap outside the
    break is still exactly a week, so the season does not drift onto a
    Tuesday after the holiday."""
    c = season.calendar_for(2026)
    rounds, _ = scheduling.generate_league_season(
        "car_x", c.season_id, "c_lig1", [f"t{i}" for i in range(18)],
        c.league_starts_on.isoformat(),
        skip_from=c.winter_break_from.isoformat(),
        skip_to=c.winter_break_to.isoformat(),
    )
    for r in rounds:
        assert _dt.date.fromisoformat(r["scheduled_on"]).weekday() == season.SATURDAY


# --- §11.2: the phase -----------------------------------------------------

def _phase_on(api_client, career_id, on_date):
    from api import config
    from db.connection import get_connection

    conn = get_connection(config.DB_PATH)
    try:
        return season.derive_phase(conn, career_id, on_date)
    finally:
        conn.close()


def test_phase_walks_the_season(api_client, mock_engine):
    career_id = create_career(api_client)["career_id"]
    c = onboarding.FIRST_SEASON

    assert _phase_on(api_client, career_id, c.starts_on.isoformat()) == season.PRE_SEASON
    assert _phase_on(api_client, career_id, "2026-08-28") == season.PRE_SEASON
    assert _phase_on(api_client, career_id, c.league_starts_on.isoformat()) == season.FIRST_HALF
    assert _phase_on(api_client, career_id, "2026-12-26") == season.FIRST_HALF
    assert _phase_on(api_client, career_id, "2027-01-01") == season.WINTER_BREAK
    assert _phase_on(api_client, career_id, "2027-01-31") == season.WINTER_BREAK
    assert _phase_on(api_client, career_id, "2027-02-01") == season.SECOND_HALF
    assert _phase_on(api_client, career_id, "2027-05-22") == season.SECOND_HALF


def test_past_the_last_season_is_season_end_not_summer(api_client, mock_engine):
    """§11.2's steps 2 and 3. With no season standing ahead, the career waits
    at season end — no separate flag needed to say the rollover is due."""
    career_id = create_career(api_client)["career_id"]
    after = _dt.date.fromisoformat(onboarding.SEASON_ENDS_ON) + _dt.timedelta(days=10)
    assert _phase_on(api_client, career_id, after.isoformat()) == season.SEASON_END


def test_career_state_carries_the_phase(api_client, mock_engine):
    """§11.8 — added in fetch_career_state, so it reaches every endpoint
    that returns the block at once (D28/INV-18)."""
    career_id = create_career(api_client)["career_id"]
    state = api_client.get(f"/careers/{career_id}/day").json()["career_state"]
    assert state["season_phase"] == season.PRE_SEASON

    advanced = api_client.post(
        f"/careers/{career_id}/advance", json={"to": "next_event"}
    ).json()
    assert advanced["career_state"]["season_phase"] in season.PHASES


def test_transfer_window_is_only_the_two_holiday_phases():
    assert season.transfer_window(season.WINTER_BREAK) == "winter"
    assert season.transfer_window(season.SUMMER_TRANSFER_WINDOW) == "summer"
    for phase in (season.PRE_SEASON, season.FIRST_HALF, season.SECOND_HALF, season.SEASON_END):
        assert season.transfer_window(phase) is None


def test_advance_stops_at_the_phase_change(api_client, mock_engine):
    """§11.8 — `season_phase_change` is a stopper, so `advance` parks itself
    at the boundary instead of running through it."""
    career_id = create_career(api_client)["career_id"]
    day = api_client.get(f"/careers/{career_id}/day").json()

    # Day one of a career IS a phase change: the day before it belongs to no
    # season while one stands ahead, which §11.2 step 2 reads as the summer
    # window. Pre-season starting is exactly the transition out of it.
    change = next(e for e in day["events"] if e["kind"] == "season_phase_change")
    assert change["ref_id"] == season.PRE_SEASON

    body = api_client.post(
        f"/careers/{career_id}/advance", json={"to": "next_event"}
    ).json()
    assert body["stop_reason"] in ("match", "season_phase_change")
