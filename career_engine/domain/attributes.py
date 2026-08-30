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


def level(value: float) -> int:
    """§3.2 D43 - the raw 0-100 value's readable face, 0-10. One decade per
    level, so the equivalence a requirement is checked with stays exact and
    reversible: level N <=> value >= 10 * N. 74.0 -> 7, 100.0 -> 10, 4.0 -> 0.

    The eleventh bucket (level 0, for anything under 10) is deliberate:
    folding 0..9 up into level 1 would break that equivalence, and every
    `requires` threshold is written against it.

    This function is the ONLY place the scale lives — P1 ships the derived
    level alongside the raw value precisely so FE never re-implements it.
    """
    return int(value // 10)


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
