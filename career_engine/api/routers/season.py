"""§11.5/§11.6 - S1 and S2.

D46 keeps the rollover out of `advance`: it is its own endpoint so FE can
put a season-end screen in front of it, where the user sees the final table
and starts the turnover themselves.
"""
import sqlite3

from fastapi import APIRouter, Depends, Query

from api import errors, serializers
from api.deps import get_db
from domain import rollover, season as season_mod

router = APIRouter(prefix="/careers/{career_id}/season", tags=["season"])


def _require_finished(conn: sqlite3.Connection, career_id: str, season_id: str) -> None:
    """Both remaining preconditions answer with the same code: for the user
    they are one situation ("it isn't over yet"), and the count in the
    message is the only useful difference between them (§11.5)."""
    unplayed = season_mod.unplayed_count(conn, career_id, season_id)
    if unplayed:
        raise errors.season_not_finished(unplayed)


@router.post("/rollover")
def post_rollover(career_id: str, conn: sqlite3.Connection = Depends(get_db)):
    """S1. One call, one transaction (INV-36), and `game_date` does not move
    (D47) — the summer is played day by day like any other stretch."""
    serializers.require_career(conn, career_id)

    game_date = conn.execute(
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"]

    if season_mod.derive_phase(conn, career_id, game_date) != season_mod.SEASON_END:
        # Not at the boundary at all: the same code, because "the season is
        # not over" is what both mean.
        raise errors.season_not_finished(0)

    finished = conn.execute(
        "SELECT season_id FROM season WHERE career_id = ? ORDER BY starts_on DESC LIMIT 1",
        (career_id,),
    ).fetchone()
    _require_finished(conn, career_id, finished["season_id"])

    result = rollover.run(conn, career_id)
    conn.commit()
    return {"career_state": serializers.fetch_career_state(conn, career_id), **result}


@router.get("/summary")
def get_summary(
    career_id: str,
    season: str = Query(default=None, description="§11.6 — defaults to the last completed season"),
    conn: sqlite3.Connection = Depends(get_db),
):
    """S2. For an FE that missed the rollover screen, or one looking back."""
    serializers.require_career(conn, career_id)

    if season is None:
        row = conn.execute(
            "SELECT season_id FROM season_result WHERE career_id = ? "
            "ORDER BY season_id DESC LIMIT 1",
            (career_id,),
        ).fetchone()
        if row is None:
            raise errors.season_not_finished(
                season_mod.unplayed_count(
                    conn, career_id,
                    conn.execute(
                        "SELECT season_id FROM season WHERE career_id = ? "
                        "ORDER BY starts_on DESC LIMIT 1",
                        (career_id,),
                    ).fetchone()["season_id"],
                )
            )
        season = row["season_id"]
    else:
        recorded = conn.execute(
            "SELECT 1 FROM season_result WHERE career_id = ? AND season_id = ? LIMIT 1",
            (career_id, season),
        ).fetchone()
        if recorded is None:
            raise errors.season_not_finished(
                season_mod.unplayed_count(conn, career_id, season)
            )

    return rollover.summary(conn, career_id, season)
