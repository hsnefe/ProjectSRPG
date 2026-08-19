"""§3.1/§6.2 D41 - day_budget: the day's spendable pool. spend() is the
check+deduct write path (INV-4: raises before touching any row if any
resource can't cover its cost); refill() resets every resource to its
daily default (INV-29)."""
import sqlite3

from api import config, errors


def get_all(conn: sqlite3.Connection, career_id: str) -> dict:
    rows = conn.execute(
        "SELECT resource_key, remaining FROM day_budget WHERE career_id = ?", (career_id,)
    ).fetchall()
    return {r["resource_key"]: r["remaining"] for r in rows}


def spend(conn: sqlite3.Connection, career_id: str, costs: dict) -> None:
    """Raises insufficient_budget for the first resource that can't cover
    its cost. Checks every resource before writing any of them, so a
    partial spend never happens."""
    current = get_all(conn, career_id)
    for key, amount in costs.items():
        if current.get(key, 0.0) < amount:
            raise errors.insufficient_budget(key)
    for key, amount in costs.items():
        conn.execute(
            "UPDATE day_budget SET remaining = remaining - ? WHERE career_id = ? AND resource_key = ?",
            (amount, career_id, key),
        )


def add(conn: sqlite3.Connection, career_id: str, resource_key: str, amount: float, ceiling: float = None) -> None:
    """For effects that top up a resource (e.g. 'energy' from sleeping).
    Clamped to [0, ceiling] if a ceiling is given."""
    current = get_all(conn, career_id).get(resource_key, 0.0)
    new_value = max(0.0, current + amount)
    if ceiling is not None:
        new_value = min(new_value, ceiling)
    conn.execute(
        "UPDATE day_budget SET remaining = ? WHERE career_id = ? AND resource_key = ?",
        (new_value, career_id, resource_key),
    )


def refill(conn: sqlite3.Connection, career_id: str) -> None:
    for key, amount in config.DAY_BUDGET_DEFAULTS.items():
        conn.execute(
            "INSERT INTO day_budget (career_id, resource_key, remaining) VALUES (?, ?, ?) "
            "ON CONFLICT (career_id, resource_key) DO UPDATE SET remaining = excluded.remaining",
            (career_id, key, amount),
        )
