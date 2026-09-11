"""§12.7 - sponsorship deals.

No phase gate, unlike transfers: a brand does not wait for a window, and the
request was explicit that a deal can be signed at any point in the season.
"""
import sqlite3

from fastapi import APIRouter, Depends

from api import serializers
from api.deps import get_db
from domain import sponsorship

router = APIRouter(prefix="/careers/{career_id}/sponsorships", tags=["sponsorship"])


def _game_date(conn: sqlite3.Connection, career_id: str) -> str:
    return conn.execute(
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"]


@router.get("")
def get_sponsorships(career_id: str, conn: sqlite3.Connection = Depends(get_db)):
    """Offers and running deals in one answer: the player's question is "what
    is my sponsorship situation", not "what is on the table"."""
    serializers.require_career(conn, career_id)
    on_date = _game_date(conn, career_id)
    return {
        "offers": sponsorship.list_offers(conn, career_id),
        "active": sponsorship.list_active(conn, career_id),
        "pending_obligations": [
            {
                "obligation_id": row["obligation_id"],
                "deal_id": row["deal_id"],
                "due_on": row["due_on"],
            }
            for row in sponsorship.pending_obligations(conn, career_id, on_date)
        ],
    }


@router.post("/{deal_id}/accept")
def post_accept(career_id: str, deal_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    deal = sponsorship.accept(conn, career_id, deal_id, _game_date(conn, career_id))
    conn.commit()
    return {
        "career_state": serializers.fetch_career_state(conn, career_id),
        "deal": deal,
    }


@router.post("/{deal_id}/decline")
def post_decline(career_id: str, deal_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    sponsorship.decline(conn, career_id, deal_id, _game_date(conn, career_id))
    conn.commit()
    return {
        "career_state": serializers.fetch_career_state(conn, career_id),
        "offers": sponsorship.list_offers(conn, career_id),
    }


@router.post("/obligations/{obligation_id}/attend")
def post_attend(
    career_id: str, obligation_id: str, conn: sqlite3.Connection = Depends(get_db)
):
    """Turn up. Costs the day's budget and some condition."""
    serializers.require_career(conn, career_id)
    result = sponsorship.attend(
        conn, career_id, obligation_id, _game_date(conn, career_id)
    )
    conn.commit()
    return {"career_state": serializers.fetch_career_state(conn, career_id), **result}


@router.post("/obligations/{obligation_id}/skip")
def post_skip(
    career_id: str, obligation_id: str, conn: sqlite3.Connection = Depends(get_db)
):
    """Don't. The deal breaks, the money stops and the press notices — which
    is what keeps the advance gate from being a lock."""
    serializers.require_career(conn, career_id)
    result = sponsorship.skip(
        conn, career_id, obligation_id, _game_date(conn, career_id)
    )
    conn.commit()
    return {"career_state": serializers.fetch_career_state(conn, career_id), **result}
