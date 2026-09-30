"""§14.2 D80-D82 - gear: slots, equip, grant-only items, legacy rows."""
import sqlite3

import pytest

from api import config
from catalog import grant_item_id, validate_catalog
from catalog.shop import SHOP_ITEMS, gear_by_id, validate_gear
from domain import attributes, inventory, legacy_items, wallet
from tests.conftest import create_career, grant_money


@pytest.fixture
def created_career(api_client):
    return create_career(api_client)


def _buy(api_client, career_id, catalog_id):
    return api_client.post(f"/careers/{career_id}/purchases", json={"catalog_id": catalog_id})


def _items(api_client, career_id):
    return {i["catalog_id"]: i for i in api_client.get(f"/careers/{career_id}/inventory").json()["items"]}


def _charisma(api_client, career_id):
    attrs = api_client.get(f"/careers/{career_id}/player").json()["attributes"]
    return next(a for a in attrs if a["key"] == "charisma")


# --- catalog -------------------------------------------------------------

def test_every_slotted_item_has_a_grade_and_grant_rows_are_free():
    for item in SHOP_ITEMS:
        if item.get("slot"):
            assert 1 <= item["grade"] <= 5, item["catalog_id"]
            assert item["passive_effects"]["attribute:charisma"] == item["grade"] * 0.5
            if item["acquire"] == "grant":
                assert item["price"] == 0
        else:
            assert "grade" not in item


def test_same_slot_items_exist_so_equip_has_something_to_choose():
    watches = [i for i in SHOP_ITEMS if i.get("slot") == "watch"]
    assert len(watches) == 3


def test_validate_gear_rejects_a_priced_grant_and_a_gradeless_slot():
    base = {"catalog_id": "x", "category": "clothing", "slot": "shoes", "grade": 1,
            "acquire": "shop", "price": 10}
    validate_gear([base])
    with pytest.raises(ValueError):
        validate_gear([{**base, "acquire": "grant"}])
    with pytest.raises(ValueError):
        validate_gear([{**base, "grade": 0}])
    with pytest.raises(ValueError):
        validate_gear([{**base, "category": "realEstate"}])


def test_grant_item_is_a_known_effect_key_and_ids_keep_their_hyphens():
    validate_catalog([{"catalog_id": "x", "effects": {"grant_item:special-foundation": 1}}], "test")
    assert grant_item_id("grant_item:special-signed-jersey") == "special-signed-jersey"
    assert grant_item_id("money") is None


# --- equip ---------------------------------------------------------------

def test_a_bought_item_is_worn_when_its_slot_is_empty(api_client, created_career):
    career_id = created_career["career_id"]
    grant_money(career_id, 10000)
    body = _buy(api_client, career_id, "acc-smart-watch").json()
    assert body["item"]["slot"] == "watch" and body["item"]["equipped"] is True


def test_a_second_item_in_a_taken_slot_stays_in_the_wardrobe(api_client, created_career):
    career_id = created_career["career_id"]
    grant_money(career_id, 10000)
    _buy(api_client, career_id, "acc-smart-watch")
    second = _buy(api_client, career_id, "acc-swiss-watch").json()
    assert second["item"]["equipped"] is False
    # Only the smart watch (grade 2, +1.0) counts; the swiss watch (+2.0) does not.
    assert _charisma(api_client, career_id)["passive_bonus"] == 1.0


def test_equip_swaps_the_slot_and_the_bonus_follows(api_client, created_career):
    career_id = created_career["career_id"]
    grant_money(career_id, 10000)
    _buy(api_client, career_id, "acc-smart-watch")
    _buy(api_client, career_id, "acc-swiss-watch")

    resp = api_client.post(f"/careers/{career_id}/inventory/acc-swiss-watch/equip")
    assert resp.status_code == 200
    body = resp.json()
    assert body["passive_bonus"]["charisma"] == 2.0
    items = {i["catalog_id"]: i for i in body["items"]}
    assert items["acc-swiss-watch"]["equipped"] and not items["acc-smart-watch"]["equipped"]
    assert "career_state" in body                         # D28/INV-18
    assert _charisma(api_client, career_id)["passive_bonus"] == 2.0


def test_unequip_drops_the_bonus_but_not_the_row(api_client, created_career):
    career_id = created_career["career_id"]
    grant_money(career_id, 10000)
    _buy(api_client, career_id, "acc-swiss-watch")
    resp = api_client.post(f"/careers/{career_id}/inventory/acc-swiss-watch/unequip")
    assert resp.json()["passive_bonus"]["charisma"] == 0
    assert "acc-swiss-watch" in _items(api_client, career_id)


def test_unworn_gear_still_pays_its_upkeep(api_client, created_career):
    """Equip is not a free sell: upkeep sums every owned row (daytime.py)."""
    career_id = created_career["career_id"]
    grant_money(career_id, 10000)
    _buy(api_client, career_id, "tech-photographer")
    api_client.post(f"/careers/{career_id}/inventory/tech-photographer/unequip")
    from db.connection import get_connection
    conn = get_connection(config.DB_PATH)
    try:
        total = conn.execute(
            "SELECT SUM(upkeep_weekly) AS s FROM inventory WHERE career_id = ?", (career_id,)
        ).fetchone()["s"]
    finally:
        conn.close()
    assert total == 20


def test_slotless_rows_always_count(api_client, created_career):
    """The realEstate rows predate slots; they must keep paying their bonus."""
    career_id = created_career["career_id"]
    grant_money(career_id, 20000)
    _buy(api_client, career_id, "estate-villa")
    assert _charisma(api_client, career_id)["passive_bonus"] == 1.0
    resp = api_client.post(f"/careers/{career_id}/inventory/estate-villa/equip")
    assert resp.status_code == 409 and resp.json()["code"] == "item_not_equippable"


def test_equip_errors(api_client, created_career):
    career_id = created_career["career_id"]
    resp = api_client.post(f"/careers/{career_id}/inventory/acc-swiss-watch/equip")
    assert resp.status_code == 404 and resp.json()["code"] == "item_not_owned"


def test_the_database_refuses_two_equipped_rows_in_a_slot(db_conn, career_id):
    """INV-66 lives in the partial unique index, not only in domain code."""
    for item_id in ("a", "b"):
        db_conn.execute(
            "INSERT INTO inventory (career_id, item_id, purchased_at, price_paid, upkeep_weekly, "
            "slot, grade, equipped) VALUES (?, ?, '2026-08-01', 0, 0, 'watch', 1, 0)",
            (career_id, item_id),
        )
    db_conn.execute("UPDATE inventory SET equipped = 1 WHERE item_id = 'a'")
    with pytest.raises(sqlite3.IntegrityError):
        db_conn.execute("UPDATE inventory SET equipped = 1 WHERE item_id = 'b'")


# --- grant-only items ----------------------------------------------------

def test_a_grant_only_item_cannot_be_bought(api_client, created_career):
    career_id = created_career["career_id"]
    grant_money(career_id, 100000)
    resp = _buy(api_client, career_id, "special-foundation")
    assert resp.status_code == 409 and resp.json()["code"] == "item_not_for_sale"


def test_grant_hands_over_the_item_once_and_for_free(db_conn, career_id):
    row = inventory.grant(db_conn, career_id, "special-foundation", "2026-09-01")
    assert row["equipped"] is True and row["slot"] == "foundation"
    assert inventory.grant(db_conn, career_id, "special-foundation", "2026-09-01") is None
    paid = db_conn.execute(
        "SELECT price_paid FROM inventory WHERE item_id = 'special-foundation'"
    ).fetchone()["price_paid"]
    assert paid == 0


def test_grant_refuses_an_item_that_is_for_sale(db_conn, career_id):
    with pytest.raises(ValueError):
        inventory.grant(db_conn, career_id, "acc-swiss-watch", "2026-09-01")


def test_grant_item_effect_reaches_the_inventory_through_t2(api_client, created_career, monkeypatch):
    """The effect dispatch is shared by T2, T6 and the social accept/attend
    paths; drive it through T2 with a patched lifestyle row."""
    from catalog.lifestyle import LIFESTYLE_ITEMS

    career_id = created_career["career_id"]
    item = next(i for i in LIFESTYLE_ITEMS if i["catalog_id"] == "sos-arkadas")
    monkeypatch.setitem(item, "effects", {**item["effects"], "grant_item:special-signed-jersey": 1})
    monkeypatch.setitem(item, "event_chance", 0)
    resp = api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": "sos-arkadas"})
    assert resp.status_code == 200, resp.json()
    assert [g["catalog_id"] for g in resp.json()["granted_items"]] == ["special-signed-jersey"]
    assert "special-signed-jersey" in _items(api_client, career_id)


# --- legacy rows (D81) ---------------------------------------------------

def _own_legacy(conn, career_id, item_id, price):
    conn.execute(
        "INSERT INTO inventory (career_id, item_id, purchased_at, price_paid, upkeep_weekly) "
        "VALUES (?, ?, '2026-08-01', ?, 0)",
        (career_id, item_id, price),
    )


def test_reconcile_converts_the_mappable_and_refunds_the_rest(db_conn, career_id):
    wallet.apply(db_conn, career_id, 1000, "sale", "seed", "2026-01-01")
    _own_legacy(db_conn, career_id, "personal-watch", 85)       # -> acc-smart-watch
    _own_legacy(db_conn, career_id, "personal-boots", 45)       # refunded
    _own_legacy(db_conn, career_id, "estate-flat", 3200)        # untouched
    before = wallet.get_balance(db_conn, career_id)

    assert legacy_items.reconcile(db_conn) == 2

    rows = {r["catalog_id"]: r for r in inventory.list_items(db_conn, career_id)}
    assert set(rows) == {"acc-smart-watch", "estate-flat"}
    assert rows["acc-smart-watch"]["equipped"] and rows["acc-smart-watch"]["price_paid"] == 85
    assert wallet.get_balance(db_conn, career_id) == before + 45
    assert wallet.ledger_total(db_conn, career_id) == wallet.get_balance(db_conn, career_id)  # INV-19
    assert legacy_items.reconcile(db_conn) == 0                 # idempotent


def test_mapped_legacy_row_counts_toward_the_bonus(db_conn, career_id):
    _own_legacy(db_conn, career_id, "personal-suit", 60)
    legacy_items.reconcile(db_conn)
    expected = gear_by_id("cloth-tailored-suit")["passive_effects"]["attribute:charisma"]
    assert attributes.passive_bonus(db_conn, career_id, "charisma") == expected
