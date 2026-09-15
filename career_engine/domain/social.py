"""§5.4 R4-R6, §6.3 D53 - the single write path for `social_offer`.

An offer is one paragraph and two buttons that the day loop puts in front of
the player. It exists because the six relationships (§3.4) were otherwise
entirely player-initiated: you could talk to the coach, but the coach never
asked you for anything, so a relationship you ignored simply sat there.

Three rules shape everything below.

**At most one offer is open at a time (INV-39).** Not a queue. The advance
loop stops on an offer and the player answers it, so a second one can only
arrive after the first is resolved. A queue would turn a modal into a list
and let a week's worth of ignored offers land at once.

**The answer is mandatory (D53).** An open offer blocks `POST /advance`
outright. That is why there is no expiry: a state reachable only by refusing
to answer, when refusing to answer is impossible, is a state nothing can
test.

**Declining always works (INV-40).** It checks no requirement, spends no
budget and touches no balance. A mandatory answer with a failable escape
hatch is a soft-lock waiting for a player with an empty wallet.

A template with `plan_days_ahead` (§12.8, D58) is the one exception to
"answered means resolved": accepting still applies `relationship_delta` on
the spot, but its `costs`/`effects` move to a `social_plan` row due on a
later day instead of applying here and now — see the plan functions below.

Like every other domain module: nothing here commits. The router does, once
(INV-3).
"""
import datetime as _dt
import random
import sqlite3
from typing import List, Optional

from api import config
from api.ids import (
    new_social_conflict_id,
    new_social_offer_id,
    new_social_plan_id,
)
from content.social_offers import SOCIAL_OFFERS
from domain import requirements

_BY_ID = {t["template_id"]: t for t in SOCIAL_OFFERS}

DECISIONS = ("accept", "decline")

PLAN_PENDING = "pending"
PLAN_DONE = "done"
PLAN_MISSED = "missed"

# §12.8/D58 - what missing a plan you already said yes to costs. Bigger than
# any template's own decline delta (those run -1 to -5): breaking a promise
# reads worse than never having made one, the same relationship sponsorship
# obligations already put on a missed appearance (MISSED_MEDIA_DELTA).
MISSED_PLAN_RELATIONSHIP_DELTA = -12

CONFLICT_OPEN = "open"
CONFLICT_RESOLVED = "resolved"
CONFLICT_PLAN = "plan"
CONFLICT_OFFER = "offer"

# §12.9/D59 - what showing up to the one you picked is worth. In a plan
# conflict the template's own `accept` delta was already paid the day the
# offer was accepted (§12.8), so without this the chosen side would move by
# zero and the screen would show one bar falling and none rising. Flat rather
# than per-template: what is being rewarded is choosing, and that is the same
# act whichever evening it was.
CHOSEN_CONFLICT_RELATIONSHIP_DELTA = 4


def template(template_id: str) -> Optional[dict]:
    """The authored row behind a stored offer. None for an id the content
    file no longer carries — a career can hold an offer written by an
    earlier version of that file."""
    return _BY_ID.get(template_id)


def _row_to_offer(row: sqlite3.Row) -> dict:
    """A stored row plus the authored text it points at. The deltas stay
    behind: R4 serves what the player reads and the gate they must clear,
    never the payoff (catalog/dialogue.public_catalog()'s split)."""
    tpl = template(row["template_id"]) or {}
    return {
        "offer_id": row["offer_id"],
        "template_id": row["template_id"],
        "relationship_id": row["relationship_id"],
        "opened_on": row["opened_on"],
        "status": row["status"],
        "resolved_on": row["resolved_on"],
        "title": tpl.get("title", ""),
        "body": tpl.get("body", ""),
        "accept_label": tpl.get("accept_label", ""),
        "decline_label": tpl.get("decline_label", ""),
        "costs": tpl.get("costs", {}),
        "requires": tpl.get("requires", {}),
    }


def get(conn: sqlite3.Connection, career_id: str, offer_id: str) -> Optional[dict]:
    row = conn.execute(
        "SELECT * FROM social_offer WHERE career_id = ? AND offer_id = ?",
        (career_id, offer_id),
    ).fetchone()
    return _row_to_offer(row) if row else None


def list_open(conn: sqlite3.Connection, career_id: str) -> List[dict]:
    rows = conn.execute(
        "SELECT * FROM social_offer WHERE career_id = ? AND status = 'open' "
        "ORDER BY opened_on ASC, offer_id ASC",
        (career_id,),
    ).fetchall()
    return [_row_to_offer(r) for r in rows]


def pending_by_relationship(conn: sqlite3.Connection, career_id: str) -> set:
    """Which relationship ids have an offer waiting, in one query — R1 draws
    six cards and must not run six lookups to do it (relationships.peak_scores
    makes the same trade)."""
    rows = conn.execute(
        "SELECT DISTINCT relationship_id FROM social_offer "
        "WHERE career_id = ? AND status = 'open'",
        (career_id,),
    ).fetchall()
    return {r["relationship_id"] for r in rows}


def _weighted_pick(rng: random.Random, candidates: List[dict]) -> dict:
    """Deterministic weighted choice over an already-ordered list.

    Local rather than borrowed from the news layer's sampler: that one is
    private and carries cooldown/arc concerns this does not have, and sharing
    it would tie two content systems' randomness together — the same seed
    would stop meaning the same thing on either side.
    """
    total = sum(t["weight"] for t in candidates)
    roll = rng.random() * total
    upto = 0.0
    for t in candidates:
        upto += t["weight"]
        if roll < upto:
            return t
    return candidates[-1]  # float drift only


def _eligible(
    conn: sqlite3.Connection, career_id: str, on_date: str, scores: dict
) -> List[dict]:
    last_opened_cache = {}

    def last_opened(template_id: str) -> Optional[str]:
        if template_id not in last_opened_cache:
            row = conn.execute(
                "SELECT MAX(opened_on) AS last FROM social_offer "
                "WHERE career_id = ? AND template_id = ?",
                (career_id, template_id),
            ).fetchone()
            last_opened_cache[template_id] = row["last"]
        return last_opened_cache[template_id]

    today = _dt.date.fromisoformat(on_date)
    out = []
    for tpl in SOCIAL_OFFERS:
        score = scores.get(tpl["relationship_id"])
        if score is None or not tpl["min_score"] <= score <= tpl["max_score"]:
            continue
        last = last_opened(tpl["template_id"])
        if last and (today - _dt.date.fromisoformat(last)).days < tpl["cooldown_days"]:
            continue
        # D42 read as eligibility rather than enforcement: an offer the player
        # could only decline is not an offer, it is a notification.
        if not requirements.met(conn, career_id, config.USER_PLAYER_ID, tpl.get("requires")):
            continue
        out.append(tpl)
    return out


def maybe_generate(
    conn: sqlite3.Connection, career_id: str, on_date: str, seed: int
) -> Optional[dict]:
    """One day's chance of an offer. Cheapest checks first, the way the news
    layer rolls its trigger chance before touching the database — a quiet day
    should cost one comparison, not a table scan.

    Deterministic from the career's own seed (INV-7): the same career
    replayed to the same date produces the same offer.
    """
    if conn.execute(
        "SELECT 1 FROM social_offer WHERE career_id = ? AND status = 'open' LIMIT 1",
        (career_id,),
    ).fetchone():
        return None  # INV-39

    rng = random.Random(f"{seed}:social:{on_date}")
    if rng.random() >= config.SOCIAL_OFFER_DAILY_CHANCE:
        return None

    scores = {
        r["relationship_id"]: r["score"]
        for r in conn.execute(
            "SELECT relationship_id, score FROM relationship WHERE career_id = ?",
            (career_id,),
        ).fetchall()
    }
    candidates = _eligible(conn, career_id, on_date, scores)
    if not candidates:
        return None

    tpl = _weighted_pick(rng, candidates)
    return get(conn, career_id, _insert_offer(conn, career_id, tpl, on_date))


def _insert_offer(
    conn: sqlite3.Connection, career_id: str, tpl: dict, on_date: str
) -> str:
    """One `social_offer` row from a chosen template. Extracted because §12.9's
    conflict roll opens two of them in a breath and the INSERT should have one
    author."""
    offer_id = new_social_offer_id()
    conn.execute(
        "INSERT INTO social_offer (career_id, offer_id, template_id, relationship_id, "
        "opened_on, status, resolved_on) VALUES (?, ?, ?, ?, ?, 'open', NULL)",
        (career_id, offer_id, tpl["template_id"], tpl["relationship_id"], on_date),
    )
    return offer_id


def resolve(
    conn: sqlite3.Connection, career_id: str, offer_id: str, decision: str, on_date: str
) -> dict:
    """Flips an open offer to accepted/declined. Writes nothing else — the
    router applies the branch's effects through their own single write paths
    (relationships.apply_delta, wallet.apply, condition.apply_delta), because
    owning them here would make this a second writer for four tables it has
    no business in.

    Callers MUST already have checked that the offer is open and, for accept,
    that the gate and the budget clear. This is the last step, not the first.
    """
    assert decision in DECISIONS, decision
    conn.execute(
        "UPDATE social_offer SET status = ?, resolved_on = ? "
        "WHERE career_id = ? AND offer_id = ?",
        ("accepted" if decision == "accept" else "declined", on_date, career_id, offer_id),
    )
    return get(conn, career_id, offer_id)


# --- social plans (§12.8, D58) --------------------------------------------
#
# A `plan_days_ahead` template's accept doesn't resolve on the spot: it
# schedules one of these, due on a later day, that the player has to attend
# or skip once that day arrives. Single write path for the `social_plan`
# table, the way `resolve()` above is for `social_offer` — the router still
# owns applying `costs`/`effects` (INV-3: one transaction, and those belong
# to wallet/condition/attributes/day_budget's own single write paths, not
# this module's).

def _row_to_plan(row: sqlite3.Row) -> dict:
    tpl = template(row["template_id"]) or {}
    return {
        "plan_id": row["plan_id"],
        "offer_id": row["offer_id"],
        "template_id": row["template_id"],
        "relationship_id": row["relationship_id"],
        "due_on": row["due_on"],
        "status": row["status"],
        "title": tpl.get("title", ""),
        "body": tpl.get("body", ""),
        "costs": tpl.get("costs", {}),
    }


def get_plan(conn: sqlite3.Connection, career_id: str, plan_id: str) -> Optional[dict]:
    row = conn.execute(
        "SELECT * FROM social_plan WHERE career_id = ? AND plan_id = ?",
        (career_id, plan_id),
    ).fetchone()
    return _row_to_plan(row) if row else None


def list_due_plans(conn: sqlite3.Connection, career_id: str, on_date: str) -> List[dict]:
    """Every plan due today or overdue — overdue only possible in the moment
    between a day rolling over and the player answering, since the advance
    gate stops time until they do (mirrors sponsorship.pending_obligations)."""
    rows = conn.execute(
        "SELECT * FROM social_plan WHERE career_id = ? AND status = ? AND due_on <= ? "
        "ORDER BY due_on ASC, plan_id ASC",
        (career_id, PLAN_PENDING, on_date),
    ).fetchall()
    return [_row_to_plan(r) for r in rows]


def create_plan(
    conn: sqlite3.Connection, career_id: str, offer_id: str, template_id: str,
    relationship_id: str, due_on: str,
) -> dict:
    plan_id = new_social_plan_id()
    conn.execute(
        "INSERT INTO social_plan (career_id, plan_id, offer_id, template_id, "
        "relationship_id, due_on, status) VALUES (?, ?, ?, ?, ?, ?, ?)",
        (career_id, plan_id, offer_id, template_id, relationship_id, due_on, PLAN_PENDING),
    )
    return get_plan(conn, career_id, plan_id)


def mark_plan_done(conn: sqlite3.Connection, career_id: str, plan_id: str) -> None:
    conn.execute(
        "UPDATE social_plan SET status = ? WHERE career_id = ? AND plan_id = ?",
        (PLAN_DONE, career_id, plan_id),
    )


def mark_plan_missed(conn: sqlite3.Connection, career_id: str, plan_id: str) -> None:
    conn.execute(
        "UPDATE social_plan SET status = ? WHERE career_id = ? AND plan_id = ?",
        (PLAN_MISSED, career_id, plan_id),
    )


# --- social conflicts (§12.9, D59) -----------------------------------------
#
# Two invitations for the same evening and one player. The row below stores
# the dilemma itself; the two halves stay where they already live, in
# `social_plan` or `social_offer`, and `source` says which.
#
# Two ways one is born, and they are deliberately lopsided:
#
#   - `plan`  - two plans fall due on the same day. CERTAIN, no dice. Both
#               were promised, so the one dropped takes the full missed-plan
#               penalty (-12).
#   - `offer` - a day with no plan due rolls SOCIAL_CONFLICT_DAILY_CHANCE and
#               opens TWO offers instead of one. Nobody was promised anything,
#               so the one turned down only takes its template's own `decline`
#               delta (-1 to -5). This is the narrowing of INV-39: at most one
#               open offer, OR one conflict pair.
#
# The resolution spends nothing (D60). A mandatory answer that can fail on
# budget is INV-40's soft-lock with extra steps.

def _conflict_side(
    conn: sqlite3.Connection, career_id: str, source: str, ref_id: str
) -> Optional[dict]:
    """One half, read out of whichever table `source` names. The two shapes
    are flattened to the same keys here so the router and FE never branch on
    `source` to read a name."""
    if source == CONFLICT_PLAN:
        row = get_plan(conn, career_id, ref_id)
        key = "plan_id"
    else:
        row = get(conn, career_id, ref_id)
        key = "offer_id"
    if row is None:
        return None
    return {
        "ref_id": row[key],
        "relationship_id": row["relationship_id"],
        "template_id": row["template_id"],
        "title": row["title"],
        "body": row["body"],
    }


def _row_to_conflict(conn: sqlite3.Connection, career_id: str, row: sqlite3.Row) -> dict:
    sides = [
        _conflict_side(conn, career_id, row["source"], row[col])
        for col in ("left_ref", "right_ref")
    ]
    return {
        "conflict_id": row["conflict_id"],
        "source": row["source"],
        "due_on": row["due_on"],
        "status": row["status"],
        "chosen_ref": row["chosen_ref"],
        "sides": [s for s in sides if s is not None],
    }


def get_conflict(
    conn: sqlite3.Connection, career_id: str, conflict_id: str
) -> Optional[dict]:
    row = conn.execute(
        "SELECT * FROM social_conflict WHERE career_id = ? AND conflict_id = ?",
        (career_id, conflict_id),
    ).fetchone()
    return _row_to_conflict(conn, career_id, row) if row else None


def list_open_conflicts(conn: sqlite3.Connection, career_id: str) -> List[dict]:
    rows = conn.execute(
        "SELECT * FROM social_conflict WHERE career_id = ? AND status = ? "
        "ORDER BY due_on ASC, conflict_id ASC",
        (career_id, CONFLICT_OPEN),
    ).fetchall()
    return [_row_to_conflict(conn, career_id, r) for r in rows]


def open_conflict(conn: sqlite3.Connection, career_id: str) -> Optional[dict]:
    """The one open conflict, if any. Singular by construction: every creation
    path below refuses to add a second while one is open, the same way INV-39
    keeps offers to one."""
    conflicts = list_open_conflicts(conn, career_id)
    return conflicts[0] if conflicts else None


def conflict_member_refs(conn: sqlite3.Connection, career_id: str) -> set:
    """Every ref currently locked inside an open conflict.

    Two callers, both of which would otherwise count the same evening twice:
    the day loop suppresses the members' own `social_offer`/`social_plan_due`
    events so the day stops once, and the single-answer endpoints refuse a ref
    that appears here (INV-53)."""
    rows = conn.execute(
        "SELECT left_ref, right_ref FROM social_conflict WHERE career_id = ? AND status = ?",
        (career_id, CONFLICT_OPEN),
    ).fetchall()
    return {r["left_ref"] for r in rows} | {r["right_ref"] for r in rows}


def _create_conflict(
    conn: sqlite3.Connection, career_id: str, source: str, due_on: str,
    left_ref: str, right_ref: str,
) -> dict:
    conflict_id = new_social_conflict_id()
    conn.execute(
        "INSERT INTO social_conflict (career_id, conflict_id, source, due_on, "
        "left_ref, right_ref, status, chosen_ref) VALUES (?, ?, ?, ?, ?, ?, ?, NULL)",
        (career_id, conflict_id, source, due_on, left_ref, right_ref, CONFLICT_OPEN),
    )
    return get_conflict(conn, career_id, conflict_id)


def conflict_for_today(
    conn: sqlite3.Connection, career_id: str, on_date: str
) -> Optional[dict]:
    """The conflict standing in the player's way today, creating the plan-vs-plan
    one on first ask.

    **Lazy and sticky**, the way §12.2 decides squad status: the first caller
    computes it, the row is written, everyone after reads it. T1's event list
    and T3's door gate have to agree about the same evening - deciding afresh
    on each call would let the calendar show a conflict the gate does not know
    about. It rolls no dice, so there is nothing to keep deterministic here;
    the stickiness is about the two callers, not about the seed.

    Three plans due at once take the first two in the order `list_due_plans`
    already fixes; the third stays a plain pending plan and gets its turn once
    this conflict is answered.
    """
    existing = open_conflict(conn, career_id)
    if existing:
        return existing

    due = list_due_plans(conn, career_id, on_date)
    if len(due) < 2:
        return None
    return _create_conflict(
        conn, career_id, CONFLICT_PLAN, on_date, due[0]["plan_id"], due[1]["plan_id"]
    )


def maybe_generate_conflict(
    conn: sqlite3.Connection, career_id: str, on_date: str, seed: int
) -> Optional[dict]:
    """The other source: two people inviting you to the same evening without
    knowing about each other.

    Rolled on its own namespace (`:social_conflict:`) rather than by drawing
    more numbers from `maybe_generate`'s stream - an extra draw there would
    shift the template every existing seeded test picks, and the two rolls
    genuinely are independent questions.

    Skipped entirely on a day that already has a plan due: that day's conflict
    is the certain one, and `conflict_for_today` owns it.
    """
    if open_conflict(conn, career_id):
        return None
    if conn.execute(
        "SELECT 1 FROM social_offer WHERE career_id = ? AND status = 'open' LIMIT 1",
        (career_id,),
    ).fetchone():
        return None  # INV-39
    if list_due_plans(conn, career_id, on_date):
        return None

    rng = random.Random(f"{seed}:social_conflict:{on_date}")
    if rng.random() >= config.SOCIAL_CONFLICT_DAILY_CHANCE:
        return None

    scores = {
        r["relationship_id"]: r["score"]
        for r in conn.execute(
            "SELECT relationship_id, score FROM relationship WHERE career_id = ?",
            (career_id,),
        ).fetchall()
    }
    candidates = _eligible(conn, career_id, on_date, scores)
    if not candidates:
        return None

    first = _weighted_pick(rng, candidates)
    # The rival has to be a different person - "choose between the coach and
    # the coach" is not a dilemma, it is a bug.
    rivals = [t for t in candidates if t["relationship_id"] != first["relationship_id"]]
    if not rivals:
        return None
    second = _weighted_pick(rng, rivals)

    return _create_conflict(
        conn, career_id, CONFLICT_OFFER, on_date,
        _insert_offer(conn, career_id, first, on_date),
        _insert_offer(conn, career_id, second, on_date),
    )


def resolve_conflict(
    conn: sqlite3.Connection, career_id: str, conflict_id: str, chosen_ref: str
) -> dict:
    conn.execute(
        "UPDATE social_conflict SET status = ?, chosen_ref = ? "
        "WHERE career_id = ? AND conflict_id = ?",
        (CONFLICT_RESOLVED, chosen_ref, career_id, conflict_id),
    )
    return get_conflict(conn, career_id, conflict_id)
