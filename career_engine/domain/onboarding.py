"""§5.1 C1 - everything a brand-new career needs, written in the caller's
transaction (INV-3: one logical action, all-or-nothing).

D9: the world itself (team roster, competitions, rules) is identical
across every career - what create_career() actually varies per career is
just which career_id all these rows are filed under, plus the seed-shuffled
fixture order and cup draw. Every table is keyed by career_id (D10), so
"the same fixed world" still means writing full copies of it per career.
"""
import random
import sqlite3
from datetime import date, timedelta
from typing import Optional

from api import config, errors
from api.ids import new_career_id
from domain import day_budget, scheduling, wallet
from worlddata.attributes import STARTING_ATTRIBUTES
from worlddata.competitions import (
    BIRINCI_LIG, COMPETITION_RULES, COMPETITIONS, CUP_TEAM_IDS,
    STARTING_ENTRIES, SUPER_LIG, ULUSAL_KUPA,
)
from worlddata.relationships import RELATIONSHIP_SEED, STARTING_SCORE
from worlddata.teams import ALL_TEAMS, TIER1_TEAMS, TIER2_TEAMS

SEASON_ID = "25/26"
SEASON_STARTS_ON = "2026-08-01"
SEASON_ENDS_ON = "2027-05-31"

# The cup's own calendar starts later than the league season — a real
# domestic cup is interspersed between league rounds, not kicked off the
# same day. Without this offset, cup round 1 and league round 1 land on
# the literal same kickoff_at (both computed from day 0 of their own
# schedule), which is unrealistic and made the user's "next match" pick
# between two same-instant fixtures depending on row order. Two weeks in
# gives the league its first two rounds before the cup begins.
CUP_STARTS_ON = "2026-08-15"

_VALID_POSITIONS = ("Kaleci", "Defans", "Orta saha", "Forvet")


def create_career(
    conn: sqlite3.Connection,
    player_name: str,
    position: str,
    team_id: str,
    seed: Optional[int] = None,
) -> str:
    """Returns the new career_id. Does not commit - the router does, once,
    after this returns (INV-3)."""
    if position not in _VALID_POSITIONS:
        raise errors.invalid_request(f"position must be one of {_VALID_POSITIONS}, got {position!r}")

    tier2_ids = {t["team_id"] for t in TIER2_TEAMS}
    if team_id not in tier2_ids:
        # D21: the user always starts in the bottom tier (1. Lig).
        raise errors.invalid_request(f"team_id {team_id!r} is not a tier-2 club (D21)")

    seed_value = seed if seed is not None else random.SystemRandom().randint(0, 2**31 - 1)
    rng = random.Random(seed_value)

    career_id = new_career_id()
    created_at = f"{date.today().isoformat()}T00:00:00+03:00"

    conn.execute(
        "INSERT INTO career (career_id, created_at, seed, schema_version) VALUES (?, ?, ?, ?)",
        (career_id, created_at, seed_value, 1),
    )
    conn.execute(
        "INSERT INTO career_state (career_id, game_date, season_id, money, condition) "
        "VALUES (?, ?, ?, ?, ?)",
        (career_id, SEASON_STARTS_ON, SEASON_ID, 0, config.STARTING_CONDITION),
    )
    wallet.apply(
        conn, career_id, config.STARTING_MONEY, "starting_balance", "career:init", SEASON_STARTS_ON
    )
    day_budget.refill(conn, career_id)

    _seed_world(conn, career_id, rng)
    _seed_player(conn, career_id, player_name, position, team_id)
    _seed_relationships(conn, career_id)

    return career_id


def _seed_world(conn: sqlite3.Connection, career_id: str, rng: random.Random) -> None:
    for team in ALL_TEAMS:
        conn.execute(
            "INSERT INTO team (career_id, team_id, name, short_name, country, attack, midfield, "
            "defense, goalkeeper, mentality, color_primary, color_secondary) "
            "VALUES (?, ?, ?, ?, 'TR', ?, ?, ?, ?, ?, ?, ?)",
            (
                career_id, team["team_id"], team["name"], team["short_name"],
                team["attack"], team["midfield"], team["defense"], team["goalkeeper"],
                team["mentality"], team["color_primary"], team["color_secondary"],
            ),
        )

    for comp in COMPETITIONS:
        conn.execute(
            "INSERT INTO competition (career_id, competition_id, kind, name, country, tier, "
            "format, team_count) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                career_id, comp["competition_id"], comp["kind"], comp["name"],
                comp["country"], comp["tier"], comp["format"], comp["team_count"],
            ),
        )

    for competition_id, rule in COMPETITION_RULES.items():
        conn.execute(
            "INSERT INTO competition_rule (career_id, competition_id, promote_count, "
            "relegate_count, promotes_to_competition_id, relegates_to_competition_id) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            (
                career_id, competition_id, rule["promote_count"], rule["relegate_count"],
                rule["promotes_to_competition_id"], rule["relegates_to_competition_id"],
            ),
        )

    for competition_id, tid in STARTING_ENTRIES:
        conn.execute(
            "INSERT INTO competition_entry (career_id, season_id, competition_id, team_id) "
            "VALUES (?, ?, ?, ?)",
            (career_id, SEASON_ID, competition_id, tid),
        )

    conn.execute(
        "INSERT INTO season (career_id, season_id, starts_on, ends_on) VALUES (?, ?, ?, ?)",
        (career_id, SEASON_ID, SEASON_STARTS_ON, SEASON_ENDS_ON),
    )

    # D9: seed shuffles fixture order (not the roster) — each league gets
    # its own independent shuffle of the same fixed team list.
    for competition_id, teams in ((SUPER_LIG, TIER1_TEAMS), (BIRINCI_LIG, TIER2_TEAMS)):
        ids = [t["team_id"] for t in teams]
        rng.shuffle(ids)
        rounds, fixtures = scheduling.generate_league_season(
            career_id, SEASON_ID, competition_id, ids, SEASON_STARTS_ON
        )
        _insert_rounds(conn, rounds)
        _insert_fixtures(conn, fixtures)

    cup_rounds = scheduling.generate_cup_calendar(
        career_id, SEASON_ID, ULUSAL_KUPA, len(CUP_TEAM_IDS), CUP_STARTS_ON
    )
    _insert_rounds(conn, cup_rounds)

    # Round 1 (r32) has no prior-round dependency, so it's drawn immediately
    # alongside the calendar — later rounds stay undrawn until their
    # predecessor is played (§3.3, §6.7's cup-draw event).
    round1_kickoff = f"{cup_rounds[0]['scheduled_on']}T20:00:00+03:00"
    round1_fixtures = scheduling.draw_cup_round(
        career_id, SEASON_ID, ULUSAL_KUPA, 1, round1_kickoff, CUP_TEAM_IDS, rng=rng
    )
    _insert_fixtures(conn, round1_fixtures)
    conn.execute(
        "UPDATE competition_round SET drawn = 1 "
        "WHERE career_id = ? AND season_id = ? AND competition_id = ? AND round_no = 1",
        (career_id, SEASON_ID, ULUSAL_KUPA),
    )


def _insert_rounds(conn: sqlite3.Connection, rounds: list) -> None:
    conn.executemany(
        "INSERT INTO competition_round (career_id, season_id, competition_id, round_no, "
        "stage, scheduled_on, drawn) VALUES (:career_id, :season_id, :competition_id, "
        ":round_no, :stage, :scheduled_on, :drawn)",
        rounds,
    )


def _insert_fixtures(conn: sqlite3.Connection, fixtures: list) -> None:
    conn.executemany(
        "INSERT INTO fixture (career_id, fixture_id, season_id, competition_id, round_no, "
        "leg, kickoff_at, home_team_id, away_team_id, status, home_score, away_score, match_id) "
        "VALUES (:career_id, :fixture_id, :season_id, :competition_id, :round_no, :leg, "
        ":kickoff_at, :home_team_id, :away_team_id, :status, :home_score, :away_score, :match_id)",
        fixtures,
    )


def _seed_player(conn: sqlite3.Connection, career_id: str, name: str, position: str, team_id: str) -> None:
    player_id = config.USER_PLAYER_ID
    birth_year = date.today().year - 21
    conn.execute(
        "INSERT INTO player (career_id, player_id, name, position, birth_date, team_id, is_user) "
        "VALUES (?, ?, ?, ?, ?, ?, 1)",
        (career_id, player_id, name, position, f"{birth_year}-08-19", team_id),
    )
    for key, value in STARTING_ATTRIBUTES.items():
        conn.execute(
            "INSERT INTO player_attribute (career_id, player_id, attribute_key, value) "
            "VALUES (?, ?, ?, ?)",
            (career_id, player_id, key, value),
        )
    signed_at = SEASON_STARTS_ON
    expires_at = (date.fromisoformat(SEASON_STARTS_ON) + timedelta(days=config.CONTRACT_LENGTH_DAYS)).isoformat()
    conn.execute(
        "INSERT INTO player_contract (career_id, player_id, team_id, signed_at, expires_at, "
        "weekly_wage, appearance_bonus, goal_bonus, release_clause) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (
            career_id, player_id, team_id, signed_at, expires_at,
            config.STARTING_WEEKLY_WAGE, config.STARTING_APPEARANCE_BONUS,
            config.STARTING_GOAL_BONUS, config.STARTING_RELEASE_CLAUSE,
        ),
    )


def _seed_relationships(conn: sqlite3.Connection, career_id: str) -> None:
    import json

    from domain import relationships as relationships_domain

    for r in RELATIONSHIP_SEED:
        raw_traits = {"hobbies": r["hobbies"], **r.get("traits_extra", {})}
        traits = relationships_domain.validate_traits(r["kind"], raw_traits)  # INV-16, even at seed time
        conn.execute(
            "INSERT INTO relationship (career_id, relationship_id, kind, category, score, "
            "person_name, contact_name, age, occupation, bio, last_contact_at, traits) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?)",
            (
                career_id, r["relationship_id"], r["kind"], r["category"], STARTING_SCORE,
                r["person_name"], r["contact_name"], r["age"], r["occupation"], r["bio"],
                json.dumps(traits, ensure_ascii=False),
            ),
        )
