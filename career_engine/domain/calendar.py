"""§5.3 W5 - what a stretch of days looks like on a calendar.

Read-only, like daytime.list_events(), and a sibling of it rather than a
replacement: the two answer different questions and therefore speak
different vocabularies.

    T1  events[].kind   "what is TRUE today"
    W5  marks[].kind    "what is SCHEDULED on this day"

That is why `upkeep_warning` and `relationship_low` are absent here — the
first is a projection of a balance that does not exist yet for a future
date, and the second is a state with no date at all. And why `wage`,
`cup_round`, `contract_expiry` and `season_end` appear here but have no T1
equivalent: they are facts about the calendar, not about today.

Composing this on the client was the alternative and it loses twice: FE
would have to re-implement config.WAGE_WEEKDAY in Dart (a backend rule
living in two places, §1.3), and the season's own bounds are returned by no
endpoint at all today.
"""
import datetime as _dt
import sqlite3
from typing import List, Optional

from api import config, serializers


def month_bounds(on_date: str) -> tuple:
    """The first and last day of the month `on_date` falls in. The default
    range for a calendar page, so FE never has to know how long February
    is to ask for it."""
    day = _dt.date.fromisoformat(on_date)
    first = day.replace(day=1)
    next_month = (first + _dt.timedelta(days=32)).replace(day=1)
    return first.isoformat(), (next_month - _dt.timedelta(days=1)).isoformat()


def _fixture_marks(
    conn: sqlite3.Connection, career_id: str, season_id: str, user_team_id: str,
    from_date: str, to_date: str,
) -> List[tuple]:
    """v1 shows only the user's own fixtures. A grid carrying every club's
    match on every day is a fixture list, not a calendar — and the player's
    question is "when do I play". A `competition=` filter can widen this
    later without changing the shape."""
    rows = conn.execute(
        "SELECT * FROM fixture WHERE career_id = ? AND season_id = ? "
        "AND (home_team_id = ? OR away_team_id = ?) "
        "AND kickoff_at >= ? AND kickoff_at <= ? ORDER BY kickoff_at ASC",
        (career_id, season_id, user_team_id, user_team_id, from_date, f"{to_date}T99"),
    ).fetchall()

    out = []
    for row in rows:
        # kickoff_at is 'YYYY-MM-DDTHH:MM:SS+03:00'; the calendar day is the
        # date part. The world is fixed at +03:00 (§5.0) so there is no
        # timezone arithmetic to do — slicing is the honest operation here.
        out.append((row["kickoff_at"][:10], {
            "kind": "match",
            "ref_id": row["fixture_id"],
            "competition": serializers.fetch_competition_ref(conn, career_id, row["competition_id"]),
            "round_no": row["round_no"],
            "kickoff_at": row["kickoff_at"],
            "home": serializers.fetch_team_ref(conn, career_id, row["home_team_id"]),
            "away": serializers.fetch_team_ref(conn, career_id, row["away_team_id"]),
            "status": row["status"],
            "score": (
                {"home": row["home_score"], "away": row["away_score"]}
                if row["status"] == "played" else None
            ),
            "is_user_match": True,
        }))
    return out


def _wage_marks(from_date: str, to_date: str) -> List[tuple]:
    """Every wage day in range, computed from config.WAGE_WEEKDAY — the same
    constant §6.5 pays on, so the grid and the ledger cannot disagree about
    which day is payday."""
    out = []
    day = _dt.date.fromisoformat(from_date)
    last = _dt.date.fromisoformat(to_date)
    while day <= last:
        if day.weekday() == config.WAGE_WEEKDAY:
            out.append((day.isoformat(), {"kind": "wage", "ref_id": None}))
        day += _dt.timedelta(days=1)
    return out


def _cup_round_marks(
    conn: sqlite3.Connection, career_id: str, season_id: str, from_date: str, to_date: str,
) -> List[tuple]:
    """Rounds are scheduled before they are drawn (§5.3), so "you have a cup
    tie on 3 November" is renderable months before anyone knows against
    whom. An undrawn round has no fixture, which is exactly why it needs its
    own mark rather than being derivable from the fixture list."""
    rows = conn.execute(
        "SELECT competition_id, round_no, stage, scheduled_on, drawn FROM competition_round "
        "WHERE career_id = ? AND season_id = ? AND scheduled_on >= ? AND scheduled_on <= ? "
        "AND drawn = 0 ORDER BY scheduled_on ASC",
        (career_id, season_id, from_date, to_date),
    ).fetchall()
    return [
        (r["scheduled_on"], {
            "kind": "cup_round", "ref_id": r["competition_id"],
            "round_no": r["round_no"], "stage": r["stage"], "drawn": bool(r["drawn"]),
        })
        for r in rows
    ]


def _contract_marks(
    conn: sqlite3.Connection, career_id: str, from_date: str, to_date: str,
) -> List[tuple]:
    row = conn.execute(
        "SELECT expires_at FROM player_contract WHERE career_id = ? AND player_id = ? "
        "ORDER BY signed_at DESC LIMIT 1",
        (career_id, config.USER_PLAYER_ID),
    ).fetchone()
    if row is None or not from_date <= row["expires_at"] <= to_date:
        return []
    return [(row["expires_at"], {"kind": "contract_expiry", "ref_id": None})]


def _season_marks(season: Optional[sqlite3.Row], from_date: str, to_date: str) -> List[tuple]:
    if season is None:
        return []
    out = []
    if from_date <= season["starts_on"] <= to_date:
        out.append((season["starts_on"], {"kind": "season_start", "ref_id": None}))
    if from_date <= season["ends_on"] <= to_date:
        out.append((season["ends_on"], {"kind": "season_end", "ref_id": None}))
    return out


def build_calendar(
    conn: sqlite3.Connection, career_id: str, from_date: str, to_date: str
) -> dict:
    """Only days that carry at least one mark are returned. A 31-day month
    with five marks sends five rows; the empty grid is FE's to draw from
    `from`/`to`, which it has to know anyway to lay out the weekday
    offsets."""
    state = conn.execute(
        "SELECT game_date, season_id FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()
    season_id = state["season_id"]
    user_team_id = serializers.fetch_user_team_id(conn, career_id)

    season = conn.execute(
        "SELECT season_id, starts_on, ends_on FROM season WHERE career_id = ? AND season_id = ?",
        (career_id, season_id),
    ).fetchone()

    marks = []
    if user_team_id:
        marks += _fixture_marks(conn, career_id, season_id, user_team_id, from_date, to_date)
    marks += _wage_marks(from_date, to_date)
    marks += _cup_round_marks(conn, career_id, season_id, from_date, to_date)
    marks += _contract_marks(conn, career_id, from_date, to_date)
    marks += _season_marks(season, from_date, to_date)

    by_date = {}
    for date, mark in marks:
        by_date.setdefault(date, []).append(mark)

    return {
        "from": from_date,
        "to": to_date,
        "today": state["game_date"],
        "season": dict(season) if season else None,
        "days": [
            {"date": date, "marks": by_date[date]}
            for date in sorted(by_date)
        ],
    }
