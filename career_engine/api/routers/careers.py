"""§5.1 - C0-C4, plus the skill-exam submission (§2) that follows creation."""
import sqlite3

from fastapi import APIRouter, Depends

from api import config, errors, serializers
from api.deps import get_db
from api.schemas.career import CreateCareerRequest, SubmitSkillExamsRequest
from catalog.skill_exams import MAX_LEVEL, MIN_LEVEL, SKILL_EXAMS
from domain import onboarding, skill_exams
from worlddata import positions as positions_data
from worlddata.attributes import BASE_SKILL_VALUE, ROLE_BONUS_PER_SLOT
from worlddata.competitions import COMPETITIONS, STARTING_ENTRIES
from worlddata.countries import COUNTRIES
from worlddata.relationships import STARTING_SCORES
from worlddata.teams import ALL_TEAMS

router = APIRouter(prefix="/careers", tags=["careers"])


@router.get("/options")
def get_options():
    """Everything the "Yeni Kariyer" form needs, in one call: which
    nationalities exist, which positions and — per position — which roles,
    every club that may be named as a target, and the exam/starting-value
    tables so FE can preview them without duplicating the numbers."""
    # Which league each club plays in, straight from the worlddata entries so
    # /options stays career-independent (no DB read, same as before). Cup
    # entries are skipped — every club is in the cup, so it says nothing about
    # where a club belongs.
    competitions_by_id = {c["competition_id"]: c for c in COMPETITIONS}
    team_competition = {
        team_id: competitions_by_id[competition_id]
        for competition_id, team_id in STARTING_ENTRIES
        if competitions_by_id[competition_id]["kind"] == "league"
    }

    return {
        "nationalities": [
            {
                "country_code": c["country_code"],
                "name": c["name"],
                "nationality": c["nationality"],
            }
            for c in COUNTRIES
        ],
        "positions": [
            {
                "position": position,
                "roles": [
                    {
                        "role_id": role["role_id"],
                        "name": role["name"],
                        "group": role["group"],
                        "attributes": list(role["attributes"]),
                    }
                    for role in positions_data.roles_for_position(position)
                ],
            }
            for position in positions_data.POSITIONS
        ],
        # Any club may be a dream club — unlike the old `clubs` list, this is
        # not a pick of where you start (§3 assigns that from nationality).
        "target_teams": [
            {
                "team": serializers.team_ref(team),
                "competition": (
                    serializers.worlddata_competition_ref(team_competition[team["team_id"]])
                    if team_competition.get(team["team_id"]) else None
                ),
                "strength_hint": serializers.strength_hint(team),
            }
            for team in ALL_TEAMS
        ],
        "skill_exams": [
            {
                "exam_id": e["exam_id"],
                "title": e["title"],
                "description": e["description"],
                "attribute_key": e["attribute_key"],
                "points_per_level": e["points_per_level"],
                "min_level": MIN_LEVEL,
                "max_level": MAX_LEVEL,
                "max_value": e["max_value"],
            }
            for e in SKILL_EXAMS
        ],
        "starting_values": {
            "money": config.STARTING_MONEY,
            "condition": config.STARTING_CONDITION,
            "relationships": dict(STARTING_SCORES),
            "base_skill_value": BASE_SKILL_VALUE,
            "role_bonus_per_slot": ROLE_BONUS_PER_SLOT,
        },
    }


@router.post("", status_code=201)
def create_career(body: CreateCareerRequest, conn: sqlite3.Connection = Depends(get_db)):
    career_id = onboarding.create_career(
        conn,
        first_name=body.first_name,
        last_name=body.last_name,
        nationality=body.nationality,
        position=body.position,
        role=body.role,
        target_team_id=body.target_team_id,
        seed=body.seed,
    )
    conn.commit()
    return _build_hub(conn, career_id)


@router.post("/{career_id}/skill-exams")
def submit_skill_exams(
    career_id: str,
    body: SubmitSkillExamsRequest,
    conn: sqlite3.Connection = Depends(get_db),
):
    """§2 - grades in, attribute points out. Applied against the career's
    current game_date so the write is dated inside the career's own timeline,
    not the wall clock."""
    serializers.require_career(conn, career_id)
    state = serializers.fetch_career_state(conn, career_id)

    changes = skill_exams.apply_results(
        conn,
        career_id,
        config.USER_PLAYER_ID,
        [r.model_dump() for r in body.results],
        state["current_date"],
    )
    conn.commit()
    return {"career_id": career_id, "results": changes}


@router.get("")
def list_careers(conn: sqlite3.Connection = Depends(get_db)):
    rows = conn.execute(
        "SELECT c.career_id, c.created_at, cs.season_id, cs.game_date, p.name AS player_name, "
        "p.birth_date, p.team_id FROM career c "
        "JOIN career_state cs ON cs.career_id = c.career_id "
        "JOIN player p ON p.career_id = c.career_id AND p.is_user = 1 "
        "ORDER BY c.created_at DESC"
    ).fetchall()

    careers = []
    for row in rows:
        team = serializers.fetch_team_ref(conn, row["career_id"], row["team_id"])
        league_id = serializers.fetch_user_league_competition_id(conn, row["career_id"], row["season_id"])
        competition = (
            serializers.fetch_competition_ref(conn, row["career_id"], league_id) if league_id else None
        )
        standing_rank = None
        if league_id:
            standings = serializers.fetch_full_standings(conn, row["career_id"], row["season_id"], league_id)
            own = next((s for s in standings if s["team_id"] == row["team_id"]), None)
            standing_rank = own["rank"] if own else None

        careers.append({
            "career_id": row["career_id"],
            "player_name": row["player_name"],
            "player_age": serializers.age_from_birth_date(row["birth_date"]),
            "team": team,
            "competition": competition,
            "season_id": row["season_id"],
            "current_date": row["game_date"],
            "created_at": row["created_at"],
            "standing_rank": standing_rank,
        })
    return {"careers": careers}


@router.get("/{career_id}")
def get_career(career_id: str, conn: sqlite3.Connection = Depends(get_db)):
    return _build_hub(conn, career_id)


@router.delete("/{career_id}", status_code=204)
def delete_career(career_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    # INV-9: every row for this career_id disappears. CONTRACT.md's §3 SQL
    # doesn't declare ON DELETE CASCADE for most of these tables (only
    # player_attribute → player has a real FK, §3.2), so this is an
    # explicit, exhaustive purge rather than relying on cascade.
    tables = [
        "day_budget", "player_attribute", "player_fame", "fame_event",
        "player_value_history", "player_season_stat", "player_contract",
        "skill_exam_result", "player",
        "competition_entry", "competition_rule", "competition_round", "fixture_team_stat",
        "fixture", "season", "competition", "team",
        "relationship_event", "relationship",
        "news", "activity_log", "inventory", "money_ledger",
        "career_state", "career",
    ]
    for table in tables:
        conn.execute(f"DELETE FROM {table} WHERE career_id = ?", (career_id,))
    conn.commit()
    return None


def _build_hub(conn: sqlite3.Connection, career_id: str) -> dict:
    serializers.require_career(conn, career_id)
    career_state = serializers.fetch_career_state(conn, career_id)

    player_row = conn.execute(
        "SELECT name, first_name, last_name, nationality, position, role, birth_date, "
        "team_id, target_team_id FROM player WHERE career_id = ? AND is_user = 1",
        (career_id,),
    ).fetchone()
    age = serializers.age_from_birth_date(player_row["birth_date"])

    role_data = positions_data.get_role(player_row["role"]) if player_row["role"] else None

    player = {
        "name": player_row["name"],
        "first_name": player_row["first_name"],
        "last_name": player_row["last_name"],
        "nationality": player_row["nationality"],
        "position": player_row["position"],
        # role_name is None for careers created before roles existed; the id
        # is still echoed so FE can tell "no role" from "unknown role".
        "role": player_row["role"],
        "role_name": role_data["name"] if role_data else None,
        "age": age,
        "team": serializers.fetch_team_ref(conn, career_id, player_row["team_id"]),
        "target_team": (
            serializers.fetch_team_ref(conn, career_id, player_row["target_team_id"])
            if player_row["target_team_id"] else None
        ),
    }

    next_fixture = serializers.fetch_next_fixture(conn, career_id, player_row["team_id"])

    league_id = serializers.fetch_user_league_competition_id(conn, career_id, career_state["season_id"])
    standing_summary = None
    if league_id:
        standings = serializers.fetch_full_standings(conn, career_id, career_state["season_id"], league_id)
        own = next((s for s in standings if s["team_id"] == player_row["team_id"]), None)
        rule = conn.execute(
            "SELECT promote_count, relegate_count FROM competition_rule "
            "WHERE career_id = ? AND competition_id = ?",
            (career_id, league_id),
        ).fetchone()
        standing_summary = {
            "competition_id": league_id,
            "rank": own["rank"] if own else None,
            "played": own["played"] if own else 0,
            "points": own["points"] if own else 0,
            "promotion_slots": rule["promote_count"] if rule else 0,
            "relegation_slots": rule["relegate_count"] if rule else 0,
        }

    news_rows = conn.execute(
        "SELECT news_id, category, title, source, published_at FROM news "
        "WHERE career_id = ? ORDER BY published_at DESC LIMIT 5",
        (career_id,),
    ).fetchall()

    return {
        "career_id": career_id,
        "career_state": career_state,
        "player": player,
        "next_fixture": next_fixture,
        "standing_summary": standing_summary,
        "news_preview": [dict(r) for r in news_rows],
    }
