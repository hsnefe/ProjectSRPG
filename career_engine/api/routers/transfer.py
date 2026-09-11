"""§11.7 - S3 and S4, plus the renewal counter.

The counter endpoint is not in §11.7, which defines acceptance and nothing
else. A club that can only present a take-it-or-leave-it deal is not
negotiating, so the renewal offer carries one push-back; see §12.4.
"""
import sqlite3

from fastapi import APIRouter, Depends

from api import errors, serializers
from api.deps import get_db
from domain import season as season_mod, transfer

router = APIRouter(prefix="/careers/{career_id}/transfer", tags=["transfer"])


def _game_date(conn: sqlite3.Connection, career_id: str) -> str:
    return conn.execute(
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"]


def _seed(conn: sqlite3.Connection, career_id: str) -> int:
    return conn.execute(
        "SELECT seed FROM career WHERE career_id = ?", (career_id,)
    ).fetchone()["seed"]


@router.get("/offers")
def get_offers(career_id: str, conn: sqlite3.Connection = Depends(get_db)):
    """S3. A closed window answers with an empty list, not an error — the
    player asking "has anyone come in?" out of season is a fair question
    with a boring answer (§11.7)."""
    serializers.require_career(conn, career_id)
    game_date = _game_date(conn, career_id)
    phase = season_mod.derive_phase(conn, career_id, game_date)
    window = season_mod.transfer_window(phase)

    if window is None:
        return {"window": None, "closes_on": None, "offers": []}

    # Offers open lazily, the first time the player looks inside a window.
    # Nothing generates them on a schedule because nothing needs to: the
    # window is the trigger, and `generate` is idempotent while any offer of
    # it is still open.
    transfer.generate(conn, career_id, game_date, _seed(conn, career_id), window)
    conn.commit()

    return {
        "window": window,
        "closes_on": _window_closes_on(conn, career_id, game_date, window),
        "offers": transfer.list_open(conn, career_id),
    }


def _window_closes_on(conn, career_id, game_date, window):
    """The last day the window is open. Winter is the break's own end date;
    summer runs until the day before the new season opens."""
    if window == "winter":
        row = season_mod.current_season_row(conn, career_id, game_date)
        return row["winter_break_to"] if row else None

    upcoming = conn.execute(
        "SELECT starts_on FROM season WHERE career_id = ? AND starts_on > ? "
        "ORDER BY starts_on ASC LIMIT 1",
        (career_id, game_date),
    ).fetchone()
    if upcoming is None:
        return None
    import datetime as _dt
    return (
        _dt.date.fromisoformat(upcoming["starts_on"]) - _dt.timedelta(days=1)
    ).isoformat()


@router.post("/offers/{offer_id}/accept")
def post_accept(career_id: str, offer_id: str, conn: sqlite3.Connection = Depends(get_db)):
    """S4. One transaction: the player moves, the contract is written, and
    every other open offer expires."""
    serializers.require_career(conn, career_id)
    result = transfer.accept(conn, career_id, offer_id, _game_date(conn, career_id))
    conn.commit()
    return {"career_state": serializers.fetch_career_state(conn, career_id), **result}


@router.post("/offers/{offer_id}/counter")
def post_counter(career_id: str, offer_id: str, conn: sqlite3.Connection = Depends(get_db)):
    """§12.4 — ask the club for more, once. Whether it says yes comes from
    the coach relationship, his trust, and last season's goals: the same
    things that decide whether you play."""
    serializers.require_career(conn, career_id)
    game_date = _game_date(conn, career_id)

    phase = season_mod.derive_phase(conn, career_id, game_date)
    if season_mod.transfer_window(phase) is None:
        raise errors.no_transfer_window()

    result = transfer.counter(conn, career_id, offer_id, _seed(conn, career_id))
    conn.commit()
    return {"career_state": serializers.fetch_career_state(conn, career_id), **result}


@router.post("/offers/{offer_id}/decline")
def post_decline(career_id: str, offer_id: str, conn: sqlite3.Connection = Depends(get_db)):
    """Not in §11.7 either, and for the same reason as the counter: a list
    you can only accept from is not a choice. Declining costs nothing and
    cannot fail (the same reading INV-40 gives social offers)."""
    serializers.require_career(conn, career_id)
    row = transfer.get(conn, career_id, offer_id)
    if row is None:
        raise errors.offer_not_found(offer_id)
    if row["status"] != transfer.OPEN:
        raise errors.offer_not_open(offer_id)

    conn.execute(
        "UPDATE transfer_offer SET status = ? WHERE career_id = ? AND offer_id = ?",
        (transfer.EXPIRED, career_id, offer_id),
    )
    conn.commit()
    return {
        "career_state": serializers.fetch_career_state(conn, career_id),
        "offers": transfer.list_open(conn, career_id),
    }
