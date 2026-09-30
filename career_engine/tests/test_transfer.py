"""§11.7 — contracts, offers, renewals and moving club."""
import datetime as _dt

import pytest

from api import config
from db.connection import get_connection
from domain import contracts, onboarding, season
from tests.conftest import create_career
from tests.test_rollover import _db, _finish_the_season


@pytest.fixture
def summer_career(api_client, mock_engine):
    """A career sitting in the summer window with its contract run out —
    the state the whole section is about."""
    career_id = create_career(api_client)["career_id"]
    _finish_the_season(career_id)

    # Expire the opening contract with the season that just ended.
    conn = _db()
    try:
        ends_on = conn.execute(
            "SELECT ends_on FROM season WHERE career_id = ? ORDER BY starts_on DESC LIMIT 1",
            (career_id,),
        ).fetchone()["ends_on"]
        conn.execute(
            "UPDATE player_contract SET expires_at = ? WHERE career_id = ?",
            (ends_on, career_id),
        )
        conn.commit()
    finally:
        conn.close()

    api_client.post(f"/careers/{career_id}/season/rollover")
    return career_id


# --- D50/INV-35: contracts end on season boundaries -----------------------

def test_the_opening_contract_expires_on_a_season_boundary(api_client, mock_engine):
    """730 days from an August Saturday lands on an arbitrary Tuesday, which
    is neither of the two dates a contract may end on."""
    career_id = create_career(api_client)["career_id"]
    body = api_client.get(f"/careers/{career_id}/player/contract").json()

    final_season = season.calendar_for(
        onboarding.FIRST_SEASON_OPENING_YEAR + config.STARTING_CONTRACT_SEASONS - 1
    )
    assert body["expires_at"] == final_season.ends_on.isoformat()
    assert _dt.date.fromisoformat(body["expires_at"]).weekday() == season.SATURDAY


def test_days_until_expiry_counts_from_game_date(api_client, mock_engine):
    """It used to count from the wall clock, which is years off once a
    career has rolled over."""
    career_id = create_career(api_client)["career_id"]
    body = api_client.get(f"/careers/{career_id}/player/contract").json()

    expected = (
        _dt.date.fromisoformat(body["expires_at"])
        - _dt.date.fromisoformat(onboarding.SEASON_STARTS_ON)
    ).days
    assert body["days_until_expiry"] == expected


def test_expiry_is_always_a_season_end(api_client, mock_engine):
    career_id = create_career(api_client)["career_id"]
    conn = _db()
    try:
        for length in (1, 2, 3):
            expires = contracts.expiry_for(
                conn, career_id, onboarding.SEASON_STARTS_ON, length
            )
            assert expires == season.calendar_for(
                onboarding.FIRST_SEASON_OPENING_YEAR + length - 1
            ).ends_on.isoformat()
    finally:
        conn.close()


def test_an_expired_contract_stops_paying_wages(api_client, mock_engine):
    """The lookup ordered by signed_at and ignored expires_at, so an expired
    deal kept paying forever. Nothing could reach that before §11.7."""
    career_id = create_career(api_client)["career_id"]
    conn = _db()
    try:
        conn.execute(
            "UPDATE player_contract SET expires_at = '2026-08-20' WHERE career_id = ?",
            (career_id,),
        )
        conn.commit()
        assert contracts.is_free_agent(conn, career_id, onboarding.SEASON_STARTS_ON)
        assert contracts.active_contract(conn, career_id, onboarding.SEASON_STARTS_ON) is None
        # The record of it is still there, for "your deal ran out" to be sayable.
        assert contracts.latest_contract(conn, career_id) is not None
    finally:
        conn.close()

    # Walk to the first Monday; no wage entry should appear.
    for _ in range(9):
        resp = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})
        if resp.status_code != 200:
            break
        assert not [e for e in resp.json()["ledger_entries"] if e["kind"] == "wage"]


def test_a_free_agent_is_reported_as_one(api_client, mock_engine):
    career_id = create_career(api_client)["career_id"]
    conn = _db()
    try:
        conn.execute(
            "UPDATE player_contract SET expires_at = '2026-08-20' WHERE career_id = ?",
            (career_id,),
        )
        conn.commit()
    finally:
        conn.close()

    body = api_client.get(f"/careers/{career_id}/player/contract").json()
    assert body["status"] == "expired"

    day = api_client.get(f"/careers/{career_id}/day").json()
    assert any(e["kind"] == "contract_expired" for e in day["events"])


# --- the window -----------------------------------------------------------

def test_offers_are_empty_outside_a_window(api_client, mock_engine):
    """A closed window is a boring answer, not an error (§11.7)."""
    career_id = create_career(api_client)["career_id"]
    body = api_client.get(f"/careers/{career_id}/transfer/offers").json()

    assert body["window"] is None
    assert body["closes_on"] is None
    assert body["offers"] == []


def test_the_summer_window_opens_after_the_rollover(api_client, summer_career):
    body = api_client.get(f"/careers/{summer_career}/transfer/offers").json()

    assert body["window"] == "summer"
    assert body["closes_on"] is not None
    assert body["offers"]


def test_the_current_club_is_among_the_bidders(api_client, summer_career):
    """§11.7 — staying is a choice, so the club you are at has to make one
    of the offers."""
    body = api_client.get(f"/careers/{summer_career}/transfer/offers").json()
    renewals = [o for o in body["offers"] if o["is_renewal"]]
    assert len(renewals) == 1

    hub = api_client.get(f"/careers/{summer_career}").json()
    assert renewals[0]["team"]["team_id"] == hub["player"]["team"]["team_id"]


def test_offers_are_generated_once_per_window(api_client, summer_career):
    """A window is one round of interest, not a daily auction."""
    first = api_client.get(f"/careers/{summer_career}/transfer/offers").json()["offers"]
    second = api_client.get(f"/careers/{summer_career}/transfer/offers").json()["offers"]
    assert [o["offer_id"] for o in first] == [o["offer_id"] for o in second]


def test_every_offer_expires_on_a_season_boundary(api_client, summer_career):
    body = api_client.get(f"/careers/{summer_career}/transfer/offers").json()
    for offer in body["offers"]:
        assert _dt.date.fromisoformat(offer["expires_at"]).weekday() == season.SATURDAY
        assert offer["length_seasons"] in (2, 3)


# --- accepting ------------------------------------------------------------

def test_accepting_moves_the_player_and_writes_the_contract(api_client, summer_career):
    offers = api_client.get(f"/careers/{summer_career}/transfer/offers").json()["offers"]
    target = next(o for o in offers if not o["is_renewal"])

    resp = api_client.post(
        f"/careers/{summer_career}/transfer/offers/{target['offer_id']}/accept"
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()

    assert body["team"]["team_id"] == target["team"]["team_id"]
    assert body["contract"]["weekly_wage"] == target["weekly_wage"]
    assert body["contract"]["expires_at"] == target["expires_at"]

    hub = api_client.get(f"/careers/{summer_career}").json()
    assert hub["player"]["team"]["team_id"] == target["team"]["team_id"]

    contract = api_client.get(f"/careers/{summer_career}/player/contract").json()
    assert contract["status"] == "active"
    assert contract["team"]["team_id"] == target["team"]["team_id"]


def test_accepting_books_a_hotel_room(api_client, summer_career):
    """§14.4 D90 - a new city: the club puts the player up for a while."""
    offers = api_client.get(f"/careers/{summer_career}/transfer/offers").json()["offers"]
    target = next(o for o in offers if not o["is_renewal"])
    body = api_client.post(
        f"/careers/{summer_career}/transfer/offers/{target['offer_id']}/accept"
    ).json()

    assert body["residence_move"]["to"] == "res-hotel"
    housing = api_client.get(f"/careers/{summer_career}/housing").json()
    assert housing["active_residence_id"] == "res-hotel"


def test_accepting_resets_the_club_relationships(api_client, summer_career):
    """§13.1/D69 through the endpoint, not the domain function: S4's response
    is FE's only chance to learn the new names without re-fetching R1."""
    from api import config
    from worlddata.relationships import STARTING_SCORES

    before = {
        r["relationship_id"]: r
        for r in api_client.get(f"/careers/{summer_career}/relationships").json()["relationships"]
    }

    offers = api_client.get(f"/careers/{summer_career}/transfer/offers").json()["offers"]
    target = next(o for o in offers if not o["is_renewal"])
    body = api_client.post(
        f"/careers/{summer_career}/transfer/offers/{target['offer_id']}/accept"
    ).json()

    resets = {r["relationship_id"]: r for r in body["relationships_reset"]}
    assert set(resets) == set(config.CLUB_SCOPED_RELATIONSHIPS)
    for rid, reset in resets.items():
        assert reset["after"] == STARTING_SCORES[rid]
        assert reset["person_name"] and reset["contact_name"]

    after = {
        r["relationship_id"]: r
        for r in api_client.get(f"/careers/{summer_career}/relationships").json()["relationships"]
    }
    assert after["coach"]["person_name"] == resets["coach"]["person_name"]
    assert after["coach"]["traits"]["trust"] == 50.0      # §12.2's input, back to default
    # ...and the career-scoped side came along unchanged.
    assert after["media"]["person_name"] == before["media"]["person_name"]
    assert after["family"]["score"] == before["family"]["score"]


def test_accepting_one_offer_expires_the_rest(api_client, summer_career):
    """A club that has been turned down is not still waiting."""
    offers = api_client.get(f"/careers/{summer_career}/transfer/offers").json()["offers"]
    assert len(offers) > 1
    taken = offers[0]

    api_client.post(f"/careers/{summer_career}/transfer/offers/{taken['offer_id']}/accept")

    remaining = api_client.get(f"/careers/{summer_career}/transfer/offers").json()["offers"]
    assert all(o["offer_id"] != taken["offer_id"] for o in remaining)
    # And the ones that were open when it was taken are gone too.
    for other in offers[1:]:
        resp = api_client.post(
            f"/careers/{summer_career}/transfer/offers/{other['offer_id']}/accept"
        )
        assert resp.status_code == 409
        assert resp.json()["code"] == "offer_not_open"


def test_accepting_twice_is_refused(api_client, summer_career):
    offers = api_client.get(f"/careers/{summer_career}/transfer/offers").json()["offers"]
    offer_id = offers[0]["offer_id"]
    assert api_client.post(
        f"/careers/{summer_career}/transfer/offers/{offer_id}/accept"
    ).status_code == 200

    again = api_client.post(f"/careers/{summer_career}/transfer/offers/{offer_id}/accept")
    assert again.status_code == 409
    assert again.json()["code"] == "offer_not_open"


def test_an_unknown_offer_is_404(api_client, summer_career):
    resp = api_client.post(f"/careers/{summer_career}/transfer/offers/o_nope/accept")
    assert resp.status_code == 404
    assert resp.json()["code"] == "offer_not_found"


def test_accepting_outside_a_window_is_refused(api_client, summer_career):
    """The offer is real, the window is not."""
    offers = api_client.get(f"/careers/{summer_career}/transfer/offers").json()["offers"]
    offer_id = offers[0]["offer_id"]

    conn = _db()
    try:
        # Jump into the new season, where the window is shut.
        starts_on = conn.execute(
            "SELECT starts_on FROM season WHERE career_id = ? ORDER BY starts_on DESC LIMIT 1",
            (summer_career,),
        ).fetchone()["starts_on"]
        conn.execute(
            "UPDATE career_state SET game_date = ? WHERE career_id = ?",
            (starts_on, summer_career),
        )
        conn.commit()
    finally:
        conn.close()

    resp = api_client.post(f"/careers/{summer_career}/transfer/offers/{offer_id}/accept")
    assert resp.status_code == 409
    assert resp.json()["code"] == "no_transfer_window"


def test_declining_costs_nothing_and_leaves_the_rest(api_client, summer_career):
    offers = api_client.get(f"/careers/{summer_career}/transfer/offers").json()["offers"]
    dropped = offers[0]["offer_id"]

    resp = api_client.post(f"/careers/{summer_career}/transfer/offers/{dropped}/decline")
    assert resp.status_code == 200
    remaining = resp.json()["offers"]
    assert all(o["offer_id"] != dropped for o in remaining)
    assert len(remaining) == len(offers) - 1


# --- the renewal counter (§12.4) ------------------------------------------

def test_the_renewal_can_be_pushed_back_on_once(api_client, summer_career):
    offers = api_client.get(f"/careers/{summer_career}/transfer/offers").json()["offers"]
    renewal = next(o for o in offers if o["is_renewal"])
    before = renewal["weekly_wage"]

    resp = api_client.post(
        f"/careers/{summer_career}/transfer/offers/{renewal['offer_id']}/counter"
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["offer"]["counter_used"] is True

    if body["accepted"]:
        assert body["offer"]["weekly_wage"] > before
        # The bonuses follow the wage rather than staying at the old scale.
        assert body["offer"]["goal_bonus"] == max(1, round(body["offer"]["weekly_wage"] * 0.30))
    else:
        assert body["offer"]["weekly_wage"] == before

    # Either way, the door is shut.
    again = api_client.post(
        f"/careers/{summer_career}/transfer/offers/{renewal['offer_id']}/counter"
    )
    assert again.status_code == 409
    assert again.json()["code"] == "offer_not_open"


def test_a_countered_offer_can_still_be_accepted(api_client, summer_career):
    offers = api_client.get(f"/careers/{summer_career}/transfer/offers").json()["offers"]
    renewal = next(o for o in offers if o["is_renewal"])

    countered = api_client.post(
        f"/careers/{summer_career}/transfer/offers/{renewal['offer_id']}/counter"
    ).json()["offer"]

    resp = api_client.post(
        f"/careers/{summer_career}/transfer/offers/{renewal['offer_id']}/accept"
    )
    assert resp.status_code == 200
    assert resp.json()["contract"]["weekly_wage"] == countered["weekly_wage"]


def test_the_rollover_reports_the_expired_contract_and_its_offers(api_client, mock_engine):
    """§11.5 step 3 — the summer window opens with the rollover, so the
    player is not left to go looking for it."""
    career_id = create_career(api_client)["career_id"]
    _finish_the_season(career_id)
    conn = _db()
    try:
        ends_on = conn.execute(
            "SELECT ends_on FROM season WHERE career_id = ? ORDER BY starts_on DESC LIMIT 1",
            (career_id,),
        ).fetchone()["ends_on"]
        conn.execute(
            "UPDATE player_contract SET expires_at = ? WHERE career_id = ?",
            (ends_on, career_id),
        )
        conn.commit()
    finally:
        conn.close()

    body = api_client.post(f"/careers/{career_id}/season/rollover").json()
    assert body["user"]["contract_status"] == "expired"
    assert body["offers"]
    assert any(o["is_renewal"] for o in body["offers"])


def test_a_running_contract_survives_the_rollover(api_client, mock_engine):
    career_id = create_career(api_client)["career_id"]
    _finish_the_season(career_id)

    body = api_client.post(f"/careers/{career_id}/season/rollover").json()
    assert body["user"]["contract_status"] == "active"
    assert body["offers"] == []
