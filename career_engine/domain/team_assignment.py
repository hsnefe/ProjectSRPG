"""§3 - which club a brand-new career actually starts at.

The rule is "the player's own country, that country's bottom league, one of
the suitable clubs in it". None of those three steps hardcodes 'TR' or
'c_lig2': the bottom league is whichever league row for that country has the
highest `tier` (tier counts downward — 1 is the top flight), and its clubs
come from competition_entry, which competitions.py calls the single source of
truth for who is in a competition. Shipping a second country therefore needs
no edit here.

Which club among them is a swappable policy. STRATEGIES maps a name to a
picker; create_career() asks for DEFAULT_STRATEGY and never names one
directly, so re-tuning the rule — or letting the FE choose per career — is a
one-line change rather than surgery on onboarding.

This module reads the world tables, so it must run after _seed_world().
"""
import random
import sqlite3
from typing import Callable, List, Optional

from api import errors


def find_lowest_league(conn: sqlite3.Connection, career_id: str, country_code: str) -> Optional[str]:
    """The bottom-tier league competition_id for `country_code`, or None if
    that country has no league in this career's world.

    Cups are excluded by kind: their tier is NULL (§3.3) and "the bottom of
    the pyramid" is a league-only idea. ORDER BY tier DESC picks the largest
    tier number, which is the lowest division.
    """
    row = conn.execute(
        "SELECT competition_id FROM competition "
        "WHERE career_id = ? AND country = ? AND kind = 'league' AND tier IS NOT NULL "
        "ORDER BY tier DESC LIMIT 1",
        (career_id, country_code),
    ).fetchone()
    return row["competition_id"] if row is not None else None


def league_team_ids(
    conn: sqlite3.Connection, career_id: str, season_id: str, competition_id: str
) -> List[str]:
    """Every club entered in `competition_id` this season, ordered by team_id
    so a seeded pick is reproducible regardless of insert order."""
    rows = conn.execute(
        "SELECT team_id FROM competition_entry "
        "WHERE career_id = ? AND season_id = ? AND competition_id = ? "
        "ORDER BY team_id",
        (career_id, season_id, competition_id),
    ).fetchall()
    return [r["team_id"] for r in rows]


def _overall(conn: sqlite3.Connection, career_id: str, team_id: str) -> float:
    row = conn.execute(
        "SELECT attack, midfield, defense, goalkeeper FROM team "
        "WHERE career_id = ? AND team_id = ?",
        (career_id, team_id),
    ).fetchone()
    return (row["attack"] + row["midfield"] + row["defense"] + row["goalkeeper"]) / 4.0


# --- strategies -------------------------------------------------------------
# Every strategy has the same signature so STRATEGIES stays a flat dispatch
# table: (conn, career_id, team_ids, rng) -> team_id. team_ids is never empty
# — assign_starting_team() raises before calling if the league has no clubs.

def _weaker_half(
    conn: sqlite3.Connection, career_id: str, team_ids: List[str], rng: random.Random
) -> str:
    """"Uygun alt takımlar": rank the bottom league by overall rating and draw
    from its weaker half. A career that starts at the division's strongest
    club has nowhere to climb inside it, which is the whole point of starting
    at the bottom (D21). Ties break by team_id via the sort's stability over
    league_team_ids()'s own ordering."""
    ranked = sorted(team_ids, key=lambda t: (_overall(conn, career_id, t), t))
    half = max(1, len(ranked) // 2)
    return rng.choice(ranked[:half])


def _any_club(
    conn: sqlite3.Connection, career_id: str, team_ids: List[str], rng: random.Random
) -> str:
    """Uniform draw across the whole bottom league."""
    return rng.choice(team_ids)


def _weakest_club(
    conn: sqlite3.Connection, career_id: str, team_ids: List[str], rng: random.Random
) -> str:
    """Deterministic: always the single weakest club. Useful for tests and for
    a "hardest start" option if one is ever offered."""
    return min(team_ids, key=lambda t: (_overall(conn, career_id, t), t))


STRATEGIES: dict = {
    "weaker_half": _weaker_half,
    "any_club": _any_club,
    "weakest_club": _weakest_club,
}

DEFAULT_STRATEGY = "weaker_half"


def assign_starting_team(
    conn: sqlite3.Connection,
    career_id: str,
    season_id: str,
    country_code: str,
    rng: random.Random,
    strategy: str = DEFAULT_STRATEGY,
) -> str:
    """Returns the team_id the new career starts at. Raises invalid_request if
    the country has no league or no clubs in it — that is a world-data gap
    (a country added to countries.py without its competitions), so it surfaces
    as a request error naming the country rather than an IndexError."""
    picker: Optional[Callable] = STRATEGIES.get(strategy)
    if picker is None:
        raise errors.invalid_request(
            f"unknown team assignment strategy {strategy!r}, expected one of {tuple(STRATEGIES)}"
        )

    competition_id = find_lowest_league(conn, career_id, country_code)
    if competition_id is None:
        raise errors.invalid_request(f"no league is defined for country {country_code!r}")

    team_ids = league_team_ids(conn, career_id, season_id, competition_id)
    if not team_ids:
        raise errors.invalid_request(f"lowest league {competition_id!r} has no clubs")

    return picker(conn, career_id, team_ids, rng)
