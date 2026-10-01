"""§14.7 - "bad form", defined once.

Two readers need the same answer: the post-match trigger that queues the coach's
bad day (domain/triggers.py) and the context layer that makes a flashy car cost
charisma (domain/context.py). A definition kept in each would drift the first
time somebody tuned one - so it lives here. Bad form is `STREAK` straight
defeats of the user's team, the latest ones; a draw or a win ends it.
"""
import sqlite3

STREAK = 3


def _user_team_id(conn: sqlite3.Connection, career_id: str) -> str:
    return conn.execute(
        "SELECT team_id FROM player WHERE career_id = ? AND is_user = 1", (career_id,)
    ).fetchone()["team_id"]


def losing_streak(conn: sqlite3.Connection, career_id: str) -> bool:
    team_id = _user_team_id(conn, career_id)
    rows = conn.execute(
        "SELECT home_team_id, home_score, away_score FROM fixture WHERE career_id = ? AND status = 'played' "
        "AND (home_team_id = ? OR away_team_id = ?) ORDER BY kickoff_at DESC, fixture_id DESC LIMIT ?",
        (career_id, team_id, team_id, STREAK),
    ).fetchall()
    if len(rows) < STREAK:
        return False
    return all(
        r["home_score"] != r["away_score"]
        and (r["home_score"] < r["away_score"]) == (r["home_team_id"] == team_id)
        for r in rows
    )
