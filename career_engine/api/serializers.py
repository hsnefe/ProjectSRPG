"""§5.0 - shared response shapes every router builds from, so TeamRef,
CompetitionRef, and CareerState are assembled in exactly one place each."""
import sqlite3
from typing import Optional

from api import errors


def team_ref(row) -> dict:
    """Accepts either an sqlite3.Row (DB-scoped team) or a plain dict
    (worlddata's pre-career team catalog, used by C0 before any career
    exists to scope rows to)."""
    return {
        "team_id": row["team_id"],
        "name": row["name"],
        "short_name": row["short_name"],
        "color_primary": row["color_primary"],
        "color_secondary": row["color_secondary"],
    }


def worlddata_competition_ref(comp: dict) -> dict:
    return {
        "competition_id": comp["competition_id"],
        "kind": comp["kind"],
        "name": comp["name"],
        "country": comp["country"],
        "tier": comp["tier"],
    }


def strength_hint(team: dict) -> str:
    """§5.1 C0 - a coarse label derived from a team's four ratings; the raw
    numbers themselves are never sent to FE pre-career. Thresholds are
    authored against the actual tier-2 roster's spread (worlddata/teams.py),
    not a general formula - if teams.py's ratings change, re-check these."""
    avg = (team["attack"] + team["midfield"] + team["defense"] + team["goalkeeper"]) / 4
    if avg < 56:
        return "zayıf"
    if avg > 61:
        return "güçlü"
    return "orta"


def competition_ref(row: sqlite3.Row) -> dict:
    return {
        "competition_id": row["competition_id"],
        "kind": row["kind"],
        "name": row["name"],
        "country": row["country"],
        "tier": row["tier"],
    }


def fetch_team_ref(conn: sqlite3.Connection, career_id: str, team_id: str) -> Optional[dict]:
    row = conn.execute(
        "SELECT team_id, name, short_name, color_primary, color_secondary "
        "FROM team WHERE career_id = ? AND team_id = ?",
        (career_id, team_id),
    ).fetchone()
    return team_ref(row) if row is not None else None


def fetch_competition_ref(conn: sqlite3.Connection, career_id: str, competition_id: str) -> Optional[dict]:
    row = conn.execute(
        "SELECT competition_id, kind, name, country, tier "
        "FROM competition WHERE career_id = ? AND competition_id = ?",
        (career_id, competition_id),
    ).fetchone()
    return competition_ref(row) if row is not None else None


def fetch_day_budget(conn: sqlite3.Connection, career_id: str) -> dict:
    rows = conn.execute(
        "SELECT resource_key, remaining FROM day_budget WHERE career_id = ?", (career_id,)
    ).fetchall()
    return {r["resource_key"]: r["remaining"] for r in rows}


def fetch_career_state(conn: sqlite3.Connection, career_id: str) -> dict:
    """§5.0 CareerState - the block every state-changing endpoint returns
    in full (D28, INV-18). Raises career_not_found if the career doesn't
    exist, so routers don't each need their own existence check."""
    row = conn.execute(
        "SELECT current_date, season_id, money, condition FROM career_state WHERE career_id = ?",
        (career_id,),
    ).fetchone()
    if row is None:
        raise errors.career_not_found(career_id)
    return {
        "current_date": row["current_date"],
        "season_id": row["season_id"],
        "money": row["money"],
        "condition": row["condition"],
        "day_budget": fetch_day_budget(conn, career_id),
    }


def fetch_user_team_id(conn: sqlite3.Connection, career_id: str) -> Optional[str]:
    row = conn.execute(
        "SELECT team_id FROM player WHERE career_id = ? AND is_user = 1", (career_id,)
    ).fetchone()
    return row["team_id"] if row is not None else None


def fetch_user_league_competition_id(conn: sqlite3.Connection, career_id: str, season_id: str) -> Optional[str]:
    """The league (kind='league') the user's team is entered in this
    season — distinct from the cup, which every tier-2/tier-1 team also
    plays but which has no standings table (INV: no_standings, §9)."""
    row = conn.execute(
        "SELECT ce.competition_id FROM competition_entry ce "
        "JOIN competition c ON c.career_id = ce.career_id AND c.competition_id = ce.competition_id "
        "JOIN player p ON p.career_id = ce.career_id AND p.team_id = ce.team_id AND p.is_user = 1 "
        "WHERE ce.career_id = ? AND ce.season_id = ? AND c.kind = 'league'",
        (career_id, season_id),
    ).fetchone()
    return row["competition_id"] if row is not None else None


def fetch_full_standings(conn: sqlite3.Connection, career_id: str, season_id: str, competition_id: str) -> list:
    """§5.3 W2 - every team entered in this competition/season, ranked,
    even teams with zero games played (the `standing` VIEW only has rows
    for teams that appear in a *played* fixture, so a fresh season needs
    this LEFT JOIN to show anyone at all)."""
    rows = conn.execute(
        """
        WITH entries AS (
          SELECT team_id FROM competition_entry
          WHERE career_id = ? AND season_id = ? AND competition_id = ?
        ),
        agg AS (
          SELECT e.team_id,
                 COALESCE(s.played, 0) AS played,
                 COALESCE(s.won, 0) AS won,
                 COALESCE(s.drawn, 0) AS drawn,
                 COALESCE(s.lost, 0) AS lost,
                 COALESCE(s.goals_for, 0) AS goals_for,
                 COALESCE(s.goals_against, 0) AS goals_against,
                 COALESCE(s.points, 0) AS points
          FROM entries e
          LEFT JOIN standing s
            ON s.career_id = ? AND s.season_id = ? AND s.competition_id = ? AND s.team_id = e.team_id
        )
        SELECT team_id, played, won, drawn, lost, goals_for, goals_against,
               (goals_for - goals_against) AS goal_difference, points,
               RANK() OVER (
                 ORDER BY points DESC, (goals_for - goals_against) DESC, goals_for DESC
               ) AS rank
        FROM agg
        ORDER BY rank, team_id
        """,
        (career_id, season_id, competition_id, career_id, season_id, competition_id),
    ).fetchall()
    return [dict(r) for r in rows]


def fetch_next_fixture(conn: sqlite3.Connection, career_id: str, user_team_id: str) -> Optional[dict]:
    """§5.1 C3 next_fixture - the soonest not-yet-played fixture involving
    the user's team, across every competition they're in (league AND cup)."""
    row = conn.execute(
        "SELECT * FROM fixture WHERE career_id = ? AND status = 'scheduled' "
        "AND (home_team_id = ? OR away_team_id = ?) ORDER BY kickoff_at ASC LIMIT 1",
        (career_id, user_team_id, user_team_id),
    ).fetchone()
    if row is None:
        return None

    home = fetch_team_ref(conn, career_id, row["home_team_id"])
    away = fetch_team_ref(conn, career_id, row["away_team_id"])
    competition = fetch_competition_ref(conn, career_id, row["competition_id"])
    current_date = conn.execute(
        "SELECT current_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["current_date"]

    import datetime as _dt
    kickoff_date = row["kickoff_at"][:10]
    days_until = (
        _dt.date.fromisoformat(kickoff_date) - _dt.date.fromisoformat(current_date)
    ).days

    return {
        "fixture_id": row["fixture_id"],
        "competition": competition,
        "round_no": row["round_no"],
        "kickoff_at": row["kickoff_at"],
        "home": home,
        "away": away,
        "user_side": "home" if row["home_team_id"] == user_team_id else "away",
        "days_until": days_until,
    }


def require_career(conn: sqlite3.Connection, career_id: str) -> None:
    """Raises career_not_found if career_id doesn't exist. Cheaper than
    fetch_career_state() for endpoints that only need the existence check."""
    row = conn.execute("SELECT 1 FROM career WHERE career_id = ?", (career_id,)).fetchone()
    if row is None:
        raise errors.career_not_found(career_id)
