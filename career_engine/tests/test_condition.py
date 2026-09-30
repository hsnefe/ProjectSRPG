"""§6.6 - condition.daily_recovery(), the single read path for "what is one
advanced day worth". The write side (apply_delta / set_from_match) is
covered where it is exercised: tests/test_time_router.py and
tests/test_matches_router.py.

§14.4 D88: the base is the active residence's sleep, not a flat constant, and no
shop row carries a daily condition bonus any more (the treadmill and the estate
rows that did are gone), so the item-bonus tests install their own."""
import pytest

from api import config
from catalog import housing as housing_catalog
from catalog import shop
from domain import condition

DORM = housing_catalog.get("res-dorm")


@pytest.fixture
def condition_items(monkeypatch):
    """Two catalog items that carry a daily condition bonus, patched in because
    the shipped catalog has none."""
    bonuses = {"home-cinema": 1, "home-record-player": 2}
    monkeypatch.setattr(shop, "DAILY_CONDITION_BONUS", bonuses)
    return bonuses


def own(conn, career_id, *item_ids):
    for item_id in item_ids:
        conn.execute(
            "INSERT INTO inventory (career_id, item_id, purchased_at, price_paid, upkeep_weekly) "
            "VALUES (?, ?, '2026-08-01', 0, 0)",
            (career_id, item_id),
        )
    conn.commit()


def test_empty_inventory_recovers_the_residence_sleep(db_conn, career_id):
    recovery = condition.daily_recovery(db_conn, career_id)
    assert recovery["base"] == DORM["sleep"]
    assert recovery["bonus"] == 0
    assert recovery["total"] == DORM["sleep"]
    assert recovery["capped"] is False
    assert recovery["sources"] == []
    assert recovery["residence"]["residence_id"] == "res-dorm"


def test_an_owned_item_raises_the_daily_rate(db_conn, career_id, condition_items):
    own(db_conn, career_id, "home-cinema")
    recovery = condition.daily_recovery(db_conn, career_id)

    assert recovery["bonus"] == 1
    assert recovery["total"] == DORM["sleep"] + 1
    assert recovery["sources"] == [
        {"item_id": "home-cinema", "title": "Ev sineması sistemi", "amount": 1}
    ]


def test_items_without_a_daily_effect_contribute_nothing(db_conn, career_id):
    own(db_conn, career_id, "home-cinema", "acc-smart-watch")
    recovery = condition.daily_recovery(db_conn, career_id)
    assert recovery["bonus"] == 0
    assert recovery["sources"] == []


def test_bonuses_from_several_items_add_up_and_are_ordered(db_conn, career_id, condition_items):
    own(db_conn, career_id, "home-cinema", "home-record-player", "home-plants")
    recovery = condition.daily_recovery(db_conn, career_id)

    assert recovery["bonus"] == 3
    # Biggest contributor first, so a UI listing them needs no sort of its own.
    assert [s["item_id"] for s in recovery["sources"]] == ["home-record-player", "home-cinema"]


def test_an_inventory_row_for_a_dropped_item_does_not_explode(db_conn, career_id):
    """An old career can hold an item id the catalog no longer lists. That
    must cost the day loop nothing worse than zero bonus."""
    own(db_conn, career_id, "item-that-no-longer-exists")
    assert condition.daily_recovery(db_conn, career_id)["bonus"] == 0


def test_total_is_capped(db_conn, career_id, monkeypatch, condition_items):
    monkeypatch.setattr(config, "MAX_CONDITION_RECOVERY_PER_DAY", DORM["sleep"] + 1)
    own(db_conn, career_id, "home-cinema", "home-record-player")
    recovery = condition.daily_recovery(db_conn, career_id)

    assert recovery["bonus"] == 3          # uncapped sum is still reported
    assert recovery["total"] == DORM["sleep"] + 1   # INV-41
    assert recovery["capped"] is True


def test_the_bonus_never_lifts_condition_past_the_attribute_ceiling(
    db_conn, career_id, player_id, condition_items
):
    """INV-10 - the whole point of routing the bonus through apply_delta()
    rather than writing career_state.condition directly. A fully-equipped
    player one point below their ceiling still lands ON the ceiling."""
    db_conn.execute(
        "INSERT INTO player_attribute (career_id, player_id, attribute_key, value) "
        "VALUES (?, ?, 'condition', 80)",
        (career_id, player_id),
    )
    db_conn.execute("UPDATE career_state SET condition = 79 WHERE career_id = ?", (career_id,))
    own(db_conn, career_id, "home-cinema", "home-record-player")

    recovery = condition.daily_recovery(db_conn, career_id)
    assert recovery["total"] == DORM["sleep"] + 3

    assert condition.apply_delta(db_conn, career_id, recovery["total"]) == 80
