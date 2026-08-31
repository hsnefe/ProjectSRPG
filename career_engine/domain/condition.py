"""§3.1 D15/D38 - the single write path for career_state.condition, and
(since §6.6 made the daily rate depend on owned items) the single read path
for how much one advanced day is worth.
Bounded above by player_attribute['condition'] (INV-10) and below by 0.

Not the match engine's own 35 floor (INV-25) — that only bounds the value
M2 writes back after a match. Day-to-day life (a bad night out, an unpaid
upkeep week) can take condition lower than 35; only a match itself can't."""
import sqlite3

from api import config


def get_ceiling(conn: sqlite3.Connection, career_id: str) -> float:
    row = conn.execute(
        "SELECT value FROM player_attribute WHERE career_id = ? AND player_id = ? AND attribute_key = 'condition'",
        (career_id, config.USER_PLAYER_ID),
    ).fetchone()
    return row["value"] if row is not None else 100.0


def daily_recovery(conn: sqlite3.Connection, career_id: str) -> dict:
    """§6.3/§6.6 - how much condition one advanced day is worth right now:
    the flat base plus every owned item's daily_effects['condition'], capped
    at config.MAX_CONDITION_RECOVERY_PER_DAY (INV-41).

    This is the single READ path for that number, the way apply_delta() is
    the single write path. T1 reports it and daytime.process_day() applies
    it, so the "+8 bugün" the player is shown and the delta they actually
    get cannot disagree — the failure mode of computing it twice.

    Note what this does NOT do: it never touches the attribute ceiling. The
    bonus changes the SIZE of the delta, never the clamp, so a player at
    their ceiling with every item in the shop still stays at the ceiling
    (INV-10)."""
    from catalog.shop import DAILY_CONDITION_BONUS, SHOP_ITEMS  # local, like daytime._item_title

    titles = {i["catalog_id"]: i["title"] for i in SHOP_ITEMS}

    base = config.NATURAL_CONDITION_RECOVERY_PER_DAY
    rows = conn.execute(
        "SELECT item_id FROM inventory WHERE career_id = ?", (career_id,)
    ).fetchall()

    sources = []
    for row in rows:
        amount = DAILY_CONDITION_BONUS.get(row["item_id"])
        if amount:
            sources.append({
                "item_id": row["item_id"],
                # The title travels so the hub can name the source without a
                # second N3 fetch; it is authored catalog text, not an
                # assembled sentence (§1.3).
                "title": titles.get(row["item_id"], row["item_id"]),
                "amount": amount,
            })
    sources.sort(key=lambda s: (-s["amount"], s["item_id"]))

    bonus = sum(s["amount"] for s in sources)
    uncapped = base + bonus
    total = min(uncapped, config.MAX_CONDITION_RECOVERY_PER_DAY)
    return {
        "base": base,
        "bonus": bonus,
        "total": total,
        "capped": total < uncapped,
        "sources": sources,
    }


def apply_delta(conn: sqlite3.Connection, career_id: str, delta: float) -> int:
    current = conn.execute(
        "SELECT condition FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["condition"]
    ceiling = get_ceiling(conn, career_id)
    new_value = max(0, min(round(current + delta), round(ceiling)))
    conn.execute("UPDATE career_state SET condition = ? WHERE career_id = ?", (new_value, career_id))
    return new_value


def set_from_match(conn: sqlite3.Connection, career_id: str, final_condition: int) -> int:
    """§6.6 M2 - final_condition already passed validation (35-100, not
    above pre-match condition); this still re-clamps to the attribute
    ceiling (INV-10) as a defensive floor, same bound apply_delta uses."""
    ceiling = get_ceiling(conn, career_id)
    new_value = max(35, min(round(final_condition), round(ceiling)))
    conn.execute("UPDATE career_state SET condition = ? WHERE career_id = ?", (new_value, career_id))
    return new_value
