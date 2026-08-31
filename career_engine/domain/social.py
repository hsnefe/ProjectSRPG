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

Like every other domain module: nothing here commits. The router does, once
(INV-3).
"""
import datetime as _dt
import random
import sqlite3
from typing import List, Optional

from api import config
from api.ids import new_social_offer_id
from content.social_offers import SOCIAL_OFFERS
from domain import requirements

_BY_ID = {t["template_id"]: t for t in SOCIAL_OFFERS}

DECISIONS = ("accept", "decline")


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
    offer_id = new_social_offer_id()
    conn.execute(
        "INSERT INTO social_offer (career_id, offer_id, template_id, relationship_id, "
        "opened_on, status, resolved_on) VALUES (?, ?, ?, ?, ?, 'open', NULL)",
        (career_id, offer_id, tpl["template_id"], tpl["relationship_id"], on_date),
    )
    return get(conn, career_id, offer_id)


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
