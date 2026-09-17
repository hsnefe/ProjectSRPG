"""§3.2 D30 - the single write path for player_attribute.value. Same shape
as wallet.apply()/relationships.apply_delta(): clamps to 0-100. No event
log here (unlike money/relationships/fame) — CONTRACT.md doesn't call for
a per-attribute audit trail; activity_log.applied_effects (T2) and R3's
own response body already carry what changed and why.

§13.3 D73 adds a SECOND number on the read side: an owned shop item can
carry a passive bonus on a kişi attribute (a tailored suit makes you read
as more polite). The stored value is untouched by it — passive_bonus() and
effective_value() derive it per read, while apply_delta() still writes only
the base (INV-60).

That split is the whole design. A stored bonus would have to be taken back
when the item is sold or repossessed (D29), and taking it back is the one
thing that would make an attribute fall on its own — exactly what INV-22
forbids. Derived, the question never comes up: the bonus is simply absent
from the next read.

Everything that ASKS a threshold reads the effective value (D73/INV-61):
domain/requirements.py, and through it every `requires` gate in the game.
"""
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


# --- §13.3: the passive layer ---------------------------------------------


def passive_bonus(conn: sqlite3.Connection, career_id: str, attribute_key: str) -> float:
    """What the career's owned items add to one attribute, right now.

    Unknown item ids contribute nothing, for the reason
    catalog.shop.daily_condition_bonus() already spells out: an item can be
    dropped from the catalog while an old career still holds its inventory
    row, and a KeyError there would break every attribute read rather than
    just the shop.
    """
    from catalog.shop import PASSIVE_ATTRIBUTE_BONUS  # local, like condition.daily_recovery

    rows = conn.execute(
        "SELECT item_id FROM inventory WHERE career_id = ?", (career_id,)
    ).fetchall()
    return sum(
        PASSIVE_ATTRIBUTE_BONUS.get(row["item_id"], {}).get(attribute_key, 0.0)
        for row in rows
    )


def effective_value(
    conn: sqlite3.Connection, career_id: str, player_id: str, attribute_key: str
) -> float:
    """Base + passive bonus, clamped to the same 0-100 the stored value uses.

    The clamp is here as well as in apply_delta on purpose: a base of 99
    plus a +2 suit must read as 100, not 101, or `level` would produce an
    eleventh bucket no `requires` threshold can express (catalog's
    MAX_REQUIREMENT_LEVEL is 10).
    """
    base = get_value(conn, career_id, player_id, attribute_key)
    return max(0.0, min(100.0, base + passive_bonus(conn, career_id, attribute_key)))


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
    # INV-60: only the base was written. INV-61: the levels reported below
    # must still come from the EFFECTIVE value, or a client updating its
    # local copy from this response would drift from the level P1 ships and
    # the one requirements.check() gates on. One read, reused for both.
    bonus = passive_bonus(conn, career_id, attribute_key)
    effective_before = max(0.0, min(100.0, current + bonus))
    effective_after = max(0.0, min(100.0, new_value + bonus))
    # The levels ride along for the same reason P1 ships one (D43): a client
    # that updates its local copy from this response would otherwise have to
    # re-derive the scale, and then FE would own a copy of the rule after all.
    # Most deltas move a value without moving its level; the caller sees that
    # for free instead of guessing.
    return {
        "key": attribute_key,
        "before": current,
        "after": new_value,
        # §13.3 - what the wardrobe is worth, so FE can rebuild
        # effective_value locally without re-fetching P1.
        "passive_bonus": bonus,
        "level_before": level(effective_before),
        "level_after": level(effective_after),
    }
