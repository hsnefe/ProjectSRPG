"""§5.0 - shared response shapes every router builds from, so TeamRef,
CompetitionRef, and CareerState are assembled in exactly one place each."""
import datetime as _dt
import sqlite3
from typing import Optional

from api import errors
# Imported inside the module rather than at call sites: CareerState is
# assembled here and nowhere else, so the phase has exactly one source.
from domain import season


def age_from_birth_date(birth_date: str) -> int:
    """Wall-clock age from an ISO birth date. Lives here because three
    responses now carry it (C2's list row, C3's hub, P1's profile) and they
    must not drift apart."""
    b = _dt.date.fromisoformat(birth_date)
    today = _dt.date.today()
    return today.year - b.year - ((today.month, today.day) < (b.month, b.day))


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
        # game_date, not current_date — SQLite's CURRENT_DATE keyword.
        "SELECT game_date, season_id, money, condition FROM career_state WHERE career_id = ?",
        (career_id,),
    ).fetchone()
    if row is None:
        raise errors.career_not_found(career_id)
    return {
        "current_date": row["game_date"],
        "season_id": row["season_id"],
        # §11.8/D45 - derived, never stored. Added here rather than at each
        # call site so it lands in every mutating endpoint's response at
        # once (D28/INV-18), which is what the contract asks for.
        "season_phase": season.derive_phase(conn, career_id, row["game_date"]),
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
               (goals_for - goals_against) AS goal_difference, points
        FROM agg
        ORDER BY points DESC, (goals_for - goals_against) DESC, goals_for DESC,
                 goals_against ASC, won DESC, team_id
        """,
        (career_id, season_id, competition_id, career_id, season_id, competition_id),
    ).fetchall()
    return _rank_with_head_to_head(conn, career_id, season_id, competition_id,
                                   [dict(r) for r in rows])


def _head_to_head_difference(
    conn: sqlite3.Connection, career_id: str, season_id: str,
    competition_id: str, team_ids: list,
) -> dict:
    """Goal difference among a tied group ONLY, from the fixtures they
    played against each other. §11.4 orders on this, and it cannot come out
    of the `standing` view: that view aggregates per team across the whole
    competition, while this needs a table built from a subset of fixtures
    that is different for every group."""
    if len(team_ids) < 2:
        return {t: 0 for t in team_ids}

    placeholders = ",".join("?" * len(team_ids))
    rows = conn.execute(
        f"SELECT home_team_id, away_team_id, home_score, away_score FROM fixture "
        f"WHERE career_id = ? AND season_id = ? AND competition_id = ? AND status = 'played' "
        f"AND home_team_id IN ({placeholders}) AND away_team_id IN ({placeholders})",
        (career_id, season_id, competition_id, *team_ids, *team_ids),
    ).fetchall()

    diff = {t: 0 for t in team_ids}
    for row in rows:
        margin = row["home_score"] - row["away_score"]
        diff[row["home_team_id"]] += margin
        diff[row["away_team_id"]] -= margin
    return diff


def _rank_with_head_to_head(
    conn: sqlite3.Connection, career_id: str, season_id: str,
    competition_id: str, rows: list,
) -> list:
    """§11.4's ordering, in two stages: SQL settles points, goal difference,
    goals for, goals against and wins; whatever is still level is separated
    here by head-to-head goal difference.

    Note the fourth criterion (goals against) can never discriminate on its
    own: goal difference is goals for minus goals against, so two teams
    level on points, difference and goals for are necessarily level on goals
    against too. It stays in the ordering because the spec lists it and it
    costs nothing; in practice head-to-head is what breaks the tie.
    """
    def sql_key(row):
        return (row["points"], row["goal_difference"], row["goals_for"],
                -row["goals_against"], row["won"])

    ordered = []
    index = 0
    while index < len(rows):
        end = index + 1
        while end < len(rows) and sql_key(rows[end]) == sql_key(rows[index]):
            end += 1

        group = rows[index:end]
        if len(group) > 1:
            diff = _head_to_head_difference(
                conn, career_id, season_id, competition_id,
                [r["team_id"] for r in group],
            )
            group.sort(key=lambda r: (-diff[r["team_id"]], r["team_id"]))
        ordered.extend(group)
        index = end

    for position, row in enumerate(ordered, start=1):
        row["rank"] = position
    return ordered


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
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"]

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
