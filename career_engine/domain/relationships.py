"""§3.4 D23/D24 - the single write path for relationship.score, plus
per-kind validation of the traits JSON column (INV-16).

Only three kinds have a documented trait shape in CONTRACT.md §3.4 (coach,
media, partner); teammates and family are left open (extra fields allowed,
nothing required) until their dialogue content is written. INV-16 still
applies to them - traits must be a dict - just against a permissive model.
"""
import json
import sqlite3
from typing import List, Optional, Type

from pydantic import BaseModel, ConfigDict

from api import errors


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
    """teammates/family - no shape pinned down yet, so anything validates."""
    model_config = ConfigDict(extra="allow")


KIND_TRAIT_MODELS: dict = {
    "coach": CoachTraits,
    "media": MediaTraits,
    "partner": PartnerTraits,
    "teammates": _OpenTraits,
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


def replay_score(conn: sqlite3.Connection, career_id: str, relationship_id: str, base_score: int = 50) -> int:
    """Sums relationship_event from base_score, clamping at each step the
    same way apply_delta does. Used by tests to check the stored score
    never drifts from its own audit trail."""
    rows = conn.execute(
        "SELECT delta FROM relationship_event "
        "WHERE career_id = ? AND relationship_id = ? ORDER BY happened_at",
        (career_id, relationship_id),
    ).fetchall()
    score = base_score
    for row in rows:
        score = max(0, min(100, score + row["delta"]))
    return score
