"""§14.2 D81 - what becomes of the pre-§14 shop rows a career already owns.

The personal-*/home-* items were replaced by the design doc's gear. A career
that bought one keeps a row whose id is no longer in the catalog, and such a
row contributes nothing: the player would have paid for a thing that silently
stopped working. So each one either becomes its nearest new item (same
`price_paid`, now slotted and worn) or is paid back in full.

Money moves through wallet.apply() like every other movement (INV-17), which is
why this is not SQL in a migration: a migration cannot write the ledger.
reconcile() is idempotent - once a legacy row is gone there is nothing left for
it to find - and runs at startup right after the migrations.
"""
import sqlite3

from domain import inventory, wallet

# Nearest honest equivalent. A console has no successor in the gear list, a
# treadmill belongs to the housing phase's home gym, and the old boots were a
# stat stick with no slot - those three are refunded.
LEGACY_TO_NEW = {
    "personal-watch": "acc-smart-watch",
    "personal-suit": "cloth-tailored-suit",
    "personal-headphones": "tech-earbuds",
    "home-tv": "home-cinema",
    "home-espresso": "home-coffee-machine",
}
LEGACY_REFUNDED = ("personal-boots", "home-console", "home-treadmill")


def reconcile(conn: sqlite3.Connection) -> int:
    """Converts or refunds every legacy row in every career. Returns how many
    rows it touched. Commits once at the end."""
    from catalog.shop import gear_by_id

    ids = tuple(LEGACY_TO_NEW) + LEGACY_REFUNDED
    marks = ",".join("?" * len(ids))
    rows = conn.execute(
        f"SELECT i.career_id, i.item_id, i.price_paid, s.game_date "
        f"FROM inventory i JOIN career_state s USING (career_id) "
        f"WHERE i.item_id IN ({marks}) ORDER BY i.career_id, i.item_id",
        ids,
    ).fetchall()

    for row in rows:
        career_id, old_id = row["career_id"], row["item_id"]
        new_id = LEGACY_TO_NEW.get(old_id)
        new_item = gear_by_id(new_id) if new_id else None
        already_has_new = new_item is not None and conn.execute(
            "SELECT 1 FROM inventory WHERE career_id = ? AND item_id = ?", (career_id, new_id)
        ).fetchone()

        conn.execute("DELETE FROM inventory WHERE career_id = ? AND item_id = ?", (career_id, old_id))
        if new_item is not None and not already_has_new:
            inventory.add(conn, career_id, new_item, row["game_date"], row["price_paid"])
        elif row["price_paid"] > 0:
            wallet.apply(
                conn, career_id, row["price_paid"], "refund", f"legacy_item:{old_id}",
                f"{row['game_date']}T00:00:00+03:00",
            )
    conn.commit()
    return len(rows)
