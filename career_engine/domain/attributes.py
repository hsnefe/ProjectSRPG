"""§3.2 D30 - the single write path for player_attribute.value. Same shape
as wallet.apply()/relationships.apply_delta(): clamps to 0-100. No event
log here (unlike money/relationships/fame) — CONTRACT.md doesn't call for
a per-attribute audit trail; activity_log.applied_effects (T2) and R3's
own response body already carry what changed and why."""
import sqlite3


def get_value(conn: sqlite3.Connection, career_id: str, player_id: str, attribute_key: str) -> float:
    row = conn.execute(
        "SELECT value FROM player_attribute WHERE career_id = ? AND player_id = ? AND attribute_key = ?",
        (career_id, player_id, attribute_key),
    ).fetchone()
    return row["value"] if row is not None else 0.0


def apply_delta(
    conn: sqlite3.Connection, career_id: str, player_id: str, attribute_key: str, delta: float
) -> dict:
    current = get_value(conn, career_id, player_id, attribute_key)
    new_value = max(0.0, min(100.0, current + delta))
    conn.execute(
        "UPDATE player_attribute SET value = ? "
        "WHERE career_id = ? AND player_id = ? AND attribute_key = ?",
        (new_value, career_id, player_id, attribute_key),
    )
    return {"key": attribute_key, "before": current, "after": new_value}
