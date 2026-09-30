"""§3.1 D15/D38 - the single write path for career_state.condition, and
(since §6.6 made the daily rate depend on owned items) the single read path
for how much one advanced day is worth.
Bounded above by player_attribute['condition'] (INV-10) and below by 0.

Not the match engine's own 35 floor (INV-25) — that only bounds the value
M2 writes back after a match. Day-to-day life (a bad night out, an unpaid
upkeep week) can take condition lower than 35; only a match itself can't."""
import sqlite3

from api import config
from domain import housing, inventory


def get_ceiling(conn: sqlite3.Connection, career_id: str) -> float:
    row = conn.execute(
        "SELECT value FROM player_attribute WHERE career_id = ? AND player_id = ? AND attribute_key = 'condition'",
        (career_id, config.USER_PLAYER_ID),
    ).fetchone()
    return row["value"] if row is not None else 100.0


def daily_recovery(
    conn: sqlite3.Connection, career_id: str, on_date: str = None, seed: int = None
) -> dict:
    """§6.3/§6.6 - how much condition one advanced day is worth right now:
    the active residence's sleep (§14.4 D88) plus its modifiers plus every worn
    item's daily_effects['condition'], capped at
    config.MAX_CONDITION_RECOVERY_PER_DAY (INV-41).

    `on_date`/`seed` are for the roommate-noise roll (domain/housing.py): pass the
    night being asked about and the roll is thrown exactly as the day loop throws
    it; leave them out and the nominal sleep comes back with the chance reported.

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

    home = housing.recovery_parts(conn, career_id, on_date, seed)
    base = home["sleep"]
    modifiers = sum(m["amount"] for m in home["modifiers"])
    sources = []
    for item_id in inventory.contributing_ids(conn, career_id):  # §14.2: worn rows only
        amount = DAILY_CONDITION_BONUS.get(item_id)
        if amount:
            sources.append({
                "item_id": item_id,
                # The title travels so the hub can name the source without a
                # second N3 fetch; it is authored catalog text, not an
                # assembled sentence (§1.3).
                "title": titles.get(item_id, item_id),
                "amount": amount,
            })
    sources.sort(key=lambda s: (-s["amount"], s["item_id"]))

    # `bonus` stays "everything above the base", so the hub's "+N from items"
    # line keeps meaning what it meant; the home's own adjustments ride in it and
    # are itemised under `modifiers` for the morning forecast.
    bonus = modifiers + sum(s["amount"] for s in sources)
    uncapped = base + bonus
    total = max(0, min(uncapped, config.MAX_CONDITION_RECOVERY_PER_DAY))
    return {
        "base": base,
        "bonus": bonus,
        "total": total,
        "capped": total < uncapped,
        "sources": sources,
        # §14.4 - where the base came from and what the night did to it.
        "residence": home["residence"],
        "modifiers": home["modifiers"],
        "noise": home["noise"],
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
