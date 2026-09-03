"""§5.4 - R1-R3."""
import json
import sqlite3

from fastapi import APIRouter, Depends

from api import config, errors, serializers
from api.deps import get_db
from api.schemas.relationship import InteractRequest
from catalog.dialogue import DIALOGUE_RELATIONSHIP, resolve_outcome
from domain import attributes, relationships as relationships_domain, requirements, social

router = APIRouter(prefix="/careers/{career_id}/relationships", tags=["relationships"])


def _row_to_card(row: sqlite3.Row, pending: set) -> dict:
    """`pending` is precomputed for the whole career rather than looked up
    per row: R1 draws six cards, and six single-row queries to answer one
    boolean is the shape relationships.peak_scores() already avoids."""
    traits = json.loads(row["traits"])
    return {
        "relationship_id": row["relationship_id"],
        "kind": row["kind"],
        "category": row["category"],
        "score": row["score"],
        "person_name": row["person_name"],
        "contact_name": row["contact_name"],
        "last_contact_at": row["last_contact_at"],
        "has_pending_request": row["relationship_id"] in pending,  # §5.4 R4
        "traits": traits,
    }


@router.get("")
def list_relationships(career_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    rows = conn.execute(
        "SELECT * FROM relationship WHERE career_id = ? ORDER BY relationship_id", (career_id,)
    ).fetchall()
    pending = social.pending_by_relationship(conn, career_id)
    return {"relationships": [_row_to_card(r, pending) for r in rows]}


@router.get("/{relationship_id}")
def get_relationship(career_id: str, relationship_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    row = conn.execute(
        "SELECT * FROM relationship WHERE career_id = ? AND relationship_id = ?",
        (career_id, relationship_id),
    ).fetchone()
    if row is None:
        raise errors.invalid_request(f"unknown relationship_id {relationship_id!r}")

    card = _row_to_card(row, social.pending_by_relationship(conn, career_id))
    traits = card["traits"]
    events = conn.execute(
        "SELECT happened_at, delta, reason FROM relationship_event "
        "WHERE career_id = ? AND relationship_id = ? ORDER BY happened_at DESC LIMIT 20",
        (career_id, relationship_id),
    ).fetchall()

    return {
        **card,
        "age": row["age"],
        "occupation": row["occupation"],
        "bio": row["bio"],
        "hobbies": traits.get("hobbies", []),
        "recent_events": [dict(e) for e in events],
    }


@router.post("/{relationship_id}/interact")
def interact(
    career_id: str,
    relationship_id: str,
    body: InteractRequest,
    conn: sqlite3.Connection = Depends(get_db),
):
    serializers.require_career(conn, career_id)
    row = conn.execute(
        "SELECT 1 FROM relationship WHERE career_id = ? AND relationship_id = ?",
        (career_id, relationship_id),
    ).fetchone()
    if row is None:
        raise errors.invalid_request(f"unknown relationship_id {relationship_id!r}")

    expected_relationship = DIALOGUE_RELATIONSHIP.get(body.dialogue_id)
    if expected_relationship != relationship_id:
        raise errors.invalid_request(
            f"dialogue {body.dialogue_id!r} does not belong to relationship {relationship_id!r}"
        )

    outcome = resolve_outcome(body.dialogue_id, body.choice_path)

    # D42: after the leaf is resolved (we need to know WHICH reply) and
    # before anything is written. Raises 409 requirement_not_met, leaving
    # relationship.score and relationship_event untouched (INV-30).
    requirements.check(conn, career_id, config.USER_PLAYER_ID, outcome.get("requires"))

    current_date = conn.execute(
        # game_date, not current_date — SQLite's CURRENT_DATE keyword.
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"]
    happened_at = f"{current_date}T12:00:00+03:00"
    reason = f"dialogue:{body.dialogue_id}:{body.choice_path[-1]}"

    relationship_change = relationships_domain.apply_delta(
        conn, career_id, relationship_id, outcome["relationship_delta"], reason, happened_at
    )

    attribute_changes = []
    for key, delta in outcome["attribute_effects"].items():
        attribute_changes.append(
            attributes.apply_delta(conn, career_id, config.USER_PLAYER_ID, key, delta)
        )

    conn.commit()

    return {
        "career_state": serializers.fetch_career_state(conn, career_id),
        "relationship_changes": [relationship_change],
        "attribute_changes": attribute_changes,
        "ledger_entries": [],
    }
