"""§5.7 D42 - the attribute gate. A catalog item or a dialogue leaf may
carry a `requires` map (attribute_key -> minimum level, §3.2 D43); this
module is the single place that decides whether a career clears it.

Shaped after day_budget.spend()'s check-then-act discipline, minus the
act: check() reads and either returns or raises, it never writes. That is
what lets every caller run it FIRST, before any cost is deducted — an
action whose threshold isn't met can't have eaten the day's time (INV-30).
"""
import sqlite3

from api import errors
from domain import attributes


def unmet(levels: dict, requires: dict) -> dict:
    """The subset of `requires` the given levels don't satisfy, as
    {key: (current_level, required_level)}. Pure, so the ordering rule and
    the comparison itself are testable without a database."""
    return {
        key: (levels.get(key, 0), required)
        for key, required in requires.items()
        if levels.get(key, 0) < required
    }


def check(
    conn: sqlite3.Connection, career_id: str, player_id: str, requires: dict = None
) -> None:
    """Raises requirement_not_met for the FIRST unsatisfied attribute, in
    the order the catalog author wrote them — a stable, authored order beats
    a "lowest first" rule nobody asked for, and FE shows the whole `requires`
    map anyway (it never has to reconstruct the list from one error).

    An empty or missing map is satisfied by definition: the field is
    optional, and its absence means "no gate", not "gate with no keys".
    """
    if not requires:
        return
    for key, required in requires.items():
        current = attributes.level(attributes.get_value(conn, career_id, player_id, key))
        if current < required:
            raise errors.requirement_not_met(key, required, current)
