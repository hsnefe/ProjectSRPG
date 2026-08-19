"""§3.1 D15/D38 - the single write path for career_state.condition.
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
