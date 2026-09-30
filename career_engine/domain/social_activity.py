"""§14.3 D84/D85 - the parts of a social activity that are decided at the moment
it is done, not authored in the catalog: who it is done with, what that changes
about its effects, and whether a risky one goes wrong.

Everything here is a pure read or a pure computation; T2 (`api/routers/time.py`)
owns the order (gate, budget, effects, risk, log) and the transaction (INV-3).
"""
import random
import sqlite3
from typing import Optional

from api import config, errors
from domain import attributes, wallet
from domain import relationships as relationships_domain


def resolve_partner(
    conn: sqlite3.Connection, career_id: str, item: dict, relationship_id: Optional[str]
) -> Optional[str]:
    """Checks the request's `relationship_id` against the activity's `mode` and
    returns the kind to spend time with, or None for a solo run.

    Runs BEFORE the budget is spent: a request that cannot be honoured must not
    have cost the player a minute of the day (the same order D42's gate keeps).
    """
    mode = item.get("mode", "S")
    if mode == "S":
        if relationship_id is not None:
            raise errors.invalid_request(f"{item['catalog_id']!r} is done alone")
        return None
    if relationship_id is None:
        if mode == "B":
            raise errors.invalid_request(f"{item['catalog_id']!r} needs a relationship_id")
        return None
    if relationship_id not in item["with"]:
        raise errors.invalid_request(
            f"{item['catalog_id']!r} cannot be done with {relationship_id!r}, only {item['with']}"
        )
    # §13.2/INV-58: you cannot spend an evening with someone you have not met.
    if relationships_domain.get_state(conn, career_id, relationship_id) == config.STATE_ABSENT:
        raise errors.relationship_absent(relationship_id)
    return relationship_id


def effects_for(item: dict, relationship_id: Optional[str]) -> dict:
    """The effect map this particular run applies.

    With someone: the catalog's skill gain as authored, plus the relationship
    score. Alone (an S/B activity without a partner): the skill gain grows by
    SOLO_SKILL_BONUS and there is nobody to befriend - which is what makes
    choosing a partner a trade rather than a free bonus."""
    effects = dict(item["effects"])
    if item.get("mode", "S") == "S/B" and relationship_id is None:
        for key, value in effects.items():
            if key.startswith("attribute:") and value is not None:
                effects[key] = round(value * config.SOLO_SKILL_BONUS, 3)
    if relationship_id is not None:
        key = f"relationship:{relationship_id}"
        effects[key] = effects.get(key, 0) + item.get("with_delta", 0)
    return effects


def risk_chance(conn: sqlite3.Connection, career_id: str, risk: dict) -> float:
    """The authored chance, lowered by the mitigating skill's LEVEL (effective,
    D74/INV-61 - a watch that opens a gate also steadies a joke) and floored so
    no amount of skill makes a risky thing safe."""
    chance = risk["chance"]
    mitigation = risk.get("mitigated_by")
    if mitigation:
        value = attributes.effective_value(conn, career_id, config.USER_PLAYER_ID, mitigation["attribute"])
        chance -= mitigation["per_level"] * attributes.level(value)
    return max(config.MIN_RISK_CHANCE, chance)


def roll_risk(
    conn: sqlite3.Connection, career_id: str, item: dict, on_date: str, seed: int
) -> Optional[dict]:
    """None for a safe activity; otherwise {"chance", "failed"}.

    Seeded like activity_events (`Random(f"{seed}:...")`), with the number of
    times this activity has already been done today in the key: doing the same
    risky thing twice in a day is two rolls, but the same career replayed from
    the same seed always gets the same outcomes."""
    risk = item.get("risk")
    if not risk:
        return None
    done_today = conn.execute(
        "SELECT COUNT(*) AS n FROM activity_log WHERE career_id = ? AND catalog_id = ? "
        "AND happened_at LIKE ?",
        (career_id, item["catalog_id"], f"{on_date}%"),
    ).fetchone()["n"]
    chance = risk_chance(conn, career_id, risk)
    rng = random.Random(f"{seed}:activity_risk:{on_date}:{item['catalog_id']}:{done_today}")
    return {"chance": chance, "failed": rng.random() < chance}


def fail_effects_for(conn: sqlite3.Connection, career_id: str, item: dict) -> dict:
    """`risk.fail_effects`, with a money loss clamped to what the player has.
    The roll has already said "it went wrong"; answering that with
    insufficient_funds would turn a bad outcome into a rejected request."""
    effects = dict(item["risk"]["fail_effects"])
    loss = effects.get("money")
    if loss is not None and loss < 0:
        effects["money"] = max(loss, -wallet.get_balance(conn, career_id))
        if effects["money"] == 0:
            del effects["money"]  # nothing left to lose; do not write a 0 ledger row
    return effects


def merge_applied(base: dict, extra: dict) -> dict:
    """Folds a second `_apply_effects` result into the first, list by list."""
    for key, rows in extra.items():
        base[key].extend(rows)
    return base
