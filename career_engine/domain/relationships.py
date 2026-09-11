"""§3.4 D23/D24 - the single write path for relationship.score, plus
per-kind validation of the traits JSON column (INV-16).

Only three kinds have a documented trait shape in CONTRACT.md §3.4 (coach,
media, partner); team and family are left open (extra fields allowed,
nothing required) until their dialogue content is written. INV-16 still
applies to them - traits must be a dict - just against a permissive model.
"""
import json
import sqlite3
from typing import List, Optional, Type

from pydantic import BaseModel, ConfigDict

from api import errors
from worlddata.relationships import STARTING_SCORES


class _BaseTraits(BaseModel):
    # D23 - hobbies replaces the removed relationship_hobby table; it's a
    # trait like any other, not specific to one kind.
    hobbies: List[str] = []


class CoachTraits(_BaseTraits):
    trust: float = 50.0
    promised_minutes: int = 0
    tactical_fit: float = 0.5


class MediaTraits(_BaseTraits):
    outlet: str = ""
    tone: str = "nötr"
    interviews_given: int = 0


class PartnerTraits(_BaseTraits):
    together_since: Optional[str] = None
    gift_count: int = 0
    mood: str = ""


class _OpenTraits(_BaseTraits):
    """team/family/fans - no shape pinned down yet, so anything validates."""
    model_config = ConfigDict(extra="allow")


KIND_TRAIT_MODELS: dict = {
    "coach": CoachTraits,
    "media": MediaTraits,
    "partner": PartnerTraits,
    "team": _OpenTraits,
    "fans": _OpenTraits,
    "family": _OpenTraits,
}


def validate_traits(kind: str, traits: dict) -> dict:
    """Raises ApiError(invalid_request) - not a bare pydantic error - so
    every caller gets a §9-shaped response."""
    model_cls = KIND_TRAIT_MODELS.get(kind)
    if model_cls is None:
        raise errors.invalid_request(f"unknown relationship kind {kind!r}")
    try:
        validated = model_cls(**traits)
    except Exception as exc:  # pydantic.ValidationError
        raise errors.invalid_request(f"invalid traits for kind {kind!r}: {exc}") from exc
    return validated.model_dump()


# Bounds for the numeric traits apply_trait_delta may move. A trait not
# listed here cannot be nudged by a delta at all - the string ones (outlet,
# tone, mood) are set, not incremented, and there is no caller for that yet.
#
# `trust` shares relationship.score's 0-100 range on purpose: they are read
# side by side (a coach who trusts you at 80 while the relationship sits at
# 30 should be legible at a glance) and a second scale would make the pair
# unreadable.
TRAIT_BOUNDS: dict = {
    "trust": (0.0, 100.0),
    "tactical_fit": (0.0, 1.0),
    "promised_minutes": (0, 95),
    "interviews_given": (0, None),
    "gift_count": (0, None),
}


def apply_trait_delta(
    conn: sqlite3.Connection,
    career_id: str,
    relationship_id: str,
    **deltas,
) -> list:
    """The only function allowed to write relationship.traits.

    Before this, `traits` was written exactly once - by onboarding's seed -
    and read forever after, which made CoachTraits.trust dead data: a field
    the contract described, the API returned, and nothing could ever move.

    Built like apply_delta above and like wallet.apply/fame.apply: one
    function owns the column, clamps, and hands back a before/after record.
    It does not commit; the calling endpoint owns the transaction (INV-3).

    The round trip goes through validate_traits twice - once to read, once
    to write - so INV-16 holds on both sides and a partial JSON blob picks
    up its model defaults before any arithmetic touches it. That matters:
    an older row written before a field existed would otherwise KeyError
    here rather than starting from the documented default.
    """
    row = conn.execute(
        "SELECT kind, traits FROM relationship WHERE career_id = ? AND relationship_id = ?",
        (career_id, relationship_id),
    ).fetchone()
    if row is None:
        raise errors.invalid_request(f"unknown relationship_id {relationship_id!r}")

    kind = row["kind"]
    traits = validate_traits(kind, json.loads(row["traits"]))

    changes = []
    for key, delta in deltas.items():
        if key not in traits:
            raise errors.invalid_request(f"kind {kind!r} has no trait {key!r}")
        if key not in TRAIT_BOUNDS:
            raise errors.invalid_request(f"trait {key!r} is not numeric")

        low, high = TRAIT_BOUNDS[key]
        before = traits[key]
        after = before + delta
        if low is not None:
            after = max(low, after)
        if high is not None:
            after = min(high, after)
        traits[key] = after
        # The applied delta, not the requested one - same honesty rule
        # apply_delta follows for the score's audit trail.
        changes.append({"key": key, "before": before, "after": after, "delta": after - before})

    conn.execute(
        "UPDATE relationship SET traits = ? WHERE career_id = ? AND relationship_id = ?",
        (json.dumps(validate_traits(kind, traits), ensure_ascii=False), career_id, relationship_id),
    )
    return changes


def get_traits(conn: sqlite3.Connection, career_id: str, relationship_id: str) -> dict:
    row = conn.execute(
        "SELECT kind, traits FROM relationship WHERE career_id = ? AND relationship_id = ?",
        (career_id, relationship_id),
    ).fetchone()
    if row is None:
        raise errors.invalid_request(f"unknown relationship_id {relationship_id!r}")
    return validate_traits(row["kind"], json.loads(row["traits"]))


def get_score(conn: sqlite3.Connection, career_id: str, relationship_id: str) -> int:
    row = conn.execute(
        "SELECT score FROM relationship WHERE career_id = ? AND relationship_id = ?",
        (career_id, relationship_id),
    ).fetchone()
    return row["score"]


def apply_delta(
    conn: sqlite3.Connection,
    career_id: str,
    relationship_id: str,
    delta: int,
    reason: str,
    happened_at: str,
    touches_contact: bool = True,
) -> dict:
    """The only function allowed to write relationship.score (INV-15).
    Clamps to 0-100 and logs the delta actually applied (post-clamp), not
    the requested one, so relationship_event stays an honest record.

    touches_contact controls last_contact_at: a genuine interaction (a
    dialogue choice, a shared match) should bump it; a decay tick (§6.5
    reason='decay') must NOT — updating it would erase the very staleness
    signal that triggered the decay, so it could never escalate.
    """
    current = get_score(conn, career_id, relationship_id)
    new_score = max(0, min(100, current + delta))
    applied_delta = new_score - current

    if touches_contact:
        conn.execute(
            "UPDATE relationship SET score = ?, last_contact_at = ? "
            "WHERE career_id = ? AND relationship_id = ?",
            (new_score, happened_at, career_id, relationship_id),
        )
    else:
        conn.execute(
            "UPDATE relationship SET score = ? WHERE career_id = ? AND relationship_id = ?",
            (new_score, career_id, relationship_id),
        )

    conn.execute(
        "INSERT INTO relationship_event (career_id, relationship_id, happened_at, delta, reason) "
        "VALUES (?, ?, ?, ?, ?)",
        (career_id, relationship_id, happened_at, applied_delta, reason),
    )
    return {
        "relationship_id": relationship_id,
        "before": current,
        "after": new_score,
        "delta": applied_delta,
    }


def replay_score(
    conn: sqlite3.Connection,
    career_id: str,
    relationship_id: str,
    base_score: Optional[int] = None,
) -> int:
    """Sums relationship_event from base_score, clamping at each step the
    same way apply_delta does. Used by tests to check the stored score
    never drifts from its own audit trail.

    base_score defaults to the kind's own §4 starting score rather than a
    flat 50 — since starting scores went per-kind, a single default would
    silently mis-replay every kind but 'team'."""
    if base_score is None:
        row = conn.execute(
            "SELECT kind FROM relationship WHERE career_id = ? AND relationship_id = ?",
            (career_id, relationship_id),
        ).fetchone()
        base_score = STARTING_SCORES[row["kind"]] if row is not None else 0

    rows = conn.execute(
        "SELECT delta FROM relationship_event "
        "WHERE career_id = ? AND relationship_id = ? ORDER BY happened_at",
        (career_id, relationship_id),
    ).fetchall()
    score = base_score
    for row in rows:
        score = max(0, min(100, score + row["delta"]))
    return score
