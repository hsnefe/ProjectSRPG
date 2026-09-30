"""§14.4 D87-D90, D95, INV-67, INV-69 - where the player lives."""
import sqlite3

import pytest

from api import config, errors
from catalog import housing as catalog
from domain import condition, housing, onboarding, wallet
from tests.conftest import create_career, grant_money


@pytest.fixture
def created_career(api_client):
    return create_career(api_client)


def _url(career_id, tail=""):
    return f"/careers/{career_id}/housing{tail}"


def _set_date(career_id, game_date):
    conn = sqlite3.connect(config.DB_PATH)
    conn.execute("UPDATE career_state SET game_date = ? WHERE career_id = ?", (game_date, career_id))
    conn.commit()
    conn.close()


def _active(api_client, career_id):
    return api_client.get(_url(career_id)).json()["active_residence_id"]


# --- catalog ---------------------------------------------------------------

def test_the_catalog_is_eighteen_homes_and_six_upgrades():
    assert len(catalog.RESIDENCES) == 18
    assert len(catalog.UPGRADES) == 6
    assert sum(1 for r in catalog.RESIDENCES if r["kind"] == "holiday") == 4


def test_validation_rejects_a_price_on_the_wrong_kind_and_an_unknown_rest_effect():
    rent = dict(catalog.get("res-studio"))
    with pytest.raises(ValueError):
        catalog.RESIDENCES.append({**rent, "residence_id": "x", "price": 5})
        try:
            catalog.validate_housing()
        finally:
            catalog.RESIDENCES.pop()
    lake = dict(catalog.get("hol-lake-cabin"))
    lake["rest"] = {"condition": 5, "effects": {"attribute:luck": 1}}
    catalog.RESIDENCES.append({**lake, "residence_id": "y"})
    try:
        with pytest.raises(ValueError):
            catalog.validate_housing()
    finally:
        catalog.RESIDENCES.pop()


# --- opening state ---------------------------------------------------------

def test_a_new_career_lives_in_the_dorm(api_client, created_career):
    body = api_client.get(_url(created_career["career_id"])).json()
    assert body["active_residence_id"] == "res-dorm"
    dorm = next(r for r in body["residences"] if r["residence_id"] == "res-dorm")
    assert dorm["held"] and dorm["active"] and dorm["tenure"] == "start"
    assert sum(1 for r in body["residences"] if r["active"]) == 1


def test_the_database_refuses_a_second_active_home(db_conn, career_id):
    """INV-67 is an index, not a convention."""
    housing.start(db_conn, career_id, "2026-08-01")
    db_conn.execute(
        "INSERT INTO residence (career_id, residence_id, tenure, acquired_on, active) "
        "VALUES (?, 'res-family', 'start', '2026-08-01', 0)", (career_id,),
    )
    with pytest.raises(sqlite3.IntegrityError):
        db_conn.execute(
            "UPDATE residence SET active = 1 WHERE career_id = ? AND residence_id = 'res-family'",
            (career_id,),
        )


def test_the_family_home_is_always_reachable(api_client, created_career):
    career_id = created_career["career_id"]
    resp = api_client.post(_url(career_id, "/res-family/activate"))
    assert resp.status_code == 200
    assert resp.json()["active_residence_id"] == "res-family"
    assert api_client.post(_url(career_id, "/res-dorm/activate")).json()["active_residence_id"] == "res-dorm"


# --- sleep -----------------------------------------------------------------

def test_the_active_home_sets_the_nightly_recovery(api_client, created_career):
    career_id = created_career["career_id"]
    api_client.post(_url(career_id, "/res-family/activate"))
    recovery = api_client.get(_url(career_id)).json()["condition_recovery"]
    family = catalog.get("res-family")
    assert recovery["base"] == family["sleep"]
    assert recovery["bonus"] == 0            # breakfast +2 and commute -2 cancel
    assert [m["key"] for m in recovery["modifiers"]] == ["breakfast", "commute"]
    assert recovery["total"] == family["sleep"]


def test_dorm_noise_is_seeded_and_halves_the_night(db_conn, career_id):
    housing.start(db_conn, career_id, "2026-08-01")
    dorm = catalog.get("res-dorm")
    nights = [f"2026-09-{d:02d}" for d in range(1, 29)]
    results = [housing.recovery_parts(db_conn, career_id, n, seed=7) for n in nights]
    again = [housing.recovery_parts(db_conn, career_id, n, seed=7) for n in nights]
    assert results == again                                   # deterministic
    halved = [r for r in results if r["noise"]["halved"]]
    assert 0 < len(halved) < len(nights)                      # a chance, not a rule
    assert all(r["sleep"] == round(dorm["sleep"] / 2) for r in halved)
    # No date, no roll: the nominal night, with the chance reported.
    nominal = housing.recovery_parts(db_conn, career_id)
    assert nominal["sleep"] == dorm["sleep"] and nominal["noise"]["chance"] == dorm["noise_chance"]


def test_the_recovery_total_respects_the_cap(db_conn, career_id, monkeypatch):
    housing.start(db_conn, career_id, "2026-08-01")
    monkeypatch.setattr(config, "MAX_CONDITION_RECOVERY_PER_DAY", 4)
    recovery = condition.daily_recovery(db_conn, career_id)
    assert recovery["total"] == 4 and recovery["capped"] is True


def test_the_best_home_with_every_upgrade_fits_under_the_cap():
    best = max(r["sleep"] for r in catalog.RESIDENCES if r["kind"] != "holiday")
    extras = sum(u.get("sleep", 0) + u.get("morning", 0) for u in catalog.UPGRADES)
    assert best + extras <= config.MAX_CONDITION_RECOVERY_PER_DAY


# --- renting ---------------------------------------------------------------

def test_renting_moves_in_and_charges_the_rest_of_the_month(api_client, created_career):
    career_id = created_career["career_id"]
    _set_date(career_id, "2026-09-16")          # 15 days left of 30, today included
    grant_money(career_id, 1000)
    before = api_client.get(_url(career_id)).json()["career_state"]["money"]

    resp = api_client.post(_url(career_id, "/res-studio/acquire"))
    assert resp.status_code == 200
    body = resp.json()
    assert body["active_residence_id"] == "res-studio" and body["moved"] is True
    rent = catalog.get("res-studio")["rent_monthly"]
    assert body["ledger_entries"][0]["amount"] == -((rent * 15 + 29) // 30)   # rounded up
    assert body["ledger_entries"][0]["kind"] == "rent"
    assert body["career_state"]["money"] == before + body["ledger_entries"][0]["amount"]


def test_renting_what_you_cannot_afford_changes_nothing(api_client, created_career):
    career_id = created_career["career_id"]
    _set_date(career_id, "2026-09-01")          # a whole month's rent, more than the 60 in hand
    resp = api_client.post(_url(career_id, "/res-site-flat/acquire"))
    assert resp.status_code == 409 and resp.json()["code"] == "insufficient_funds"
    assert _active(api_client, career_id) == "res-dorm"


def test_leaving_a_lease_ends_it(api_client, created_career):
    """INV-69: no rent for a flat you are not living in."""
    career_id = created_career["career_id"]
    grant_money(career_id, 1000)
    api_client.post(_url(career_id, "/res-studio/acquire"))
    api_client.post(_url(career_id, "/res-family/activate"))
    studio = next(r for r in api_client.get(_url(career_id)).json()["residences"]
                  if r["residence_id"] == "res-studio")
    assert studio["held"] is False
    resp = api_client.post(_url(career_id, "/res-studio/activate"))
    assert resp.status_code == 404 and resp.json()["code"] == "residence_not_held"


def test_acquiring_twice_and_the_hotel_are_refused(api_client, created_career):
    career_id = created_career["career_id"]
    grant_money(career_id, 1000)
    api_client.post(_url(career_id, "/res-studio/acquire"))
    again = api_client.post(_url(career_id, "/res-studio/acquire"))
    assert again.status_code == 409 and again.json()["code"] == "residence_already_held"
    hotel = api_client.post(_url(career_id, "/res-hotel/acquire"))
    assert hotel.status_code == 409 and hotel.json()["code"] == "residence_not_available"
    assert api_client.post(_url(career_id, "/res-nowhere/acquire")).status_code == 422


# --- buying ----------------------------------------------------------------

def test_buying_does_not_move_you_and_activating_does(api_client, created_career):
    career_id = created_career["career_id"]
    grant_money(career_id, 50_000)
    bought = api_client.post(_url(career_id, "/res-sea-villa/acquire")).json()
    assert bought["moved"] is False and bought["active_residence_id"] == "res-dorm"
    assert bought["ledger_entries"][0]["amount"] == -catalog.get("res-sea-villa")["price"]

    moved = api_client.post(_url(career_id, "/res-sea-villa/activate")).json()
    assert moved["active_residence_id"] == "res-sea-villa"
    assert moved["condition_recovery"]["base"] == catalog.get("res-sea-villa")["sleep"]


def test_an_owned_home_survives_moving_out_and_back(api_client, created_career):
    career_id = created_career["career_id"]
    grant_money(career_id, 50_000)
    api_client.post(_url(career_id, "/res-garden-house/acquire"))
    api_client.post(_url(career_id, "/res-garden-house/activate"))
    api_client.post(_url(career_id, "/res-family/activate"))
    garden = next(r for r in api_client.get(_url(career_id)).json()["residences"]
                  if r["residence_id"] == "res-garden-house")
    assert garden["held"] and garden["tenure"] == "owned" and garden["active"] is False
    assert api_client.post(_url(career_id, "/res-garden-house/activate")).status_code == 200


def test_the_active_homes_grade_adds_to_charisma_only(api_client, created_career):
    career_id = created_career["career_id"]
    grant_money(career_id, 50_000)

    def charisma():
        attrs = api_client.get(f"/careers/{career_id}/player").json()["attributes"]
        return next(a for a in attrs if a["key"] == "charisma")["passive_bonus"]

    assert charisma() == 0.0
    api_client.post(_url(career_id, "/res-sea-villa/acquire"))
    assert charisma() == 0.0                                   # owned is not lived in
    api_client.post(_url(career_id, "/res-sea-villa/activate"))
    assert charisma() == catalog.get("res-sea-villa")["grade"] * 0.5
    api_client.post(_url(career_id, "/res-dorm/activate"))
    assert charisma() == 0.0                                   # derived, never stored


def test_a_holiday_home_cannot_be_lived_in(api_client, created_career):
    career_id = created_career["career_id"]
    grant_money(career_id, 10_000)
    api_client.post(_url(career_id, "/hol-village-house/acquire"))
    resp = api_client.post(_url(career_id, "/hol-village-house/activate"))
    assert resp.status_code == 409 and resp.json()["code"] == "residence_not_available"


# --- upgrades --------------------------------------------------------------

def test_upgrades_need_an_owned_home_and_raise_the_night(api_client, created_career):
    career_id = created_career["career_id"]
    grant_money(career_id, 50_000)

    rented = api_client.post(_url(career_id, "/res-studio/acquire"))
    assert rented.status_code == 200
    refused = api_client.post(_url(career_id, "/res-studio/upgrades/up-orthopedic-bed"))
    assert refused.status_code == 409 and refused.json()["code"] == "residence_not_available"

    api_client.post(_url(career_id, "/res-garden-house/acquire"))
    api_client.post(_url(career_id, "/res-garden-house/activate"))
    bed = api_client.post(_url(career_id, "/res-garden-house/upgrades/up-orthopedic-bed"))
    assert bed.status_code == 200
    recovery = bed.json()["condition_recovery"]
    assert recovery["total"] == catalog.get("res-garden-house")["sleep"] + 1
    assert any(m["key"] == "up-orthopedic-bed" for m in recovery["modifiers"])

    again = api_client.post(_url(career_id, "/res-garden-house/upgrades/up-orthopedic-bed"))
    assert again.status_code == 409 and again.json()["code"] == "upgrade_already_installed"


def test_blackout_curtains_cancel_the_roommate_noise(db_conn, career_id):
    housing.start(db_conn, career_id, "2026-08-01")
    wallet.apply(db_conn, career_id, 100_000, "sale", "seed", "2026-08-01")
    # Noise lives in a dorm, which is never owned: pin the rule on a spec that has
    # some and a home that has the upgrade, at the read layer.
    db_conn.execute("UPDATE residence SET active = 0 WHERE career_id = ?", (career_id,))
    db_conn.execute(
        "INSERT INTO residence (career_id, residence_id, tenure, acquired_on, active) "
        "VALUES (?, 'res-dorm', 'owned', '2026-08-01', 1) ON CONFLICT DO UPDATE SET active = 1",
        (career_id,),
    )
    housing._insert  # noqa: B018 - the helper exists; the row above is enough here
    db_conn.execute(
        "INSERT INTO residence_upgrade (career_id, residence_id, upgrade_id, installed_on) "
        "VALUES (?, 'res-dorm', 'up-blackout', '2026-08-01')", (career_id,),
    )
    parts = housing.recovery_parts(db_conn, career_id, "2026-09-01", 1)
    assert parts["noise"] == {"chance": 0.0, "halved": False}


# --- holiday rest days -----------------------------------------------------

def _winter_break_day(career_id):
    conn = sqlite3.connect(config.DB_PATH)
    conn.row_factory = sqlite3.Row
    row = conn.execute(
        "SELECT winter_break_from FROM season WHERE career_id = ? ORDER BY starts_on LIMIT 1",
        (career_id,),
    ).fetchone()
    conn.close()
    return row["winter_break_from"]


def test_a_rest_day_is_out_of_season_most_of_the_year(api_client, created_career):
    career_id = created_career["career_id"]
    grant_money(career_id, 10_000)
    api_client.post(_url(career_id, "/hol-village-house/acquire"))
    resp = api_client.post(_url(career_id, "/hol-village-house/rest"))
    assert resp.status_code == 409 and resp.json()["code"] == "rest_out_of_season"


def test_a_rest_day_in_the_winter_break_pays_and_uses_the_day(api_client, created_career):
    career_id = created_career["career_id"]
    grant_money(career_id, 10_000)
    api_client.post(_url(career_id, "/hol-village-house/acquire"))
    _set_date(career_id, _winter_break_day(career_id))
    conn = sqlite3.connect(config.DB_PATH)
    conn.execute("UPDATE career_state SET condition = 30 WHERE career_id = ?", (career_id,))
    conn.commit()
    conn.close()

    resp = api_client.post(_url(career_id, "/hol-village-house/rest"))
    assert resp.status_code == 200, resp.json()
    body = resp.json()
    assert body["career_state"]["condition"] == 30 + catalog.get("hol-village-house")["rest"]["condition"]
    assert body["career_state"]["day_budget"]["time"] == 0
    assert any(c["key"] == "empathy" for c in body["attribute_changes"])

    second = api_client.post(_url(career_id, "/hol-village-house/rest"))
    assert second.status_code == 409        # the day is spent


def test_resting_needs_the_house(api_client, created_career):
    career_id = created_career["career_id"]
    _set_date(career_id, _winter_break_day(career_id))
    resp = api_client.post(_url(career_id, "/hol-lake-cabin/rest"))
    assert resp.status_code == 404 and resp.json()["code"] == "residence_not_held"


# --- rent day, eviction, hotel --------------------------------------------

def test_rent_is_taken_on_the_first_whatever_the_weekday(db_conn, career_id):
    housing.start(db_conn, career_id, "2026-08-01")
    wallet.apply(db_conn, career_id, 5000, "sale", "seed", "2026-08-01")
    housing.acquire(db_conn, career_id, "res-studio", "2026-09-20")
    rent = catalog.get("res-studio")["rent_monthly"]

    quiet = housing.process_day(db_conn, career_id, "2026-09-30")
    assert quiet["ledger_entries"] == []
    first = housing.process_day(db_conn, career_id, "2026-10-01")     # a Thursday
    assert [e["amount"] for e in first["ledger_entries"]] == [-rent]
    assert first["ledger_entries"][0]["kind"] == "rent"
    assert first["moves"] == []


def test_unpaid_rent_sends_the_player_home(db_conn, career_id):
    housing.start(db_conn, career_id, "2026-08-01")
    wallet.apply(db_conn, career_id, 500, "sale", "seed", "2026-08-01")
    housing.acquire(db_conn, career_id, "res-studio", "2026-09-30")
    wallet.apply(db_conn, career_id, -wallet.get_balance(db_conn, career_id), "purchase", "spent", "2026-09-30")

    result = housing.process_day(db_conn, career_id, "2026-10-01")
    assert result["moves"] == [{"from": "res-studio", "to": "res-family", "reason": "rent"}]
    assert housing.active_row(db_conn, career_id)["residence_id"] == "res-family"
    assert db_conn.execute(
        "SELECT 1 FROM residence WHERE career_id = ? AND residence_id = 'res-studio'", (career_id,)
    ).fetchone() is None


def test_an_eviction_stops_the_advance_and_makes_the_news(api_client, created_career, mock_engine):
    career_id = created_career["career_id"]
    grant_money(career_id, 200)
    conn = sqlite3.connect(config.DB_PATH)
    conn.row_factory = sqlite3.Row
    start = conn.execute("SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)).fetchone()[0]
    conn.close()
    assert start < "2026-09-30"
    _set_date(career_id, "2026-09-29")
    api_client.post(_url(career_id, "/res-studio/acquire"))
    money = api_client.get(_url(career_id)).json()["career_state"]["money"]
    wallet_conn = sqlite3.connect(config.DB_PATH)
    wallet_conn.execute("UPDATE career_state SET money = 0 WHERE career_id = ?", (career_id,))
    wallet_conn.commit()
    wallet_conn.close()
    assert money > 0

    body = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"}).json()
    assert body["stop_reason"] == "residence_moved"
    assert body["residence_moves"] == [{"from": "res-studio", "to": "res-family", "reason": "rent"}]
    assert body["stopped_on"] == "2026-10-01"
    assert _active(api_client, career_id) == "res-family"
    assert len(body["news_created"]) >= 1


def test_the_chef_leaves_when_the_fee_cannot_be_paid(db_conn, career_id):
    housing.start(db_conn, career_id, "2026-08-01")
    wallet.apply(db_conn, career_id, 100_000, "sale", "seed", "2026-08-01")
    housing.acquire(db_conn, career_id, "res-garden-house", "2026-08-02")
    housing.activate(db_conn, career_id, "res-garden-house", "2026-08-02")
    housing.install_upgrade(db_conn, career_id, "res-garden-house", "up-chef", "2026-08-02")

    paid = housing.process_day(db_conn, career_id, "2026-09-01")
    assert [e["amount"] for e in paid["ledger_entries"]] == [-60]
    assert housing.recovery_parts(db_conn, career_id)["modifiers"][-1]["amount"] == 2

    wallet.apply(db_conn, career_id, -wallet.get_balance(db_conn, career_id), "purchase", "spent", "2026-09-02")
    lost = housing.process_day(db_conn, career_id, "2026-10-01")
    assert lost["lost_upgrades"] == [{"residence_id": "res-garden-house", "upgrade_id": "up-chef"}]
    assert lost["moves"] == []                                 # the house stays
    assert all(m["amount"] != 2 for m in housing.recovery_parts(db_conn, career_id)["modifiers"])


def test_a_transfer_books_a_hotel_unless_you_own_your_home(db_conn, career_id):
    housing.start(db_conn, career_id, "2026-08-01")
    move = housing.on_transfer(db_conn, career_id, "2026-09-01")
    assert move["to"] == "res-hotel" and move["expires_on"] == "2026-09-15"
    assert housing.active_row(db_conn, career_id)["tenure"] == "hotel"

    # A second transfer replaces the room rather than colliding with it.
    assert housing.on_transfer(db_conn, career_id, "2026-09-05")["expires_on"] == "2026-09-19"

    wallet.apply(db_conn, career_id, 100_000, "sale", "seed", "2026-09-05")
    housing.acquire(db_conn, career_id, "res-garden-house", "2026-09-06")
    housing.activate(db_conn, career_id, "res-garden-house", "2026-09-06")
    assert housing.on_transfer(db_conn, career_id, "2026-09-10") is None
    assert housing.active_row(db_conn, career_id)["residence_id"] == "res-garden-house"


def test_the_hotel_charges_nightly_then_hands_the_player_to_the_family(db_conn, career_id):
    housing.start(db_conn, career_id, "2026-08-01")
    wallet.apply(db_conn, career_id, 1000, "sale", "seed", "2026-08-01")
    housing.on_transfer(db_conn, career_id, "2026-09-01")
    fee = catalog.get("res-hotel")["daily_fee"]

    night = housing.process_day(db_conn, career_id, "2026-09-02")
    assert [e["amount"] for e in night["ledger_entries"]] == [-fee]

    last = housing.process_day(db_conn, career_id, "2026-09-15")
    assert last["ledger_entries"] == []
    assert last["moves"] == [{"from": "res-hotel", "to": "res-family", "reason": "hotel_expired"}]
    assert wallet.ledger_total(db_conn, career_id) == wallet.get_balance(db_conn, career_id)   # INV-19
