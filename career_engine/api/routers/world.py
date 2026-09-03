"""§5.3 - W1-W4.

§5.0's `before`/`next_before` pagination cursor is used generically here
(and later for N1) as "the sort key of the last row already seen", not
literally "earlier than" — for W3's ascending kickoff_at order, `before`
filters to rows *after* that cursor, continuing the list forward.
"""
import datetime as _dt
import sqlite3
from typing import Optional

from fastapi import APIRouter, Depends, Query

from api import config, errors, serializers
from api.deps import get_db
from domain import calendar as calendar_domain

router = APIRouter(prefix="/careers/{career_id}", tags=["world"])


@router.get("/competitions")
def get_competitions(career_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    season_id = _current_season(conn, career_id)
    user_team_id = serializers.fetch_user_team_id(conn, career_id)

    rows = conn.execute(
        "SELECT competition_id, kind, name, country, tier, format, team_count "
        "FROM competition WHERE career_id = ?",
        (career_id,),
    ).fetchall()

    competitions = []
    for r in rows:
        entry = conn.execute(
            "SELECT 1 FROM competition_entry WHERE career_id = ? AND season_id = ? "
            "AND competition_id = ? AND team_id = ?",
            (career_id, season_id, r["competition_id"], user_team_id),
        ).fetchone()
        d = dict(r)
        d["user_participates"] = entry is not None
        competitions.append(d)

    return {"competitions": competitions}


@router.get("/standings")
def get_standings(
    career_id: str,
    competition: str = Query(...),
    season: Optional[str] = Query(None),
    conn: sqlite3.Connection = Depends(get_db),
):
    serializers.require_career(conn, career_id)
    season_id = season or _current_season(conn, career_id)

    kind_row = conn.execute(
        "SELECT kind FROM competition WHERE career_id = ? AND competition_id = ?",
        (career_id, competition),
    ).fetchone()
    if kind_row is None:
        raise errors.invalid_request(f"unknown competition {competition!r}")
    if kind_row["kind"] != "league":
        raise errors.no_standings(competition)

    user_team_id = serializers.fetch_user_team_id(conn, career_id)
    standings = serializers.fetch_full_standings(conn, career_id, season_id, competition)

    rows = []
    for s in standings:
        team = serializers.fetch_team_ref(conn, career_id, s["team_id"])
        rows.append({
            "rank": s["rank"], "team": team,
            "played": s["played"], "won": s["won"], "drawn": s["drawn"], "lost": s["lost"],
            "goals_for": s["goals_for"], "goals_against": s["goals_against"],
            "goal_difference": s["goal_difference"], "points": s["points"],
            "is_user_team": s["team_id"] == user_team_id,
        })

    rule = conn.execute(
        "SELECT promote_count, relegate_count FROM competition_rule "
        "WHERE career_id = ? AND competition_id = ?",
        (career_id, competition),
    ).fetchone()

    return {
        "competition": serializers.fetch_competition_ref(conn, career_id, competition),
        "season_id": season_id,
        "rows": rows,
        "promotion_slots": rule["promote_count"] if rule else 0,
        "relegation_slots": rule["relegate_count"] if rule else 0,
    }


@router.get("/fixtures")
def get_fixtures(
    career_id: str,
    competition: Optional[str] = Query(None),
    round: Optional[int] = Query(None),
    team_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    season: Optional[str] = Query(None),
    limit: int = Query(config.DEFAULT_PAGE_SIZE, le=config.MAX_PAGE_SIZE),
    before: Optional[str] = Query(None),
    conn: sqlite3.Connection = Depends(get_db),
):
    serializers.require_career(conn, career_id)
    season_id = season or _current_season(conn, career_id)
    user_team_id = serializers.fetch_user_team_id(conn, career_id)

    sql = "SELECT * FROM fixture WHERE career_id = ? AND season_id = ?"
    params = [career_id, season_id]
    if competition:
        sql += " AND competition_id = ?"
        params.append(competition)
    if round is not None:
        sql += " AND round_no = ?"
        params.append(round)
    if team_id:
        sql += " AND (home_team_id = ? OR away_team_id = ?)"
        params += [team_id, team_id]
    if status:
        sql += " AND status = ?"
        params.append(status)
    if before:
        sql += " AND kickoff_at > ?"
        params.append(before)
    sql += " ORDER BY kickoff_at ASC LIMIT ?"
    params.append(limit)

    fixture_rows = conn.execute(sql, params).fetchall()
    fixtures = []
    for r in fixture_rows:
        score = {"home": r["home_score"], "away": r["away_score"]} if r["status"] == "played" else None
        fixtures.append({
            "fixture_id": r["fixture_id"],
            "competition": serializers.fetch_competition_ref(conn, career_id, r["competition_id"]),
            "round_no": r["round_no"], "leg": r["leg"], "kickoff_at": r["kickoff_at"],
            "home": serializers.fetch_team_ref(conn, career_id, r["home_team_id"]),
            "away": serializers.fetch_team_ref(conn, career_id, r["away_team_id"]),
            "status": r["status"], "score": score,
            "is_user_match": r["home_team_id"] == user_team_id or r["away_team_id"] == user_team_id,
        })
    next_before = fixtures[-1]["kickoff_at"] if len(fixtures) == limit else None

    round_sql = "SELECT round_no, stage, scheduled_on, drawn FROM competition_round WHERE career_id = ? AND season_id = ?"
    round_params = [career_id, season_id]
    if competition:
        round_sql += " AND competition_id = ?"
        round_params.append(competition)
    round_sql += " ORDER BY round_no ASC"
    round_rows = conn.execute(round_sql, round_params).fetchall()
    rounds = [
        {"round_no": r["round_no"], "stage": r["stage"], "scheduled_on": r["scheduled_on"],
         "drawn": bool(r["drawn"])}
        for r in round_rows
    ]

    return {"fixtures": fixtures, "rounds": rounds, "next_before": next_before}


@router.get("/calendar")
def get_calendar(
    career_id: str,
    from_: Optional[str] = Query(None, alias="from"),
    to: Optional[str] = Query(None),
    conn: sqlite3.Connection = Depends(get_db),
):
    """W5 - a month of the career's calendar. Both bounds default to the
    month `game_date` falls in, so the common case is a bare GET."""
    serializers.require_career(conn, career_id)
    today = conn.execute(
        # game_date, not current_date — SQLite's CURRENT_DATE keyword.
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"]

    default_from, default_to = calendar_domain.month_bounds(today)
    from_date = from_ or default_from
    to_date = to or default_to

    try:
        span = (
            _dt.date.fromisoformat(to_date) - _dt.date.fromisoformat(from_date)
        ).days
    except ValueError:
        raise errors.invalid_request("from/to must be ISO dates (YYYY-MM-DD)")
    if span < 0:
        raise errors.invalid_request(f"to {to_date!r} is before from {from_date!r}")
    if span + 1 > config.MAX_CALENDAR_DAYS:
        raise errors.invalid_request(
            f"calendar range of {span + 1} days exceeds {config.MAX_CALENDAR_DAYS}"
        )

    return calendar_domain.build_calendar(conn, career_id, from_date, to_date)


@router.get("/teams/{team_id}")
def get_team(career_id: str, team_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    row = conn.execute(
        "SELECT * FROM team WHERE career_id = ? AND team_id = ?", (career_id, team_id)
    ).fetchone()
    if row is None:
        raise errors.invalid_request(f"unknown team_id {team_id!r}")

    season_id = _current_season(conn, career_id)
    # §5.3 W4: "competition" means the LEAGUE this team plays this season —
    # a team is also entered in the cup (competition_entry has both rows
    # since it's the single source of truth for every kind, W1), so this
    # must filter to kind='league' explicitly rather than take either row.
    entry = conn.execute(
        "SELECT ce.competition_id FROM competition_entry ce "
        "JOIN competition c ON c.career_id = ce.career_id AND c.competition_id = ce.competition_id "
        "WHERE ce.career_id = ? AND ce.season_id = ? AND ce.team_id = ? AND c.kind = 'league'",
        (career_id, season_id, team_id),
    ).fetchone()

    competition = None
    standing = None
    if entry is not None:
        competition_id = entry["competition_id"]
        competition = serializers.fetch_competition_ref(conn, career_id, competition_id)
        standings = serializers.fetch_full_standings(conn, career_id, season_id, competition_id)
        own = next((s for s in standings if s["team_id"] == team_id), None)
        if own:
            standing = {"rank": own["rank"], "played": own["played"], "points": own["points"]}

    return {
        "team": serializers.team_ref(row),
        "country": row["country"],
        "mentality": row["mentality"],
        "ratings": {
            "attack": row["attack"], "midfield": row["midfield"],
            "defense": row["defense"], "goalkeeper": row["goalkeeper"],
        },
        "competition": competition,
        "standing": standing,
    }


def _current_season(conn: sqlite3.Connection, career_id: str) -> str:
    row = conn.execute(
        "SELECT season_id FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()
    return row["season_id"]
