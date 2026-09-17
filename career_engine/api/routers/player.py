"""§5.2 - P1-P3."""
import datetime as _dt
import sqlite3

from fastapi import APIRouter, Depends, Query

from api import config, serializers
from api.deps import get_db
from domain import attributes as attributes_domain, contracts, formulas

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
    # §13.3/D74 - `level` is now derived from the EFFECTIVE value (base plus
    # what owned items add), not the stored one. That is the breaking half of
    # §13.3 and it is deliberate: domain/requirements.py gates on exactly this
    # number, so shipping the base level here would let FE grey out a reply
    # the server would have allowed (INV-61).
    #
    # `value` still means the stored base, so a training screen's progress bar
    # keeps showing what the player actually earned; `passive_bonus` is what
    # the wardrobe is worth and `effective_value` is the sum FE compares.
    passive = {
        key: attributes_domain.passive_bonus(conn, career_id, key)
        for key in config.ATTRIBUTE_KEYS
    }
    attributes = [
        {
            "key": key,
            "family": family,
            "value": attr_rows.get(key, 0.0),
            "passive_bonus": passive[key],
            "effective_value": max(0.0, min(100.0, attr_rows.get(key, 0.0) + passive[key])),
            "level": attributes_domain.level(
                max(0.0, min(100.0, attr_rows.get(key, 0.0) + passive[key]))
            ),
        }
        for key, family in config.ATTRIBUTE_KEYS.items()
    ]

    tactic_rows = {
        r["tactic_key"]: r["value"]
        for r in conn.execute(
            "SELECT tactic_key, value FROM player_tactics WHERE career_id = ? AND player_id = ?",
            (career_id, player_row["player_id"]),
        ).fetchall()
    }
    # INV-55: always len(TACTIC_KEYS) rows, same "always N rows" shape as
    # the attributes block above — a tactic never trained reads 0.0, not
    # absent.
    tactics = [
        {"key": key, "value": tactic_rows.get(key, 0.0)}
        for key in config.TACTIC_KEYS
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
        "tactics": tactics,
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

    game_date = conn.execute(
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"]

    row = contracts.active_contract(conn, career_id, game_date)
    expired = False
    if row is None:
        # §11.7 - a free agent. The last deal is still worth showing ("your
        # contract ran out in June") rather than answering null, which FE
        # cannot tell from "no career".
        row = contracts.latest_contract(conn, career_id)
        if row is None:
            return None
        expired = True

    # From game_date, never the wall clock: a career two seasons in is years
    # away from the machine's own calendar.
    days_until_expiry = contracts.days_until_expiry(row, game_date)

    return {
        "team": serializers.fetch_team_ref(conn, career_id, row["team_id"]),
        "status": "expired" if expired else "active",
        "signed_at": row["signed_at"],
        "expires_at": row["expires_at"],
        "weekly_wage": row["weekly_wage"],
        "appearance_bonus": row["appearance_bonus"],
        "goal_bonus": row["goal_bonus"],
        "release_clause": row["release_clause"],
        "days_until_expiry": days_until_expiry,
    }
