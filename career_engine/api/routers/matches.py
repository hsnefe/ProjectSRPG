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

from api import serializers
from api.deps import get_db
from domain import matches

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
