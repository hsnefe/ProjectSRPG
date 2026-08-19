"""§3.5/§6.5 D25 - the single write path for career_state.money.

Every payment (wage, bonus, purchase, upkeep, sale — even a career's own
starting balance) must go through apply(). Nothing else may write
career_state.money (INV-17) or money_ledger directly, and both are written
in the same transaction the caller controls: apply() does not commit, so a
multi-step action (T2, M2, ...) can bundle several apply() calls plus
attribute/relationship writes into one all-or-nothing transaction (INV-3)."""
import sqlite3

from api import errors


def get_balance(conn: sqlite3.Connection, career_id: str) -> int:
    row = conn.execute(
        "SELECT money FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()
    return row["money"]


def apply(
    conn: sqlite3.Connection,
    career_id: str,
    amount: int,
    kind: str,
    reason: str,
    happened_at: str,
) -> dict:
    """Applies one money movement. amount is signed: positive for income,
    negative for spend. Raises ApiError(insufficient_funds) - and writes
    nothing - if a negative amount would take the balance below zero
    (INV-5). Returns a LedgerEntry-shaped dict (§5.0) for the caller to
    surface in its response."""
    current = get_balance(conn, career_id)
    new_balance = current + amount
    if new_balance < 0:
        raise errors.insufficient_funds()

    conn.execute(
        "UPDATE career_state SET money = ? WHERE career_id = ?",
        (new_balance, career_id),
    )
    conn.execute(
        "INSERT INTO money_ledger (career_id, happened_at, amount, kind, reason, balance_after) "
        "VALUES (?, ?, ?, ?, ?, ?)",
        (career_id, happened_at, amount, kind, reason, new_balance),
    )
    return {
        "happened_at": happened_at,
        "amount": amount,
        "kind": kind,
        "reason": reason,
        "balance_after": new_balance,
    }


def ledger_total(conn: sqlite3.Connection, career_id: str) -> int:
    """Sum of every money_ledger row for this career. Used by tests (and
    could be used by an admin/debug endpoint) to check INV-19: this must
    always equal career_state.money, because apply() is the only writer
    of either and it keeps them in lockstep by construction."""
    row = conn.execute(
        "SELECT COALESCE(SUM(amount), 0) AS total FROM money_ledger WHERE career_id = ?",
        (career_id,),
    ).fetchone()
    return row["total"]
