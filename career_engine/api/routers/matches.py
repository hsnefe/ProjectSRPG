"""§5.6 - M1-M3.

M2's handler stays a plain sync `def` like every other endpoint, taking
`body: dict` rather than a Pydantic model or an async Request.json() read.
An `async def` endpoint runs directly on the event loop while its `Depends`
(a sync generator, get_db) gets dispatched to a worker thread — two
different threads touching the same sqlite3.Connection, which raises
(sqlite3 connections aren't thread-safe by default). Every sync endpoint
in this codebase runs entirely in one threadpool thread instead, avoiding
that split; `body: dict` still gets FastAPI's own JSON parsing without
requiring async access to the request. Semantic validation (missing
fields, wrong keys, wrong values) all goes through matches.validate_result()
regardless, which is what INV-23's single error code is actually about —
only genuinely malformed JSON syntax falls back to FastAPI's own 422.
"""
import sqlite3

from fastapi import APIRouter, Depends

from api import errors, serializers
from api.deps import get_db
from api.schemas.match import CoachTalkRequest
from domain import coach_talk, condition, matches

router = APIRouter(prefix="/careers/{career_id}/matches", tags=["matches"])


@router.get("/next")
def get_next_match(career_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    return matches.build_next_match_payload(conn, career_id)


@router.post("/{fixture_id}/result")
def post_match_result(career_id: str, fixture_id: str, body: dict, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    return matches.apply_result(conn, career_id, fixture_id, body)


@router.post("/{fixture_id}/abandon")
def post_abandon(career_id: str, fixture_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    return matches.abandon_match(conn, career_id, fixture_id)


@router.post("/{fixture_id}/coach-talk")
def post_coach_talk(
    career_id: str,
    fixture_id: str,
    body: CoachTalkRequest,
    conn: sqlite3.Connection = Depends(get_db),
):
    """§12.1 M4. Gates run cheapest-first and none of them writes, so a
    refusal at any step leaves the career exactly as it was (INV-4)."""
    serializers.require_career(conn, career_id)

    fixture = conn.execute(
        "SELECT kickoff_at FROM fixture WHERE career_id = ? AND fixture_id = ?",
        (career_id, fixture_id),
    ).fetchone()
    if fixture is None:
        raise errors.fixture_not_found(fixture_id)

    # The talk belongs to a match you are about to play, so it is pinned to
    # the fixture's own day rather than to "today" - reusing not_match_day
    # keeps FE's existing handling for "you can't do that yet".
    game_date = conn.execute(
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"]
    kickoff_on = fixture["kickoff_at"][:10]
    if kickoff_on != game_date:
        raise errors.not_match_day(kickoff_on)

    if coach_talk.already_talked(conn, career_id, fixture_id):
        raise errors.coach_talk_already_done(fixture_id)

    seed = conn.execute(
        "SELECT seed FROM career WHERE career_id = ?", (career_id,)
    ).fetchone()["seed"]

    result = coach_talk.talk(
        conn, career_id, fixture_id,
        topic=body.topic, value=body.value, seed=seed,
        happened_at=f"{game_date}T17:00:00+03:00",
    )

    condition_after = (
        condition.apply_delta(conn, career_id, result["condition_delta"])
        if result["condition_delta"]
        else None
    )

    conn.commit()

    return {
        "career_state": serializers.fetch_career_state(conn, career_id),
        "topic": result["topic"],
        "granted": result["granted"],
        "relationship_changes": [result["relationship_change"]],
        "trait_changes": result["trait_changes"],
        "condition_after": condition_after,
        "player": result["player"],
    }
