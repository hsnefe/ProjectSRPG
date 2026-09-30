"""§14.2 D80-D82 - what a career owns, and which of it is switched on.

Ownership (`inventory` rows) and contribution are different questions since
gear arrived. A row contributes its passive and daily effects iff it has no slot
(estate, investment: always on) or it is the `equipped` row of its slot. Upkeep
is the opposite: every owned row is paid for whether it is worn or not
(daytime.py sums `inventory.upkeep_weekly` over all rows) - a coat in the
wardrobe still cost money, and making upkeep stop on unequip would turn equip
into a free sell.

This module is the only place that decides "what contributes": attributes,
condition and the day loop all ask `contributing_ids()` instead of reading
`inventory` themselves, so the rule lives once.
"""
import sqlite3
from typing import Optional

from api import errors


def contributing_ids(conn: sqlite3.Connection, career_id: str) -> list:
    """Item ids whose passive/daily effects count right now."""
    rows = conn.execute(
        "SELECT item_id FROM inventory WHERE career_id = ? AND (slot IS NULL OR equipped = 1)",
        (career_id,),
    ).fetchall()
    return [row["item_id"] for row in rows]


def list_items(conn: sqlite3.Connection, career_id: str) -> list:
    rows = conn.execute(
        "SELECT item_id, slot, grade, equipped, purchased_at, price_paid, upkeep_weekly "
        "FROM inventory WHERE career_id = ? ORDER BY purchased_at, item_id",
        (career_id,),
    ).fetchall()
    return [
        {
            "catalog_id": r["item_id"], "slot": r["slot"], "grade": r["grade"],
            "equipped": bool(r["equipped"]), "purchased_at": r["purchased_at"],
            "price_paid": r["price_paid"], "upkeep_weekly": r["upkeep_weekly"],
        }
        for r in rows
    ]


def _slot_is_free(conn: sqlite3.Connection, career_id: str, slot: str) -> bool:
    return conn.execute(
        "SELECT 1 FROM inventory WHERE career_id = ? AND slot = ? AND equipped = 1",
        (career_id, slot),
    ).fetchone() is None


def add(conn: sqlite3.Connection, career_id: str, item: dict, on_date: str, price_paid: int) -> dict:
    """Inserts an owned row from a catalog `item`. A gear row is worn straight
    away when its slot is empty; when the slot is taken it stays in the
    wardrobe, because silently swapping what the player chose to wear would be
    the worse surprise. Does not commit (INV-3) and does not touch money - the
    caller owns the wallet call (a grant has none)."""
    slot = item.get("slot")
    equipped = 1 if slot is not None and _slot_is_free(conn, career_id, slot) else 0
    conn.execute(
        "INSERT INTO inventory (career_id, item_id, purchased_at, price_paid, upkeep_weekly, "
        "weekly_return, slot, grade, equipped) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (
            career_id, item["catalog_id"], on_date, price_paid, item["upkeep_weekly"],
            round(item["price"] * item.get("weekly_return_rate", 0)),
            slot, item.get("grade"), equipped,
        ),
    )
    return {"catalog_id": item["catalog_id"], "slot": slot, "grade": item.get("grade"),
            "equipped": bool(equipped)}


def grant(conn: sqlite3.Connection, career_id: str, catalog_id: str, on_date: str) -> Optional[dict]:
    """D82 - hands over a story item for free. Returns None when it is already
    owned (an event that fires twice must not error halfway through a
    transaction); raises on an id the catalog does not know or one that is
    for sale, since that is a content bug, not a player state."""
    from catalog.shop import gear_by_id

    item = gear_by_id(catalog_id)
    if item is None or item.get("acquire") != "grant":
        raise ValueError(f"grant_item:{catalog_id} is not a grant-only catalog item")
    owned = conn.execute(
        "SELECT 1 FROM inventory WHERE career_id = ? AND item_id = ?", (career_id, catalog_id)
    ).fetchone()
    if owned:
        return None
    return add(conn, career_id, item, on_date, 0)


def _owned_row(conn: sqlite3.Connection, career_id: str, item_id: str):
    row = conn.execute(
        "SELECT slot, equipped FROM inventory WHERE career_id = ? AND item_id = ?",
        (career_id, item_id),
    ).fetchone()
    if row is None:
        raise errors.item_not_owned(item_id)
    if row["slot"] is None:
        raise errors.item_not_equippable(item_id)
    return row


def equip(conn: sqlite3.Connection, career_id: str, item_id: str) -> None:
    """Wears `item_id`, taking off whatever held its slot (INV-66). Idempotent."""
    row = _owned_row(conn, career_id, item_id)
    conn.execute(
        "UPDATE inventory SET equipped = 0 WHERE career_id = ? AND slot = ? AND item_id != ?",
        (career_id, row["slot"], item_id),
    )
    conn.execute(
        "UPDATE inventory SET equipped = 1 WHERE career_id = ? AND item_id = ?", (career_id, item_id)
    )


def unequip(conn: sqlite3.Connection, career_id: str, item_id: str) -> None:
    _owned_row(conn, career_id, item_id)
    conn.execute(
        "UPDATE inventory SET equipped = 0 WHERE career_id = ? AND item_id = ?", (career_id, item_id)
    )
