"""§14.4 - the housing screen's endpoints.

Every mutation returns the whole CareerState (D28/INV-18) plus the new housing
picture and the day's condition forecast, because moving house changes both what a
night is worth and how much money there is.
"""
import sqlite3
from typing import Optional

from fastapi import APIRouter, Depends

from api import config, serializers
from api.deps import get_db
from api.routers.time import _apply_effects, _current_date, _seed
from domain import condition, day_budget, housing, season as season_mod, wallet  # noqa: F401

router = APIRouter(prefix="/careers/{career_id}/housing", tags=["housing"])


def _body(conn: sqlite3.Connection, career_id: str, **extra) -> dict:
    tomorrow = _tomorrow(_current_date(conn, career_id))
    return {
        "career_state": serializers.fetch_career_state(conn, career_id),
        **housing.view(conn, career_id),
        "condition_recovery": condition.daily_recovery(conn, career_id, tomorrow, _seed(conn, career_id)),
        **extra,
    }


def _tomorrow(current_date: str) -> str:
    import datetime as _dt

    return (_dt.date.fromisoformat(current_date) + _dt.timedelta(days=1)).isoformat()


@router.get("")
def get_housing(career_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    return _body(conn, career_id)


@router.post("/{residence_id}/acquire")
def acquire(career_id: str, residence_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    result = housing.acquire(conn, career_id, residence_id, _current_date(conn, career_id))
    conn.commit()
    return _body(conn, career_id, moved=result["moved"], ledger_entries=result["ledger_entries"])


@router.post("/{residence_id}/activate")
def activate(career_id: str, residence_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    result = housing.activate(conn, career_id, residence_id, _current_date(conn, career_id))
    conn.commit()
    return _body(conn, career_id, moved=result["moved"], ledger_entries=[])


@router.post("/{residence_id}/upgrades/{upgrade_id}")
def install_upgrade(
    career_id: str, residence_id: str, upgrade_id: str, conn: sqlite3.Connection = Depends(get_db)
):
    serializers.require_career(conn, career_id)
    result = housing.install_upgrade(
        conn, career_id, residence_id, upgrade_id, _current_date(conn, career_id)
    )
    conn.commit()
    return _body(conn, career_id, ledger_entries=result["ledger_entries"])


@router.post("/{residence_id}/rest")
def rest(career_id: str, residence_id: str, conn: sqlite3.Connection = Depends(get_db)):
    """D90 - a whole day at a holiday home. Check order: held and in season
    first (reads), then the day's time (INV-4), then the effects."""
    serializers.require_career(conn, career_id)
    current_date = _current_date(conn, career_id)
    phase = season_mod.derive_phase(conn, career_id, current_date)
    block = housing.require_rest(conn, career_id, residence_id, phase)

    # The whole day: a second rest on the same day finds no time left.
    day_budget.spend(conn, career_id, {"time": config.DAY_BUDGET_DEFAULTS["time"]})
    effects = {"condition": block["condition"], **block["effects"]}
    applied = _apply_effects(
        conn, career_id, effects, "lifestyle", f"housing_rest:{residence_id}",
        f"{current_date}T12:00:00+03:00",
    )
    conn.commit()
    return _body(conn, career_id, applied_effects=effects, **applied)
