"""§11.1/§11.2 - the season calendar and the phase derived from it.

Every boundary comes out of one number: the calendar year the season opens
in. That is D44's whole point - rollover and career creation call the same
function instead of each spelling out "the last Saturday of August", and a
season five years out is as computable as this one.

The phase is derived too (D45), never stored. It is the same shape D43 chose
for an attribute's `level`: the server owns the derived value and puts it in
the response, but a column would buy a sync invariant ("this must not drift
from the calendar") in exchange for one saved SELECT.
"""
import datetime as _dt
import random
import sqlite3
from typing import Dict, List, Optional

from domain import scheduling
from worlddata.competitions import CUP_TEAM_IDS, ULUSAL_KUPA

SATURDAY = 5  # date.weekday()

PRE_SEASON = "pre_season"
FIRST_HALF = "first_half"
WINTER_BREAK = "winter_break"
SECOND_HALF = "second_half"
SEASON_END = "season_end"
SUMMER_TRANSFER_WINDOW = "summer_transfer_window"

PHASES = (
    PRE_SEASON, FIRST_HALF, WINTER_BREAK, SECOND_HALF,
    SEASON_END, SUMMER_TRANSFER_WINDOW,
)

# §11.7 - a window is one of these two phases. Nothing else lets an offer be
# accepted.
TRANSFER_WINDOW_PHASES = {WINTER_BREAK: "winter", SUMMER_TRANSFER_WINDOW: "summer"}

# The preparation week between a season opening and its first league round.
PREPARATION_DAYS = 7

# The cup opens on the Wednesday after the league's first Saturday, so a cup
# tie never lands on a league day. If a team had two fixtures on one date, M1's
# "today's match" query would have no way to choose between them.
CUP_OFFSET_DAYS = 4

DAYS_BETWEEN_LEAGUE_ROUNDS = 7
DAYS_BETWEEN_CUP_ROUNDS = 14


def _last_weekday_of(year: int, month: int, weekday: int) -> _dt.date:
    last = _dt.date(year, month, 1)
    last = last.replace(day=_days_in_month(year, month))
    return last - _dt.timedelta(days=(last.weekday() - weekday) % 7)


def _first_weekday_of(year: int, month: int, weekday: int) -> _dt.date:
    first = _dt.date(year, month, 1)
    return first + _dt.timedelta(days=(weekday - first.weekday()) % 7)


def _days_in_month(year: int, month: int) -> int:
    if month == 12:
        return 31
    return (_dt.date(year, month + 1, 1) - _dt.timedelta(days=1)).day


class SeasonCalendar:
    """Every date of one season, derived from the year it opens in."""

    def __init__(self, opening_year: int):
        self.opening_year = opening_year
        self.league_starts_on = _last_weekday_of(opening_year, 8, SATURDAY)
        self.starts_on = self.league_starts_on - _dt.timedelta(days=PREPARATION_DAYS)
        self.cup_starts_on = self.league_starts_on + _dt.timedelta(days=CUP_OFFSET_DAYS)
        self.winter_break_from = _dt.date(opening_year + 1, 1, 1)
        self.winter_break_to = _dt.date(opening_year + 1, 1, 31)
        self.ends_on = _first_weekday_of(opening_year + 1, 6, SATURDAY)

    @property
    def season_id(self) -> str:
        """'26/27' from a 2026 opening. §11.1 notes v1.0's hard-coded
        '25/26' was already inconsistent with its own 2026-08 start date;
        deriving it removes the chance of saying that again."""
        return f"{self.opening_year % 100:02d}/{(self.opening_year + 1) % 100:02d}"

    def as_row(self) -> dict:
        return {
            "season_id": self.season_id,
            "starts_on": self.starts_on.isoformat(),
            "ends_on": self.ends_on.isoformat(),
            "winter_break_from": self.winter_break_from.isoformat(),
            "winter_break_to": self.winter_break_to.isoformat(),
        }

    def in_winter_break(self, day: _dt.date) -> bool:
        return self.winter_break_from <= day <= self.winter_break_to

    def next_playable(self, day: _dt.date) -> _dt.date:
        """INV-33 - no league fixture falls inside a holiday. A round that
        lands in the break shifts to the next suitable week rather than to
        the next free day, so the weekly Saturday rhythm survives."""
        while self.in_winter_break(day):
            day += _dt.timedelta(days=DAYS_BETWEEN_LEAGUE_ROUNDS)
        return day


def calendar_for(opening_year: int) -> SeasonCalendar:
    return SeasonCalendar(opening_year)


def calendar_after(season_row: sqlite3.Row) -> SeasonCalendar:
    """The season that follows the given one. Reads only its own start date,
    so a career resumed from a save lands on the same next season as one
    played straight through."""
    starts_on = _dt.date.fromisoformat(season_row["starts_on"])
    return SeasonCalendar(starts_on.year + 1)


# --- phase ----------------------------------------------------------------

def _league_starts_on(conn: sqlite3.Connection, career_id: str, season_id: str) -> Optional[str]:
    """From the data, not the constant (§11.1). If the placement rule ever
    shifts a round by a day, the phase boundary shifts with it instead of
    disagreeing with the fixtures it is supposed to describe."""
    row = conn.execute(
        "SELECT MIN(r.scheduled_on) AS first_round FROM competition_round r "
        "JOIN competition c ON c.career_id = r.career_id "
        "AND c.competition_id = r.competition_id "
        "WHERE r.career_id = ? AND r.season_id = ? AND c.kind = 'league'",
        (career_id, season_id),
    ).fetchone()
    return row["first_round"] if row else None


def season_is_complete(conn: sqlite3.Connection, career_id: str, season_id: str) -> bool:
    """Nothing left to play. `in_progress` counts as unfinished alongside
    `scheduled`: §6.4's half-finished match must be recovered, not skipped
    over by a rollover."""
    return conn.execute(
        "SELECT 1 FROM fixture WHERE career_id = ? AND season_id = ? "
        "AND status IN ('scheduled', 'in_progress') LIMIT 1",
        (career_id, season_id),
    ).fetchone() is None


def unplayed_count(conn: sqlite3.Connection, career_id: str, season_id: str) -> int:
    return conn.execute(
        "SELECT COUNT(*) AS n FROM fixture WHERE career_id = ? AND season_id = ? "
        "AND status IN ('scheduled', 'in_progress')",
        (career_id, season_id),
    ).fetchone()["n"]


def current_season_row(
    conn: sqlite3.Connection, career_id: str, game_date: str
) -> Optional[sqlite3.Row]:
    """The season whose [starts_on, ends_on] contains game_date."""
    return conn.execute(
        "SELECT * FROM season WHERE career_id = ? AND starts_on <= ? AND ends_on >= ? "
        "ORDER BY starts_on DESC LIMIT 1",
        (career_id, game_date, game_date),
    ).fetchone()


def derive_phase(conn: sqlite3.Connection, career_id: str, game_date: str) -> str:
    """§11.2's three steps.

    The distinction between steps 2 and 3 carries the logic of the whole
    section: if the rollover has been done there is a season row standing
    ahead and the player is signed up for it, so the summer is a transfer
    window; if it has not, there isn't one and the career waits at season
    end. No separate flag is needed to tell those apart.
    """
    season = current_season_row(conn, career_id, game_date)

    if season is None:
        upcoming = conn.execute(
            "SELECT 1 FROM season WHERE career_id = ? AND starts_on > ? LIMIT 1",
            (career_id, game_date),
        ).fetchone()
        return SUMMER_TRANSFER_WINDOW if upcoming else SEASON_END

    # A season can end early: the calendar may say June while the last match
    # was played in May. Checked first because it overrides the date bands.
    if season_is_complete(conn, career_id, season["season_id"]):
        return SEASON_END

    league_starts_on = _league_starts_on(conn, career_id, season["season_id"])
    if league_starts_on and game_date < league_starts_on:
        return PRE_SEASON

    break_from, break_to = season["winter_break_from"], season["winter_break_to"]
    # Seasons written before §11.3 have no break; they read as "no holiday".
    if break_from and break_to:
        if game_date < break_from:
            return FIRST_HALF
        if game_date <= break_to:
            return WINTER_BREAK
        return SECOND_HALF
    return FIRST_HALF


def transfer_window(phase: str) -> Optional[str]:
    """'winter' | 'summer' | None. §11.7's only definition of an open
    window."""
    return TRANSFER_WINDOW_PHASES.get(phase)


# --- building one season --------------------------------------------------
#
# Career creation and the season rollover need exactly the same thing: a
# season row, its entries, a full league fixture list per league and a cup
# calendar with round 1 drawn. Before this they were one function inside
# onboarding that read its team lists from worlddata's tier constants — which
# is right for season one and wrong for every season after promotion and
# relegation have moved teams. Sharing the builder means the second season
# cannot quietly regenerate the first season's divisions.


def insert_rounds(conn: sqlite3.Connection, rounds: list) -> None:
    conn.executemany(
        "INSERT INTO competition_round (career_id, season_id, competition_id, round_no, "
        "stage, scheduled_on, drawn) VALUES (:career_id, :season_id, :competition_id, "
        ":round_no, :stage, :scheduled_on, :drawn)",
        rounds,
    )


def insert_fixtures(conn: sqlite3.Connection, fixtures: list) -> None:
    conn.executemany(
        "INSERT INTO fixture (career_id, fixture_id, season_id, competition_id, round_no, "
        "leg, kickoff_at, home_team_id, away_team_id, status, home_score, away_score, match_id) "
        "VALUES (:career_id, :fixture_id, :season_id, :competition_id, :round_no, :leg, "
        ":kickoff_at, :home_team_id, :away_team_id, :status, :home_score, :away_score, :match_id)",
        fixtures,
    )


def create_season(
    conn: sqlite3.Connection,
    career_id: str,
    calendar: SeasonCalendar,
    league_teams: Dict[str, List[str]],
    rng: random.Random,
    cup_team_ids: Optional[List[str]] = None,
) -> None:
    """Writes one whole season: the row, the entries, every league's fixture
    list, the cup calendar and its first draw. Does not commit.

    `league_teams` maps competition_id -> the teams in it THIS season, so
    the caller decides where promotion and relegation have left everyone.
    """
    season_id = calendar.season_id
    cup_team_ids = list(cup_team_ids if cup_team_ids is not None else CUP_TEAM_IDS)

    conn.execute(
        "INSERT INTO season (career_id, season_id, starts_on, ends_on, "
        "winter_break_from, winter_break_to) VALUES (?, ?, ?, ?, ?, ?)",
        (career_id, season_id, calendar.starts_on.isoformat(),
         calendar.ends_on.isoformat(), calendar.winter_break_from.isoformat(),
         calendar.winter_break_to.isoformat()),
    )

    for competition_id, team_ids in league_teams.items():
        for team_id in team_ids:
            conn.execute(
                "INSERT INTO competition_entry (career_id, season_id, competition_id, team_id) "
                "VALUES (?, ?, ?, ?)",
                (career_id, season_id, competition_id, team_id),
            )
    for team_id in cup_team_ids:
        conn.execute(
            "INSERT INTO competition_entry (career_id, season_id, competition_id, team_id) "
            "VALUES (?, ?, ?, ?)",
            (career_id, season_id, ULUSAL_KUPA, team_id),
        )

    # D9: the seed shuffles fixture ORDER, not the roster — each league gets
    # its own independent shuffle of the same fixed team list.
    for competition_id, team_ids in league_teams.items():
        ids = list(team_ids)
        rng.shuffle(ids)
        rounds, fixtures = scheduling.generate_league_season(
            career_id, season_id, competition_id, ids,
            calendar.league_starts_on.isoformat(),
            days_between_rounds=DAYS_BETWEEN_LEAGUE_ROUNDS,
            skip_from=calendar.winter_break_from.isoformat(),
            skip_to=calendar.winter_break_to.isoformat(),
        )
        insert_rounds(conn, rounds)
        insert_fixtures(conn, fixtures)

    cup_rounds = scheduling.generate_cup_calendar(
        career_id, season_id, ULUSAL_KUPA, len(cup_team_ids),
        calendar.cup_starts_on.isoformat(),
        days_between_rounds=DAYS_BETWEEN_CUP_ROUNDS,
    )
    insert_rounds(conn, cup_rounds)

    # Round 1 has no prior-round dependency, so it is drawn alongside the
    # calendar; later rounds stay undrawn until their predecessor is played.
    round1_kickoff = f"{cup_rounds[0]['scheduled_on']}T20:00:00+03:00"
    insert_fixtures(conn, scheduling.draw_cup_round(
        career_id, season_id, ULUSAL_KUPA, 1, round1_kickoff, cup_team_ids, rng=rng,
    ))
    conn.execute(
        "UPDATE competition_round SET drawn = 1 "
        "WHERE career_id = ? AND season_id = ? AND competition_id = ? AND round_no = 1",
        (career_id, season_id, ULUSAL_KUPA),
    )


def league_teams_for(conn: sqlite3.Connection, career_id: str, season_id: str) -> Dict[str, List[str]]:
    """Who is in which league that season, read from competition_entry
    rather than worlddata — after a promotion the two disagree, and the
    table is the one that is right."""
    rows = conn.execute(
        "SELECT e.competition_id, e.team_id FROM competition_entry e "
        "JOIN competition c ON c.career_id = e.career_id "
        "AND c.competition_id = e.competition_id "
        "WHERE e.career_id = ? AND e.season_id = ? AND c.kind = 'league' "
        "ORDER BY e.competition_id, e.team_id",
        (career_id, season_id),
    ).fetchall()
    out: Dict[str, List[str]] = {}
    for row in rows:
        out.setdefault(row["competition_id"], []).append(row["team_id"])
    return out
