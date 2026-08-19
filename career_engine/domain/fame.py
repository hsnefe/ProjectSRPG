"""§3.2 D35 - the single write path for player_fame.value.

Same shape as wallet.apply() and relationships.apply_delta(): the value is
stored, fame_event is the audit trail, and both are written only here, in
the caller's transaction (INV-24). What actually produces fame deltas -
and what fame even means beyond a raw number - is AÇIK-9, still open; this
module doesn't need that answered to be correct, it just needs a place for
the number to live once something calls it."""
import sqlite3


def get_value(conn: sqlite3.Connection, career_id: str, player_id: str, scope: str = "overall") -> float:
    row = conn.execute(
        "SELECT value FROM player_fame WHERE career_id = ? AND player_id = ? AND scope = ?",
        (career_id, player_id, scope),
    ).fetchone()
    return row["value"] if row is not None else 0.0


def apply(
    conn: sqlite3.Connection,
    career_id: str,
    player_id: str,
    delta: float,
    reason: str,
    happened_at: str,
    scope: str = "overall",
) -> dict:
    """Upserts player_fame (a career's first fame event has no prior row)
    and logs fame_event in the same transaction. No floor/ceiling is
    enforced here — AÇIK-9 hasn't decided whether fame is bounded."""
    current = get_value(conn, career_id, player_id, scope)
    new_value = current + delta

    conn.execute(
        "INSERT INTO player_fame (career_id, player_id, scope, value) VALUES (?, ?, ?, ?) "
        "ON CONFLICT (career_id, player_id, scope) DO UPDATE SET value = excluded.value",
        (career_id, player_id, scope, new_value),
    )
    conn.execute(
        "INSERT INTO fame_event (career_id, player_id, scope, happened_at, delta, reason) "
        "VALUES (?, ?, ?, ?, ?, ?)",
        (career_id, player_id, scope, happened_at, delta, reason),
    )
    return {
        "scope": scope,
        "happened_at": happened_at,
        "delta": delta,
        "reason": reason,
        "value_after": new_value,
    }
