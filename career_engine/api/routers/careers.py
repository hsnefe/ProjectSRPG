"""§5.1 - C0-C4."""
import sqlite3

from fastapi import APIRouter, Depends

from api import errors, serializers
from api.deps import get_db
from api.schemas.career import CreateCareerRequest
from domain import onboarding
from worlddata.competitions import BIRINCI_LIG, COMPETITIONS
from worlddata.teams import TIER2_TEAMS

router = APIRouter(prefix="/careers", tags=["careers"])


@router.get("/options")
def get_options():
    birinci_lig = next(c for c in COMPETITIONS if c["competition_id"] == BIRINCI_LIG)
    return {
        "positions": ["Kaleci", "Defans", "Orta saha", "Forvet"],
        "clubs": [
            {
                "team": serializers.team_ref(team),
                "competition": serializers.worlddata_competition_ref(birinci_lig),
                "strength_hint": serializers.strength_hint(team),
            }
            for team in TIER2_TEAMS
        ],
    }


@router.post("", status_code=201)
def create_career(body: CreateCareerRequest, conn: sqlite3.Connection = Depends(get_db)):
    career_id = onboarding.create_career(
        conn, body.player_name, body.position, body.team_id, body.seed
    )
    conn.commit()
    return _build_hub(conn, career_id)


@router.get("")
def list_careers(conn: sqlite3.Connection = Depends(get_db)):
    rows = conn.execute(
        "SELECT c.career_id, c.created_at, cs.season_id, cs.game_date, p.name AS player_name, "
        "p.team_id FROM career c "
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
        "player_value_history", "player_season_stat", "player_contract", "player",
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
        "SELECT name, position, birth_date, team_id FROM player "
        "WHERE career_id = ? AND is_user = 1",
        (career_id,),
    ).fetchone()
    import datetime as _dt
    birth_date = _dt.date.fromisoformat(player_row["birth_date"])
    today = _dt.date.today()
    age = today.year - birth_date.year - ((today.month, today.day) < (birth_date.month, birth_date.day))

    player = {
        "name": player_row["name"],
        "position": player_row["position"],
        "age": age,
        "team": serializers.fetch_team_ref(conn, career_id, player_row["team_id"]),
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
