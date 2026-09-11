"""§12.7 — sponsorship deals: weekly money, and days that stop being yours."""
import datetime as _dt

import pytest

from api import config
from content.sponsorships import BY_ID, SPONSORSHIPS
from db.connection import get_connection
from domain import onboarding, season, sponsorship
from tests.conftest import create_career, set_attribute


def _db():
    return get_connection(config.DB_PATH)


def _offer_deal(career_id, template_id="local_sports_shop", on_date=None):
    """Puts one deal on the table directly. The daily roll is 4% and seeded,
    so waiting for one would be a test about the calendar."""
    from api.ids import new_sponsorship_deal_id

    on_date = on_date or onboarding.SEASON_STARTS_ON
    deal_id = new_sponsorship_deal_id()
    conn = _db()
    try:
        conn.execute(
            "INSERT INTO sponsorship_deal (career_id, deal_id, template_id, status, "
            "offered_on, signed_on, expires_on, weekly_income) "
            "VALUES (?, ?, ?, 'offered', ?, NULL, NULL, ?)",
            (career_id, deal_id, template_id, on_date,
             BY_ID[template_id]["weekly_income"]),
        )
        conn.commit()
    finally:
        conn.close()
    return deal_id


@pytest.fixture
def career(api_client, mock_engine):
    return create_career(api_client)["career_id"]


# --- the content file -----------------------------------------------------

def test_deals_with_obligations_pay_more():
    """The whole tension: the big cheque costs afternoons."""
    free = [t for t in SPONSORSHIPS if t["obligation"] is None]
    bound = [t for t in SPONSORSHIPS if t["obligation"] is not None]

    assert free and bound
    assert max(t["weekly_income"] for t in free) < min(t["weekly_income"] for t in bound)


def test_the_public_view_hides_the_generator_knobs():
    """`weight` and `cooldown_days` are the roll's business, not the
    player's — the same split R4 draws for social offers."""
    view = sponsorship_public = __import__(
        "content.sponsorships", fromlist=["public_view"]
    ).public_view(SPONSORSHIPS[0])
    assert "weight" not in view
    assert "cooldown_days" not in view
    assert "brand" in view and "weekly_income" in view


def test_an_obligations_price_is_visible_before_signing():
    """A cost you only discover afterwards is a trap, not a decision."""
    from content.sponsorships import public_view

    bound = next(t for t in SPONSORSHIPS if t["obligation"])
    view = public_view(bound)
    assert view["obligation"]["every_days"] >= 7
    assert view["obligation"]["costs"]


# --- signing --------------------------------------------------------------

def test_signing_a_deal_with_no_obligations_books_nothing(api_client, career):
    deal_id = _offer_deal(career)

    resp = api_client.post(f"/careers/{career}/sponsorships/{deal_id}/accept")
    assert resp.status_code == 200, resp.text
    deal = resp.json()["deal"]

    assert deal["status"] == "active"
    assert deal["obligations"] == []
    assert deal["expires_on"] is not None


def test_signing_books_every_obligation_up_front(api_client, career):
    """Scheduled all at once so the player can see what they agreed to, and
    so a day loop that never ran cannot silently fail to create one."""
    set_attribute(career, "charisma", 65)  # the bank deal wants level 6
    deal_id = _offer_deal(career, "bank_campaign")

    deal = api_client.post(
        f"/careers/{career}/sponsorships/{deal_id}/accept"
    ).json()["deal"]

    assert deal["obligations"]
    assert all(o["status"] == "pending" for o in deal["obligations"])
    dates = [_dt.date.fromisoformat(o["due_on"]) for o in deal["obligations"]]
    assert dates == sorted(dates)
    # Every 30 days, and never past the end of the deal.
    gaps = {(b - a).days for a, b in zip(dates, dates[1:])}
    assert gaps == {30}
    assert dates[-1].isoformat() <= deal["expires_on"]


def test_a_deal_ends_on_a_season_boundary(api_client, career):
    deal_id = _offer_deal(career)
    deal = api_client.post(
        f"/careers/{career}/sponsorships/{deal_id}/accept"
    ).json()["deal"]

    assert deal["expires_on"] == season.calendar_for(
        onboarding.FIRST_SEASON_OPENING_YEAR
    ).ends_on.isoformat()


def test_a_gated_deal_is_refused_below_the_threshold(api_client, career):
    """D42 — the kişi attributes finally do real work in the money system."""
    set_attribute(career, "charisma", 10)  # level 1
    deal_id = _offer_deal(career, "telecom_tour")

    resp = api_client.post(f"/careers/{career}/sponsorships/{deal_id}/accept")
    assert resp.status_code == 409
    assert resp.json()["code"] == "requirement_not_met"


def test_declining_costs_nothing_and_cannot_fail(api_client, career):
    deal_id = _offer_deal(career)
    before = api_client.get(f"/careers/{career}/day").json()["career_state"]

    resp = api_client.post(f"/careers/{career}/sponsorships/{deal_id}/decline")
    assert resp.status_code == 200
    after = resp.json()["career_state"]

    assert after["money"] == before["money"]
    assert after["day_budget"] == before["day_budget"]
    assert resp.json()["offers"] == []


def test_a_resolved_deal_cannot_be_resolved_again(api_client, career):
    deal_id = _offer_deal(career)
    api_client.post(f"/careers/{career}/sponsorships/{deal_id}/accept")

    again = api_client.post(f"/careers/{career}/sponsorships/{deal_id}/decline")
    assert again.status_code == 409
    assert again.json()["code"] == "sponsorship_not_open"


# --- the money ------------------------------------------------------------

def test_an_active_deal_pays_every_monday(api_client, career):
    deal_id = _offer_deal(career)
    api_client.post(f"/careers/{career}/sponsorships/{deal_id}/accept")

    income = BY_ID["local_sports_shop"]["weekly_income"]
    paid = 0
    for _ in range(9):
        resp = api_client.post(f"/careers/{career}/advance", json={"to": "next_day"})
        if resp.status_code != 200:
            break
        for entry in resp.json()["ledger_entries"]:
            if entry["kind"] == "sponsorship":
                paid += entry["amount"]

    assert paid == income, "exactly one Monday in nine days"


def test_the_income_is_frozen_at_signing(api_client, career):
    """A deal runs on the number it was signed at — the same reason
    inventory freezes `price_paid`."""
    deal_id = _offer_deal(career)
    deal = api_client.post(
        f"/careers/{career}/sponsorships/{deal_id}/accept"
    ).json()["deal"]

    conn = _db()
    try:
        stored = conn.execute(
            "SELECT weekly_income FROM sponsorship_deal WHERE career_id = ? AND deal_id = ?",
            (career, deal_id),
        ).fetchone()["weekly_income"]
    finally:
        conn.close()
    assert stored == deal["weekly_income"]


def test_an_expired_deal_stops_paying(api_client, career):
    deal_id = _offer_deal(career)
    api_client.post(f"/careers/{career}/sponsorships/{deal_id}/accept")

    conn = _db()
    try:
        conn.execute(
            "UPDATE sponsorship_deal SET expires_on = '2026-08-23' "
            "WHERE career_id = ? AND deal_id = ?",
            (career, deal_id),
        )
        conn.commit()
    finally:
        conn.close()

    for _ in range(9):
        resp = api_client.post(f"/careers/{career}/advance", json={"to": "next_day"})
        if resp.status_code != 200:
            break
        assert not [e for e in resp.json()["ledger_entries"] if e["kind"] == "sponsorship"]

    assert api_client.get(f"/careers/{career}/sponsorships").json()["active"] == []


# --- obligations ----------------------------------------------------------

def _sign_with_obligations(api_client, career):
    set_attribute(career, "charisma", 65)
    deal_id = _offer_deal(career, "bank_campaign")
    deal = api_client.post(
        f"/careers/{career}/sponsorships/{deal_id}/accept"
    ).json()["deal"]
    return deal_id, deal["obligations"][0]


def _park_on(career, on_date):
    conn = _db()
    try:
        conn.execute(
            "UPDATE career_state SET game_date = ? WHERE career_id = ?",
            (on_date, career),
        )
        conn.commit()
    finally:
        conn.close()


def test_a_due_obligation_blocks_the_day(api_client, career):
    """D53's reading: you said you would be there."""
    _, obligation = _sign_with_obligations(api_client, career)
    _park_on(career, obligation["due_on"])

    resp = api_client.post(f"/careers/{career}/advance", json={"to": "next_day"})
    assert resp.status_code == 409
    assert resp.json()["code"] == "sponsorship_obligation_pending"


def test_attending_costs_the_day_and_unblocks_it(api_client, career):
    _, obligation = _sign_with_obligations(api_client, career)
    _park_on(career, obligation["due_on"])
    before = api_client.get(f"/careers/{career}/day").json()["career_state"]

    resp = api_client.post(
        f"/careers/{career}/sponsorships/obligations/{obligation['obligation_id']}/attend"
    )
    assert resp.status_code == 200
    after = resp.json()["career_state"]

    assert after["day_budget"]["time"] == before["day_budget"]["time"] - 300
    assert after["condition"] == before["condition"] - 8

    assert api_client.post(
        f"/careers/{career}/advance", json={"to": "next_day"}
    ).status_code == 200


def test_attending_without_the_time_is_refused_and_writes_nothing(api_client, career):
    """INV-4 — a 409 leaves the obligation pending and the budget untouched."""
    _, obligation = _sign_with_obligations(api_client, career)
    _park_on(career, obligation["due_on"])

    conn = _db()
    try:
        conn.execute(
            "UPDATE day_budget SET remaining = 10 WHERE career_id = ? AND resource_key = 'time'",
            (career,),
        )
        conn.commit()
    finally:
        conn.close()

    resp = api_client.post(
        f"/careers/{career}/sponsorships/obligations/{obligation['obligation_id']}/attend"
    )
    assert resp.status_code == 409
    assert resp.json()["code"] == "insufficient_budget"

    still = api_client.get(f"/careers/{career}/sponsorships").json()
    assert still["pending_obligations"]


def test_skipping_breaks_the_deal_and_stops_the_money(api_client, career):
    """The escape hatch that keeps the gate from being a lock: the player is
    charged, never trapped."""
    deal_id, obligation = _sign_with_obligations(api_client, career)
    _park_on(career, obligation["due_on"])

    media_before = api_client.get(f"/careers/{career}/relationships/media").json()["score"]

    resp = api_client.post(
        f"/careers/{career}/sponsorships/obligations/{obligation['obligation_id']}/skip"
    )
    assert resp.status_code == 200
    assert resp.json()["relationship_changes"][0]["relationship_id"] == "media"
    assert (
        api_client.get(f"/careers/{career}/relationships/media").json()["score"]
        < media_before
    )

    # The deal is gone, and so is everything else it had booked.
    body = api_client.get(f"/careers/{career}/sponsorships").json()
    assert body["active"] == []
    assert body["pending_obligations"] == []

    # And time moves again.
    assert api_client.post(
        f"/careers/{career}/advance", json={"to": "next_day"}
    ).status_code == 200


def test_a_broken_deal_pays_nothing_further(api_client, career):
    _, obligation = _sign_with_obligations(api_client, career)
    _park_on(career, obligation["due_on"])
    api_client.post(
        f"/careers/{career}/sponsorships/obligations/{obligation['obligation_id']}/skip"
    )

    for _ in range(9):
        resp = api_client.post(f"/careers/{career}/advance", json={"to": "next_day"})
        if resp.status_code != 200:
            break
        assert not [e for e in resp.json()["ledger_entries"] if e["kind"] == "sponsorship"]


def test_an_unknown_obligation_is_404(api_client, career):
    resp = api_client.post(f"/careers/{career}/sponsorships/obligations/ob_nope/attend")
    assert resp.status_code == 404
    assert resp.json()["code"] == "sponsorship_not_found"


# --- no phase gate --------------------------------------------------------

def test_a_deal_can_be_signed_at_any_point_in_the_season(api_client, career):
    """Unlike a transfer: a brand does not wait for a window."""
    from domain.season import derive_phase

    conn = _db()
    try:
        phase = derive_phase(conn, career, onboarding.SEASON_STARTS_ON)
    finally:
        conn.close()
    assert phase == "pre_season"  # emphatically not a transfer window

    deal_id = _offer_deal(career)
    assert api_client.post(
        f"/careers/{career}/sponsorships/{deal_id}/accept"
    ).status_code == 200
