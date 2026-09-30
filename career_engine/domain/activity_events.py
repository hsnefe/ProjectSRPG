"""§13.4 D75/D76 - the single write path for `activity_event`.

An event is a paragraph and N buttons that a lifestyle action puts in front
of the player: someone recognises you in the cafe, a reporter is waiting at
the end of the run. It exists because a lifestyle action was otherwise a
sum: pick a row, pay the cost, take the effect, done. Nothing that happened
during the two hours could ever be about anything.

Three rules shape everything below, and two of them are the opposite of
domain/social.py's.

**At most one event is open at a time (INV-62).** Same as INV-39, same
reason: a modal is not a queue.

**The answer is NOT mandatory (D76).** An open event does not block
`POST /advance`. A social plan is a promise — somebody is waiting, so the
day cannot close around it — but a cafe conversation lives inside the moment
it happened in. Advancing past it expires it (INV-63): the event goes to
`expired` and writes nothing at all.

**Which means it CAN expire**, and domain/social.py's comment about why
offers have no expiry ("a state reachable only by refusing to answer, when
refusing to answer is impossible, is a state nothing can test") reads in
reverse here — this state is reachable by simply walking away, which is
exactly what makes it worth having.

Like every other domain module: nothing here commits. The router does, once
(INV-3).
"""
import random
import sqlite3
from typing import List, Optional

from api import config
from api.ids import new_activity_event_id
from content.activity_events import for_catalog, option as template_option, template
from domain import effects, requirements

OPEN = "open"
RESOLVED = "resolved"
EXPIRED = "expired"


def _row_to_event(row: sqlite3.Row) -> dict:
    """A stored row plus the authored text it points at.

    The payoff stays behind — an option's `effects` and `starts_relationship`
    never leave this module, the same split catalog/dialogue.public_catalog()
    and domain/social._row_to_offer() both draw. `requires` and `costs` DO
    travel: D42 says the player sees the gate before choosing, not after.
    """
    tpl = template(row["template_id"]) or {}
    return {
        "event_id": row["event_id"],
        "template_id": row["template_id"],
        "catalog_id": row["catalog_id"],
        "opened_on": row["opened_on"],
        "status": row["status"],
        "chosen_option": row["chosen_option"],
        "resolved_on": row["resolved_on"],
        "title": tpl.get("title", ""),
        "body": tpl.get("body", ""),
        "options": [
            {
                "option_id": opt["option_id"],
                "label": opt["label"],
                "requires": opt.get("requires", {}),
                "costs": opt.get("costs", {}),
            }
            for opt in tpl.get("options", [])
        ],
    }


def get(conn: sqlite3.Connection, career_id: str, event_id: str) -> Optional[dict]:
    row = conn.execute(
        "SELECT * FROM activity_event WHERE career_id = ? AND event_id = ?",
        (career_id, event_id),
    ).fetchone()
    return _row_to_event(row) if row else None


def list_open(conn: sqlite3.Connection, career_id: str) -> List[dict]:
    rows = conn.execute(
        "SELECT * FROM activity_event WHERE career_id = ? AND status = ? "
        "ORDER BY opened_on ASC, event_id ASC",
        (career_id, OPEN),
    ).fetchall()
    return [_row_to_event(r) for r in rows]


def _weighted_pick(rng: random.Random, candidates: List[dict]) -> dict:
    """Deterministic weighted choice over an already-ordered list.

    A copy of domain/social._weighted_pick rather than an import of it, for
    the reason that one already gives for not borrowing the news sampler:
    sharing a picker ties two content systems' randomness together, and the
    same seed would stop meaning the same thing on either side the day one
    of them grows a cooldown the other does not want.
    """
    total = sum(t["weight"] for t in candidates)
    roll = rng.random() * total
    upto = 0.0
    for t in candidates:
        upto += t["weight"]
        if roll < upto:
            return t
    return candidates[-1]  # float drift only


def maybe_generate(
    conn: sqlite3.Connection,
    career_id: str,
    catalog_id: str,
    item: dict,
    on_date: str,
    seed: int,
) -> Optional[dict]:
    """One action's chance of an event. Cheapest checks first, the way
    social.maybe_generate and the news layer both roll before touching the
    database.

    Deterministic from the career's own seed plus the date AND the activity
    (INV-7): the same career replayed the same way meets the same stranger.
    The catalog_id is in the key so that doing two different activities on
    one day does not roll the same number twice.
    """
    if conn.execute(
        "SELECT 1 FROM activity_event WHERE career_id = ? AND status = ? LIMIT 1",
        (career_id, OPEN),
    ).fetchone():
        return None  # INV-62

    chance = item.get("event_chance", config.ACTIVITY_EVENT_DEFAULT_CHANCE)
    rng = random.Random(f"{seed}:activity_event:{on_date}:{catalog_id}")
    if rng.random() >= chance:
        return None

    candidates = [
        tpl for tpl in for_catalog(catalog_id)
        # D42 read as eligibility rather than enforcement, social._eligible's
        # rule: an event whose every option the player fails is a notification,
        # not an event. The per-OPTION gates are enforced later, at choose().
        if requirements.met(conn, career_id, config.USER_PLAYER_ID, tpl.get("requires"))
    ]
    if not candidates:
        return None

    tpl = _weighted_pick(rng, candidates)
    event_id = new_activity_event_id()
    conn.execute(
        "INSERT INTO activity_event (career_id, event_id, template_id, catalog_id, "
        "opened_on, status, chosen_option, resolved_on) VALUES (?, ?, ?, ?, ?, ?, NULL, NULL)",
        (career_id, event_id, tpl["template_id"], catalog_id, on_date, OPEN),
    )
    return get(conn, career_id, event_id)


def option_for(template_id: str, option_id: str) -> Optional[dict]:
    """The authored option, payoff included. The router needs the half
    _row_to_event withholds; this is the only way to get it."""
    return template_option(template_id, option_id)


def resolve(
    conn: sqlite3.Connection, career_id: str, event_id: str, option_id: str, on_date: str
) -> dict:
    """Flips an open event to resolved. Writes nothing else — the router
    applies the option's effects through their own single write paths, for
    the reason domain/social.resolve() spells out: owning them here would
    make this a second writer for four tables it has no business in.

    Callers MUST already have checked that the event is open, that the option
    belongs to it, and that the gate and the budget clear. This is the last
    step, not the first.
    """
    conn.execute(
        "UPDATE activity_event SET status = ?, chosen_option = ?, resolved_on = ? "
        "WHERE career_id = ? AND event_id = ?",
        (RESOLVED, option_id, on_date, career_id, event_id),
    )
    return get(conn, career_id, event_id)


def expire_open(conn: sqlite3.Connection, career_id: str, on_date: Optional[str] = None) -> List[str]:
    """INV-63 - D76's other half. Called from the advance loop: whatever the
    player walked away from is gone, and gone WITHOUT applying anything -
    except (§14.5) for a relationship event that says what ignoring it costs.
    Forgetting your mother's birthday is a choice too, and `on_ignore` is how a
    template says so; every other event still writes nothing.

    `on_date` is only needed to stamp that cost; a caller with no date (a test
    asserting the row moved) gets the plain INV-63 behaviour.

    Returns the expired ids so the caller can report them; T3 does not today,
    because an event the player ignored is not news. The list exists so a
    test can assert the row moved rather than reading the table itself.
    """
    rows = conn.execute(
        "SELECT event_id, template_id FROM activity_event WHERE career_id = ? AND status = ?",
        (career_id, OPEN),
    ).fetchall()
    if not rows:
        return []
    conn.execute(
        "UPDATE activity_event SET status = ? WHERE career_id = ? AND status = ?",
        (EXPIRED, career_id, OPEN),
    )
    if on_date is not None:
        for row in rows:
            cost = (template(row["template_id"]) or {}).get("on_ignore")
            if cost:
                # clamp_money: nobody can answer an `insufficient_funds` here.
                effects.apply(
                    conn, career_id, cost, "lifestyle", f"event_ignored:{row['template_id']}",
                    f"{on_date}T08:00:00+03:00", clamp_money=True,
                )
    return [r["event_id"] for r in rows]
