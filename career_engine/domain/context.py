"""§14.7 - what an item means beyond its grade.

The design doc's gear notes are mostly context: a coat that only works in winter,
a sports car that turns on you when the team is losing, a camera crew that makes a
post go further, a channel that puts out content every week. This module is the
single reader of `catalog/shop.py::ITEM_CONTEXT`; everything else asks it.

**Derived, never stored (INV-60's reasoning).** Whether the coat counts is a
function of today's date and whether the car hurts is a function of the last three
results; neither is written anywhere, so nothing has to be taken back when winter
ends or the streak breaks - which is also what keeps INV-22 intact (no attribute
ever falls on its own; a passive bonus is a read-side layer).

Only worn items count (domain/inventory.contributing_ids), like every other
passive.
"""
import random
import sqlite3
from typing import List

from domain import form, inventory


def _context(item_id: str) -> dict:
    from catalog.shop import ITEM_CONTEXT  # local, like attributes' shop import

    return ITEM_CONTEXT.get(item_id, {})


def _game_month(conn: sqlite3.Connection, career_id: str) -> int:
    return int(conn.execute(
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"][5:7])


def passive_factor(conn: sqlite3.Connection, career_id: str, item_ids: List[str]) -> dict:
    """{item_id: factor} for the worn items whose passive bonus is not simply
    itself right now: 0 out of season, -1 in bad form. Items with no context, or
    whose context does not apply, are absent (factor 1).

    Cheap by design: this runs on every effective-attribute read, so the date and
    the results are only fetched if a worn item actually carries that context."""
    factors = {}
    month = None
    in_bad_form = None
    for item_id in item_ids:
        context = _context(item_id)
        if "months" in context:
            month = _game_month(conn, career_id) if month is None else month
            if month not in context["months"]:
                factors[item_id] = 0.0
        if "bad_form" in context:
            in_bad_form = form.losing_streak(conn, career_id) if in_bad_form is None else in_bad_form
            if in_bad_form:
                factors[item_id] = -1.0
    return factors


def boost_effects(conn: sqlite3.Connection, career_id: str, item: dict, effects: dict) -> dict:
    """Multiplies the positive skill gains of a lifestyle activity by every worn
    item that boosts it (by id or by group). A loss is never boosted, and nothing
    but `attribute:` keys is: a stream kit makes a broadcast teach more, it does not
    make it pay more."""
    factor = 1.0
    group = f"group:{item.get('group')}"
    for item_id in inventory.contributing_ids(conn, career_id):
        boosts = _context(item_id).get("boosts", {})
        factor *= boosts.get(item["catalog_id"], 1.0) * boosts.get(group, 1.0)
    if factor == 1.0:
        return effects
    return {
        key: round(value * factor, 3)
        if key.startswith("attribute:") and value is not None and value > 0 else value
        for key, value in effects.items()
    }


def bad_form_headlines(conn: sqlite3.Connection, career_id: str) -> List[dict]:
    """The headline each worn flashy item earns when a bad run is on - one per
    item, from its own `bad_form` story. The caller decides when to ask (right
    after a defeat) and writes them."""
    if not form.losing_streak(conn, career_id):
        return []
    return [
        {"item_id": item_id, **_context(item_id)["bad_form"]}
        for item_id in inventory.contributing_ids(conn, career_id)
        if "bad_form" in _context(item_id)
    ]


def acquire_story(item_id: str):
    """The headline buying `item_id` makes, or None."""
    return _context(item_id).get("news_on_acquire")


def weekly_headlines(conn: sqlite3.Connection, career_id: str, on_date: str, seed: int) -> List[dict]:
    """One headline per worn content-producing item, picked by the career seed and
    the date (INV-7): the same career replayed gets the same channel."""
    out = []
    for item_id in inventory.contributing_ids(conn, career_id):
        stories = _context(item_id).get("weekly_news")
        if stories:
            rng = random.Random(f"{seed}:weekly_news:{item_id}:{on_date}")
            out.append({"item_id": item_id, **rng.choice(stories)})
    return out
