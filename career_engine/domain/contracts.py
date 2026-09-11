"""§11.7/D50 - the contract's lifecycle.

A contract now ends on one of exactly two dates (INV-35): the first day of a
winter break, or the last day of a season. That is why length is counted in
seasons rather than days - `CONTRACT_LENGTH_DAYS = 730` lands on an arbitrary
Tuesday and can hit neither.

Three things were wrong before this module existed, and all three only bite
once a contract can actually run out:

1. `_latest_contract` ordered by `signed_at` and ignored `expires_at`, so an
   expired deal kept being "the" contract and `_pay_wage` kept paying from it
   forever. §11.7's free agent means *no active contract row*, which is a
   question that query could not ask.
2. `player_contract`'s key is (career_id, player_id, signed_at), so two
   contracts signed on the same game day collide - and signing the day the
   old one ends is exactly the normal case.
3. P3's `days_until_expiry` counted from `date.today()`, the wall clock,
   rather than from `game_date`. Harmless while no season ever turned over.
"""
import datetime as _dt
import sqlite3
from typing import Optional

from api import config
from domain import season as season_mod


def active_contract(
    conn: sqlite3.Connection, career_id: str, on_date: str
) -> Optional[sqlite3.Row]:
    """The contract in force on `on_date`, or None when the player is a free
    agent. Bounded at both ends: signed on or before today, expiring on or
    after it."""
    return conn.execute(
        "SELECT * FROM player_contract WHERE career_id = ? AND player_id = ? "
        "AND signed_at <= ? AND expires_at >= ? "
        "ORDER BY signed_at DESC LIMIT 1",
        (career_id, config.USER_PLAYER_ID, on_date, on_date),
    ).fetchone()


def latest_contract(conn: sqlite3.Connection, career_id: str) -> Optional[sqlite3.Row]:
    """The most recently signed one regardless of whether it still runs.
    For display, where "your last deal expired in June" is the useful
    answer; never for deciding whether to pay a wage."""
    return conn.execute(
        "SELECT * FROM player_contract WHERE career_id = ? AND player_id = ? "
        "ORDER BY signed_at DESC LIMIT 1",
        (career_id, config.USER_PLAYER_ID),
    ).fetchone()


def is_free_agent(conn: sqlite3.Connection, career_id: str, on_date: str) -> bool:
    return active_contract(conn, career_id, on_date) is None


def expiry_for(
    conn: sqlite3.Connection, career_id: str, signed_on: str, length_seasons: int
) -> str:
    """INV-35 - the end date is always a season boundary.

    Counted from the season the signature falls in (or, in the summer, from
    the season standing ahead): `length_seasons` whole seasons of football,
    ending on the last of their final days. A deal signed mid-season still
    covers the rest of that season plus the ones after it, which is what a
    player means by "three years".
    """
    row = season_mod.current_season_row(conn, career_id, signed_on)
    if row is None:
        row = conn.execute(
            "SELECT * FROM season WHERE career_id = ? AND starts_on > ? "
            "ORDER BY starts_on ASC LIMIT 1",
            (career_id, signed_on),
        ).fetchone()
    if row is None:
        # No season data at all: fall back to whole years from the signature
        # so the column is still a real date rather than null.
        signed = _dt.date.fromisoformat(signed_on)
        return signed.replace(year=signed.year + max(1, length_seasons)).isoformat()

    opening_year = _dt.date.fromisoformat(row["starts_on"]).year
    final = season_mod.calendar_for(opening_year + max(1, length_seasons) - 1)
    return final.ends_on.isoformat()


def days_until_expiry(contract: sqlite3.Row, on_date: str) -> int:
    """From `game_date`, never the wall clock — a career that has rolled over
    twice is years away from the machine's calendar."""
    return (
        _dt.date.fromisoformat(contract["expires_at"]) - _dt.date.fromisoformat(on_date)
    ).days


def sign(
    conn: sqlite3.Connection,
    career_id: str,
    team_id: str,
    signed_on: str,
    expires_at: str,
    weekly_wage: int,
    appearance_bonus: int,
    goal_bonus: int,
    release_clause: int,
) -> dict:
    """Writes a contract, replacing any signed on the same day.

    The REPLACE is the answer to the primary key: (career_id, player_id,
    signed_at) cannot hold two deals signed on one game day, and signing on
    the day the old one runs out is the ordinary case rather than an edge
    one. Replacing is right anyway - a player does not hold two contracts,
    and the later signature is the one that counts.
    """
    conn.execute(
        "INSERT OR REPLACE INTO player_contract (career_id, player_id, team_id, "
        "signed_at, expires_at, weekly_wage, appearance_bonus, goal_bonus, release_clause) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (career_id, config.USER_PLAYER_ID, team_id, signed_on, expires_at,
         weekly_wage, appearance_bonus, goal_bonus, release_clause),
    )
    return {
        "signed_at": signed_on,
        "expires_at": expires_at,
        "weekly_wage": weekly_wage,
        "appearance_bonus": appearance_bonus,
        "goal_bonus": goal_bonus,
        "release_clause": release_clause,
    }
