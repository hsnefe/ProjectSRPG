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
from domain import day_budget, scheduling, team_assignment, wallet
from worlddata import positions as positions_data
from worlddata.attributes import starting_attributes
from worlddata.competitions import (
    BIRINCI_LIG, COMPETITION_RULES, COMPETITIONS, CUP_TEAM_IDS,
    STARTING_ENTRIES, SUPER_LIG, ULUSAL_KUPA,
)
from worlddata.countries import DEFAULT_COUNTRY_CODE, get_country
from worlddata.relationships import RELATIONSHIP_SEED, STARTING_SCORES
from worlddata.teams import ALL_TEAMS, TIER1_TEAMS, TIER2_TEAMS

SEASON_ID = "25/26"
SEASON_STARTS_ON = "2026-08-01"      # a Saturday; the career's own day 1
SEASON_ENDS_ON = "2027-05-31"

# League round 1 is a week after the season opens, so a new career starts
# with a full preparation week rather than a match on its very first day
# (§6.1: the day loop is what the user actually plays). Rounds are 7 days
# apart from here, so every league fixture falls on a Saturday.
LEAGUE_STARTS_ON = "2026-08-08"

# The cup runs midweek, between league rounds — 14 days apart from a
# Wednesday, so a cup round can never land on a league Saturday. Before
# this, both calendars ran on Saturdays and a team could be drawn into two
# fixtures on the same date, which M1's "today's match" query has no way to
# choose between.
CUP_STARTS_ON = "2026-08-19"

# A name field long enough for a double-barrelled surname, short enough that
# it can't push FE's cards out of shape. Not pinned by CONTRACT.md.
MAX_NAME_LENGTH = 40


def _require_name(value: str, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise errors.invalid_request(f"{field} must not be empty")
    cleaned = " ".join(value.split())
    if len(cleaned) > MAX_NAME_LENGTH:
        raise errors.invalid_request(f"{field} must be at most {MAX_NAME_LENGTH} characters")
    return cleaned


def create_career(
    conn: sqlite3.Connection,
    first_name: str,
    last_name: str,
    nationality: str,
    position: str,
    role: str,
    target_team_id: str,
    seed: Optional[int] = None,
) -> str:
    """Returns the new career_id. Does not commit - the router does, once,
    after this returns (INV-3).

    The starting club is NOT an argument: §3 assigns it from the player's
    nationality (bottom league of that country), so the only club the user
    picks is target_team_id, the one they're aiming for. That assignment
    happens after _seed_world because it reads the competition tables.
    """
    first_name = _require_name(first_name, "first_name")
    last_name = _require_name(last_name, "last_name")

    country = get_country(nationality)
    if country is None:
        from worlddata.countries import COUNTRY_CODES
        raise errors.invalid_request(
            f"nationality must be one of {COUNTRY_CODES}, got {nationality!r}"
        )

    if position not in positions_data.POSITIONS:
        raise errors.invalid_request(
            f"position must be one of {positions_data.POSITIONS}, got {position!r}"
        )

    role_data = positions_data.get_role(role)
    if role_data is None:
        raise errors.invalid_request(f"unknown role {role!r}")
    if role_data["position"] != position:
        # The core position/role compatibility check: a Forvet role can't be
        # played by a Defans. The message names what IS allowed so FE can
        # recover without a second round-trip to /careers/options.
        allowed = tuple(r["role_id"] for r in positions_data.roles_for_position(position))
        raise errors.invalid_request(
            f"role {role!r} belongs to position {role_data['position']!r}, "
            f"not {position!r}; roles for {position!r} are {allowed}"
        )

    known_team_ids = {t["team_id"] for t in ALL_TEAMS}
    if target_team_id not in known_team_ids:
        raise errors.invalid_request(f"unknown target_team_id {target_team_id!r}")

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
    team_id = team_assignment.assign_starting_team(
        conn, career_id, SEASON_ID, country["country_code"], rng
    )
    _seed_player(
        conn, career_id,
        first_name=first_name, last_name=last_name,
        nationality=country["country_code"], position=position, role=role,
        team_id=team_id, target_team_id=target_team_id,
    )
    _seed_relationships(conn, career_id)

    return career_id


def _seed_world(conn: sqlite3.Connection, career_id: str, rng: random.Random) -> None:
    for team in ALL_TEAMS:
        conn.execute(
            "INSERT INTO team (career_id, team_id, name, short_name, country, attack, midfield, "
            "defense, goalkeeper, mentality, color_primary, color_secondary) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                career_id, team["team_id"], team["name"], team["short_name"],
                team.get("country", DEFAULT_COUNTRY_CODE),
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
            career_id, SEASON_ID, competition_id, ids, LEAGUE_STARTS_ON
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


def _seed_player(
    conn: sqlite3.Connection,
    career_id: str,
    first_name: str,
    last_name: str,
    nationality: str,
    position: str,
    role: str,
    team_id: str,
    target_team_id: str,
) -> None:
    player_id = config.USER_PLAYER_ID
    birth_year = date.today().year - 21
    conn.execute(
        "INSERT INTO player (career_id, player_id, name, first_name, last_name, nationality, "
        "position, role, birth_date, team_id, target_team_id, is_user) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)",
        (
            career_id, player_id, f"{first_name} {last_name}", first_name, last_name,
            nationality, position, role, f"{birth_year}-08-19", team_id, target_team_id,
        ),
    )
    # Role decides the starting spread (§2); the skill exams then move
    # shooting/passing/tackling on top of it, via domain/skill_exams.py.
    for key, value in starting_attributes(role).items():
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
                career_id, r["relationship_id"], r["kind"], r["category"],
                STARTING_SCORES[r["kind"]],
                r["person_name"], r["contact_name"], r["age"], r["occupation"], r["bio"],
                json.dumps(traits, ensure_ascii=False),
            ),
        )
