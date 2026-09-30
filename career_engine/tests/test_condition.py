"""§6.6 - condition.daily_recovery(), the single read path for "what is one
advanced day worth". The write side (apply_delta / set_from_match) is
covered where it is exercised: tests/test_time_router.py and
tests/test_matches_router.py."""
import pytest

from api import config
from catalog.shop import DAILY_CONDITION_BONUS
from domain import condition


def own(conn, career_id, *item_ids):
    for item_id in item_ids:
        conn.execute(
            "INSERT INTO inventory (career_id, item_id, purchased_at, price_paid, upkeep_weekly) "
            "VALUES (?, ?, '2026-08-01', 0, 0)",
            (career_id, item_id),
        )
    conn.commit()


def test_empty_inventory_recovers_the_flat_base(db_conn, career_id):
    recovery = condition.daily_recovery(db_conn, career_id)
    assert recovery["base"] == config.NATURAL_CONDITION_RECOVERY_PER_DAY
    assert recovery["bonus"] == 0
    assert recovery["total"] == config.NATURAL_CONDITION_RECOVERY_PER_DAY
    assert recovery["capped"] is False
    assert recovery["sources"] == []


def test_an_owned_item_raises_the_daily_rate(db_conn, career_id):
    own(db_conn, career_id, "estate-flat")
    recovery = condition.daily_recovery(db_conn, career_id)

    bonus = DAILY_CONDITION_BONUS["estate-flat"]
    assert recovery["bonus"] == bonus
    assert recovery["total"] == config.NATURAL_CONDITION_RECOVERY_PER_DAY + bonus
    assert recovery["sources"] == [
        {"item_id": "estate-flat", "title": "Şehir merkezi daire", "amount": bonus}
    ]


def test_items_without_a_daily_effect_contribute_nothing(db_conn, career_id):
    own(db_conn, career_id, "home-cinema", "acc-smart-watch")
    recovery = condition.daily_recovery(db_conn, career_id)
    assert recovery["bonus"] == 0
    assert recovery["sources"] == []


def test_bonuses_from_several_items_add_up_and_are_ordered(db_conn, career_id):
    own(db_conn, career_id, "estate-villa", "estate-flat", "home-cinema")
    recovery = condition.daily_recovery(db_conn, career_id)

    assert recovery["bonus"] == (
        DAILY_CONDITION_BONUS["estate-flat"] + DAILY_CONDITION_BONUS["estate-villa"]
    )
    # Biggest contributor first, so a UI listing them needs no sort of its own.
    assert [s["item_id"] for s in recovery["sources"]] == ["estate-flat", "estate-villa"]


def test_an_inventory_row_for_a_dropped_item_does_not_explode(db_conn, career_id):
    """An old career can hold an item id the catalog no longer lists. That
    must cost the day loop nothing worse than zero bonus."""
    own(db_conn, career_id, "item-that-no-longer-exists")
    assert condition.daily_recovery(db_conn, career_id)["bonus"] == 0


def test_total_is_capped(db_conn, career_id, monkeypatch):
    monkeypatch.setattr(config, "MAX_CONDITION_RECOVERY_PER_DAY", 6)
    own(db_conn, career_id, "estate-flat", "estate-villa")
    recovery = condition.daily_recovery(db_conn, career_id)

    assert recovery["bonus"] == 2          # uncapped sum is still reported
    assert recovery["total"] == 6          # INV-41
    assert recovery["capped"] is True


def test_the_bonus_never_lifts_condition_past_the_attribute_ceiling(db_conn, career_id, player_id):
    """INV-10 - the whole point of routing the bonus through apply_delta()
    rather than writing career_state.condition directly. A fully-equipped
    player one point below their ceiling still lands ON the ceiling."""
    db_conn.execute(
        "INSERT INTO player_attribute (career_id, player_id, attribute_key, value) "
        "VALUES (?, ?, 'condition', 80)",
        (career_id, player_id),
    )
    db_conn.execute("UPDATE career_state SET condition = 79 WHERE career_id = ?", (career_id,))
    own(db_conn, career_id, "estate-flat", "estate-villa")

    recovery = condition.daily_recovery(db_conn, career_id)
    assert recovery["total"] == 7

    assert condition.apply_delta(db_conn, career_id, recovery["total"]) == 80
