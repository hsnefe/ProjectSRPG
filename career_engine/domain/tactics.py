"""§12.11 D63 - the single write path for player_tactics.value. Same clamp
shape as attributes.apply_delta(); no event log for the same reason
attributes.py has none (CONTRACT.md doesn't call for a per-tactic audit
trail, and activity_log.applied_effects already carries what changed and
why via T2)."""
import sqlite3


def get_value(conn: sqlite3.Connection, career_id: str, player_id: str, tactic_key: str) -> float:
    row = conn.execute(
        "SELECT value FROM player_tactics WHERE career_id = ? AND player_id = ? AND tactic_key = ?",
        (career_id, player_id, tactic_key),
    ).fetchone()
    return row["value"] if row is not None else 0.0


def apply_delta(
    conn: sqlite3.Connection, career_id: str, player_id: str, tactic_key: str, delta: float
) -> dict:
    current = get_value(conn, career_id, player_id, tactic_key)
    new_value = max(0.0, min(100.0, current + delta))
    # Upsert, not a plain UPDATE: unlike player_attribute, player_tactics
    # rows aren't seeded at career creation (015_player_tactics.sql), so the
    # first training session for a given tactic has no row to update yet.
    conn.execute(
        "INSERT INTO player_tactics (career_id, player_id, tactic_key, value) VALUES (?, ?, ?, ?) "
        "ON CONFLICT (career_id, player_id, tactic_key) DO UPDATE SET value = excluded.value",
        (career_id, player_id, tactic_key, new_value),
    )
    return {"key": tactic_key, "before": current, "after": new_value}
