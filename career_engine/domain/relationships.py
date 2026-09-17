"""§3.4 D23/D24 - the single write path for relationship.score, plus
per-kind validation of the traits JSON column (INV-16).

Only three kinds have a documented trait shape in CONTRACT.md §3.4 (coach,
media, partner); team and family are left open (extra fields allowed,
nothing required) until their dialogue content is written. INV-16 still
applies to them - traits must be a dict - just against a permissive model.
"""
import json
import sqlite3
import zlib
from typing import List, Optional, Type

from pydantic import BaseModel, ConfigDict

from api import config, errors
from worlddata.relationships import (
    CLUB_STAFF_POOL,
    SCOPES,
    STARTING_SCORES,
    STARTING_STATES,
)


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


# --- §13.2 D71: relationship.state ----------------------------------------
#
# The machine runs for `partner` only (INV-59). Everything else is born
# STATE_ACTIVE and has no way to leave it, which is why set_state refuses a
# kind it wasn't written for rather than quietly widening the mechanic.


def get_state(conn: sqlite3.Connection, career_id: str, relationship_id: str) -> str:
    row = conn.execute(
        "SELECT state FROM relationship WHERE career_id = ? AND relationship_id = ?",
        (career_id, relationship_id),
    ).fetchone()
    if row is None:
        raise errors.invalid_request(f"unknown relationship_id {relationship_id!r}")
    return row["state"]


def set_state(
    conn: sqlite3.Connection, career_id: str, relationship_id: str, state: str
) -> Optional[dict]:
    """The only function allowed to write relationship.state — the same
    single-write-path rule score (INV-15) and traits (INV-42) already follow.

    Returns a before/after record, or None when the state was already what
    was asked for. A no-op returning None rather than a zero-change record
    is what lets the routers build `relationship_state_changes` by simply
    dropping the Nones: a list that only ever contains real transitions.
    """
    if state not in config.RELATIONSHIP_STATES:
        raise errors.invalid_request(f"unknown relationship state {state!r}")

    row = conn.execute(
        "SELECT kind, state FROM relationship WHERE career_id = ? AND relationship_id = ?",
        (career_id, relationship_id),
    ).fetchone()
    if row is None:
        raise errors.invalid_request(f"unknown relationship_id {relationship_id!r}")

    # INV-59. A kind with no lifecycle cannot be pushed into one by a
    # content file typo; the assert lives here rather than in the callers
    # because this is the only door.
    if row["kind"] != "partner":
        raise errors.invalid_request(
            f"relationship {relationship_id!r} (kind {row['kind']!r}) has no state machine"
        )

    before = row["state"]
    if before == state:
        return None

    conn.execute(
        "UPDATE relationship SET state = ? WHERE career_id = ? AND relationship_id = ?",
        (state, career_id, relationship_id),
    )
    return {"relationship_id": relationship_id, "before": before, "after": state}


def state_snapshot(conn: sqlite3.Connection, career_id: str) -> dict:
    """{relationship_id: state} for every row that HAS a moving state.

    Callers take one of these before their writes and diff it after
    (state_diff below). That is how `relationship_state_changes` is built,
    rather than each write path reporting its own transition: a single call
    can move the state two different ways — a leaf's `sets_state`, and
    apply_delta ending a partner whose score hit 0 — and a caller collecting
    per-path records would either miss one or report both halves of one
    change. Diffing the row asks the only question FE cares about: is this
    person in my list now, and were they before?
    """
    return {
        r["relationship_id"]: r["state"]
        for r in conn.execute(
            "SELECT relationship_id, state FROM relationship "
            "WHERE career_id = ? AND kind = 'partner'",
            (career_id,),
        ).fetchall()
    }


def state_diff(before: dict, after: dict) -> list:
    """The transitions between two snapshots, in relationship_id order."""
    return [
        {"relationship_id": rid, "before": before[rid], "after": after[rid]}
        for rid in sorted(after)
        if rid in before and before[rid] != after[rid]
    ]


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

    # §13.2 - a partner whose score reaches 0 is over. Handled HERE, at the
    # single write path, rather than in each caller: the three ways it can
    # happen (a decay tick, a bad dialogue leaf, a missed social plan) all
    # come through this function, and spreading the rule across them would
    # be three chances to forget one. The zero-delta event row is the audit
    # trail saying WHY the card disappeared; INV-15's replay sums deltas, so
    # a 0 changes nothing it checks.
    if new_score == 0:
        row = conn.execute(
            "SELECT kind, state FROM relationship WHERE career_id = ? AND relationship_id = ?",
            (career_id, relationship_id),
        ).fetchone()
        if row["kind"] == "partner" and row["state"] != config.STATE_ABSENT:
            set_state(conn, career_id, relationship_id, config.STATE_ABSENT)
            conn.execute(
                "INSERT INTO relationship_event (career_id, relationship_id, happened_at, delta, reason) "
                "VALUES (?, ?, ?, 0, 'partner_ended')",
                (career_id, relationship_id, happened_at),
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


# --- §13.1 D69/D70: the club side of a transfer ----------------------------


def club_identity(seed: int, team_id: str, relationship_id: str) -> dict:
    """Which coach/captain/stand a given club has, deterministically.

    Keyed on (seed, team_id, relationship_id) rather than drawn at random so
    INV-7 holds: the same career replayed to the same transfer meets the same
    people. A club with an authored entry would shadow the pool; today none
    have one, and adding them later changes nothing here (§13.1 D70).
    """
    pool = CLUB_STAFF_POOL[relationship_id]
    # Plain modulo over a stable hash of the key, not random.Random: this is
    # a lookup, not a roll, and it must give the same answer when called
    # again later (R2 re-reads the same row) without carrying a generator.
    index = zlib.crc32(f"{seed}:{team_id}:{relationship_id}".encode("utf-8")) % len(pool)
    return pool[index]


def reset_for_club(
    conn: sqlite3.Connection,
    career_id: str,
    team_id: str,
    seed: int,
    happened_at: str,
) -> List[dict]:
    """§13.1 - the three layers a transfer resets, in one transaction.

    1. score -> the kind's STARTING_SCORES value, written through
       apply_delta() and NOT a bare UPDATE. That is not style: §3.4 promises
       a test can replay relationship_event from the starting score and land
       on the stored one (INV-15), and a reset that skipped the log would
       break that test on the first transfer.
    2. traits -> the kind's model defaults, through apply_trait_delta()
       (INV-42). This is the one that bites: §12.2 weights the coach's
       `trust` at 35% of squad selection, so a trust carried over from the
       old club would keep you in the eleven at a club that has never seen
       you play.
    3. identity -> the new club's own people (D70).

    Returns one record per reset relationship, shaped like apply_delta's
    before/after plus the new names — S4 hands it straight to FE, which has
    no other way to learn them without re-fetching R1.
    """
    rows = conn.execute(
        "SELECT relationship_id, kind, score FROM relationship "
        "WHERE career_id = ? AND scope = 'club' ORDER BY relationship_id",
        (career_id,),
    ).fetchall()

    resets = []
    for row in rows:
        rid, kind = row["relationship_id"], row["kind"]
        target = STARTING_SCORES[kind]

        change = apply_delta(
            conn, career_id, rid, target - row["score"],
            reason=f"transfer_reset:{team_id}",
            happened_at=happened_at,
            # A reset is not a conversation. Leaving last_contact_at alone
            # would be wrong in the other direction though — the row's whole
            # history just became somebody else's — so it is cleared below
            # rather than bumped to today.
            touches_contact=False,
        )
        conn.execute(
            "UPDATE relationship SET last_contact_at = NULL, team_id = ? "
            "WHERE career_id = ? AND relationship_id = ?",
            (team_id, career_id, rid),
        )

        # traits back to the model's own defaults. Written through
        # validate_traits (INV-16) rather than a literal '{}': hobbies comes
        # from the new identity below, and a bare empty object would drop the
        # defaults every other field starts from.
        identity = club_identity(seed, team_id, rid)
        defaults = validate_traits(kind, {"hobbies": identity["hobbies"]})
        conn.execute(
            "UPDATE relationship SET traits = ?, person_name = ?, contact_name = ?, "
            "age = ?, occupation = ?, bio = ? "
            "WHERE career_id = ? AND relationship_id = ?",
            (
                json.dumps(defaults, ensure_ascii=False),
                identity["person_name"], identity["contact_name"],
                identity["age"], identity["occupation"], identity["bio"],
                career_id, rid,
            ),
        )

        resets.append({
            **change,
            "person_name": identity["person_name"],
            "contact_name": identity["contact_name"],
        })

    return resets
