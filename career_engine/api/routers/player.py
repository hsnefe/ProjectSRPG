"""§5.2 - P1-P3."""
import datetime as _dt
import sqlite3

from fastapi import APIRouter, Depends, Query

from api import config, serializers
from api.deps import get_db
from domain import attributes as attributes_domain, formulas

router = APIRouter(prefix="/careers/{career_id}/player", tags=["player"])


def _fetch_player_row(conn: sqlite3.Connection, career_id: str) -> sqlite3.Row:
    serializers.require_career(conn, career_id)
    row = conn.execute(
        "SELECT * FROM player WHERE career_id = ? AND is_user = 1", (career_id,)
    ).fetchone()
    return row


@router.get("")
def get_player(career_id: str, conn: sqlite3.Connection = Depends(get_db)):
    player_row = _fetch_player_row(conn, career_id)

    attr_rows = {
        r["attribute_key"]: r["value"]
        for r in conn.execute(
            "SELECT attribute_key, value FROM player_attribute WHERE career_id = ? AND player_id = ?",
            (career_id, player_row["player_id"]),
        ).fetchall()
    }
    # INV-21: always 11 rows, even for a key nothing has ever written to.
    # `level` is derived (D43) and ships alongside the raw value so FE can
    # test a `requires` threshold without re-implementing the scale.
    attributes = [
        {
            "key": key,
            "family": family,
            "value": attr_rows.get(key, 0.0),
            "level": attributes_domain.level(attr_rows.get(key, 0.0)),
        }
        for key, family in config.ATTRIBUTE_KEYS.items()
    ]

    fame_rows = conn.execute(
        "SELECT scope, value FROM player_fame WHERE career_id = ? AND player_id = ?",
        (career_id, player_row["player_id"]),
    ).fetchall()
    fame = [dict(r) for r in fame_rows] or [{"scope": "overall", "value": 0.0}]

    market_value = _build_market_value(conn, career_id, player_row, attr_rows, fame)

    return {
        "player_id": player_row["player_id"],
        "name": player_row["name"],
        "position": player_row["position"],
        "birth_date": player_row["birth_date"],
        "age": serializers.age_from_birth_date(player_row["birth_date"]),
        "team": serializers.fetch_team_ref(conn, career_id, player_row["team_id"]),
        "career_state": serializers.fetch_career_state(conn, career_id),
        "attributes": attributes,
        "fame": fame,
        "market_value": market_value,
    }


def _build_market_value(conn, career_id, player_row, attr_rows, fame) -> dict:
    """⟦AÇIK-8⟧: compute_market_value() returns None until a formula is
    chosen. Falls back to the most recent player_value_history snapshot;
    if neither exists yet (a brand-new career has no snapshots), returns
    None rather than inventing a number."""
    contract_row = conn.execute(
        "SELECT expires_at FROM player_contract WHERE career_id = ? AND player_id = ? "
        "ORDER BY signed_at DESC LIMIT 1",
        (career_id, player_row["player_id"]),
    ).fetchone()
    contract_days_remaining = None
    if contract_row is not None:
        contract_days_remaining = (
            _dt.date.fromisoformat(contract_row["expires_at"]) - _dt.date.today()
        ).days

    overall_fame = next((f["value"] for f in fame if f["scope"] == "overall"), 0.0)
    computed = formulas.compute_market_value(
        attributes=attr_rows,
        age=serializers.age_from_birth_date(player_row["birth_date"]),
        contract_days_remaining=contract_days_remaining,
        fame=overall_fame,
    )
    if computed is not None:
        return {"current": computed, "measured_on": _dt.date.today().isoformat()}

    latest = conn.execute(
        "SELECT value, measured_on FROM player_value_history "
        "WHERE career_id = ? AND player_id = ? ORDER BY measured_on DESC LIMIT 1",
        (career_id, player_row["player_id"]),
    ).fetchone()
    if latest is not None:
        return {"current": latest["value"], "measured_on": latest["measured_on"]}
    return None


_KIND_TO_TR = {"league": "lig", "cup": "kupa", "continental": "uluslararasi"}


@router.get("/stats")
def get_player_stats(
    career_id: str,
    season: str = Query("all"),
    competition: str = Query("all"),
    conn: sqlite3.Connection = Depends(get_db),
):
    player_row = _fetch_player_row(conn, career_id)

    sql = (
        "SELECT s.season_id, s.competition_id, c.kind AS competition_kind, c.name AS competition_name, "
        "s.appearances, s.starts, s.goals, s.assists, s.minutes, s.passes_completed, s.passes_attempted "
        "FROM player_season_stat s "
        "JOIN competition c ON c.career_id = s.career_id AND c.competition_id = s.competition_id "
        "WHERE s.career_id = ? AND s.player_id = ?"
    )
    params = [career_id, player_row["player_id"]]
    if season != "all":
        sql += " AND s.season_id = ?"
        params.append(season)
    if competition != "all":
        sql += " AND s.competition_id = ?"
        params.append(competition)

    rows = conn.execute(sql, params).fetchall()
    stat_rows = []
    for r in rows:
        d = dict(r)
        d["competition_kind"] = _KIND_TO_TR.get(d["competition_kind"], d["competition_kind"])
        stat_rows.append(d)

    history_rows = conn.execute(
        "SELECT measured_on, value FROM player_value_history "
        "WHERE career_id = ? AND player_id = ? ORDER BY measured_on ASC",
        (career_id, player_row["player_id"]),
    ).fetchall()

    return {"rows": stat_rows, "value_history": [dict(r) for r in history_rows]}


@router.get("/contract")
def get_player_contract(career_id: str, conn: sqlite3.Connection = Depends(get_db)):
    player_row = _fetch_player_row(conn, career_id)

    row = conn.execute(
        "SELECT * FROM player_contract WHERE career_id = ? AND player_id = ? "
        "ORDER BY signed_at DESC LIMIT 1",
        (career_id, player_row["player_id"]),
    ).fetchone()
    if row is None:
        return None

    days_until_expiry = (_dt.date.fromisoformat(row["expires_at"]) - _dt.date.today()).days

    return {
        "team": serializers.fetch_team_ref(conn, career_id, row["team_id"]),
        "signed_at": row["signed_at"],
        "expires_at": row["expires_at"],
        "weekly_wage": row["weekly_wage"],
        "appearance_bonus": row["appearance_bonus"],
        "goal_bonus": row["goal_bonus"],
        "release_clause": row["release_clause"],
        "days_until_expiry": days_until_expiry,
    }
