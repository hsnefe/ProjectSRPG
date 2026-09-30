"""§5.7's effect key space, applied through each value's own single write path.

It used to live in api/routers/time.py (extracted from post_action when T6 became
a second caller). §14.5-§14.6 make a third and fourth caller that are not
endpoints at all - an ignored event's `on_ignore` and a due deferred consequence
both run inside the day loop - so it moved down to the domain layer, where the
day loop can reach it without importing a router. time.py re-exports it under its
old name; api/routers/social.py still keeps its own older copy.

Note what it does NOT do: spend budget, check requirements or commit. Callers
own the order (gate, then budget, then this) and the transaction.
"""
import sqlite3

from api import config
from catalog import grant_item_id
from domain import attributes, condition, day_budget, fame, inventory, tactics, wallet
from domain import relationships as relationships_domain


def apply(
    conn: sqlite3.Connection,
    career_id: str,
    effects: dict,
    source: str,
    reason: str,
    happened_at: str,
    clamp_money: bool = False,
) -> dict:
    """Applies `effects` and returns what changed, bucketed by kind.

    `clamp_money` is for callers that run where a refusal cannot be answered: a
    consequence that comes due in the middle of an advance must not turn the whole
    day into an `insufficient_funds` error, so a loss is taken up to the balance
    and no further (the same rule T2's fail_effects follow, D85)."""
    out = {
        "attribute_changes": [],
        "tactic_changes": [],
        "relationship_changes": [],
        "ledger_entries": [],
        "granted_items": [],
    }
    for key, value in effects.items():
        if value is None:
            continue  # ⟦AÇIK-9⟧ etc. — placeholder effect, not active yet
        granted_id = grant_item_id(key)
        if granted_id is not None:
            # §14.2 D82 - a story item changes hands. No money moves and the
            # row is priced at 0; an already-owned item is simply not granted
            # twice, so a repeated event cannot fail mid-transaction.
            row = inventory.grant(conn, career_id, granted_id, happened_at[:10])
            if row is not None:
                out["granted_items"].append(row)
            continue
        if key.startswith("attribute:"):
            out["attribute_changes"].append(
                attributes.apply_delta(conn, career_id, config.USER_PLAYER_ID, key.split(":", 1)[1], value)
            )
        elif key.startswith("tactic:"):
            out["tactic_changes"].append(
                tactics.apply_delta(conn, career_id, config.USER_PLAYER_ID, key.split(":", 1)[1], value)
            )
        elif key == "condition":
            condition.apply_delta(conn, career_id, value)
        elif key == "energy":
            day_budget.add(conn, career_id, "energy", value, ceiling=config.DAY_BUDGET_DEFAULTS.get("energy"))
        elif key == "money":
            if clamp_money and value < 0:
                value = max(value, -wallet.get_balance(conn, career_id))
            if value != 0:
                out["ledger_entries"].append(wallet.apply(conn, career_id, value, source, reason, happened_at))
        elif key.startswith("fame:"):
            fame.apply(conn, career_id, config.USER_PLAYER_ID, value, reason, happened_at, scope=key.split(":", 1)[1])
        elif key.startswith("relationship:"):
            out["relationship_changes"].append(
                relationships_domain.apply_delta(
                    conn, career_id, key.split(":", 1)[1], value, reason, happened_at, touches_contact=True
                )
            )
        elif key == "sponsorship:end":
            # §14.6 - a brand walks away. The oldest active deal breaks; there is
            # no charge and no obligation clean-up beyond voiding what it booked,
            # the same ending sponsorship.skip() gives a no-show minus the media hit
            # (the event that scheduled this already decided that).
            _end_oldest_deal(conn, career_id)
    return out


def _end_oldest_deal(conn: sqlite3.Connection, career_id: str) -> None:
    row = conn.execute(
        "SELECT deal_id FROM sponsorship_deal WHERE career_id = ? AND status = 'active' "
        "ORDER BY signed_on, deal_id LIMIT 1",
        (career_id,),
    ).fetchone()
    if row is None:
        return
    conn.execute(
        "UPDATE sponsorship_deal SET status = 'broken' WHERE career_id = ? AND deal_id = ?",
        (career_id, row["deal_id"]),
    )
    conn.execute(
        "UPDATE sponsorship_obligation SET status = 'missed' "
        "WHERE career_id = ? AND deal_id = ? AND status = 'pending'",
        (career_id, row["deal_id"]),
    )
