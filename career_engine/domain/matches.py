"""§5.6 M1-M3 - the user's own match: kicking it off, recording its result
(with D33/D34's strict validation), and recovering from a lost session.

Unlike T3's background fixtures, this match is played interactively via
FE + match_engine directly (D33) — career_engine never calls match_engine
for it, only hands out the payload (M1) and records what FE reports back
(M2)."""
import random
import sqlite3
from typing import Optional

from api import config, errors, serializers
from catalog.match_actions import ACTION_SCHEMAS, BINARY_OUTCOMES, GRADED_OUTCOMES, is_goal
from domain import condition, daytime, formulas, wallet

_STATS_KEYS = {
    "goals", "shots", "shots_on_target", "corners", "dangerous_attacks",
    "total_attacks", "yellow_cards", "red_cards", "penalties", "penalty_goals",
    "fouls", "substitutions", "possession_ticks",
}


def _team_row(conn: sqlite3.Connection, career_id: str, team_id: str) -> sqlite3.Row:
    return conn.execute(
        "SELECT * FROM team WHERE career_id = ? AND team_id = ?", (career_id, team_id)
    ).fetchone()


def _team_engine_fields(row: sqlite3.Row) -> dict:
    return {"name": row["name"], "mentality": row["mentality"], **formulas.compute_team_rating(dict(row))}


def build_next_match_payload(conn: sqlite3.Connection, career_id: str) -> dict:
    """§5.6 M1. Marks the fixture 'in_progress' as a side effect of handing
    out its payload — the one exception to this being a GET — so a second
    call for the same fixture hits match_in_progress instead of minting a
    second, inconsistent engine_payload (§6.4)."""
    user_team_id = serializers.fetch_user_team_id(conn, career_id)

    in_progress = conn.execute(
        "SELECT fixture_id FROM fixture WHERE career_id = ? AND status = 'in_progress' "
        "AND (home_team_id = ? OR away_team_id = ?)",
        (career_id, user_team_id, user_team_id),
    ).fetchone()
    if in_progress:
        raise errors.match_in_progress(in_progress["fixture_id"])

    fixture = conn.execute(
        "SELECT * FROM fixture WHERE career_id = ? AND status = 'scheduled' "
        "AND (home_team_id = ? OR away_team_id = ?) ORDER BY kickoff_at ASC LIMIT 1",
        (career_id, user_team_id, user_team_id),
    ).fetchone()
    if fixture is None:
        raise errors.invalid_request("no upcoming fixture for the user's team")

    home_row = _team_row(conn, career_id, fixture["home_team_id"])
    away_row = _team_row(conn, career_id, fixture["away_team_id"])
    user_side = "home" if fixture["home_team_id"] == user_team_id else "away"
    condition_value = conn.execute(
        "SELECT condition FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["condition"]

    payload = {
        "fixture_id": fixture["fixture_id"],
        "competition": serializers.fetch_competition_ref(conn, career_id, fixture["competition_id"]),
        "kickoff_at": fixture["kickoff_at"],
        "user_side": user_side,
        "engine_payload": {
            "teams": {
                "home": _team_engine_fields(home_row),
                "away": _team_engine_fields(away_row),
            },
            "user_side": user_side,
            # D38/D39 — top-level, not inside a team block: never written to
            # the engine's own Team.stamina.
            "user_condition": condition_value,
            "client_seed": random.SystemRandom().randint(0, 2**31 - 1),
        },
    }

    conn.execute(
        "UPDATE fixture SET status = 'in_progress' WHERE career_id = ? AND fixture_id = ?",
        (career_id, fixture["fixture_id"]),
    )
    conn.commit()
    return payload


def validate_result(body: dict, pre_match_condition: int) -> None:
    """§5.6 M2 D33/D34, INV-23. Raises invalid_match_result (422) on the
    first violation found; body is accepted as a raw dict specifically so
    every violation funnels into this one documented error code instead of
    FastAPI's own {"detail": [...]} shape."""
    for field in ("match_id", "score", "stats", "final_possession_home", "final_condition"):
        if field not in body:
            raise errors.invalid_match_result(f"missing field {field!r}")

    score, stats = body["score"], body["stats"]
    if not isinstance(score, dict) or set(score.keys()) != {"home", "away"}:
        raise errors.invalid_match_result("score must have exactly home/away")
    if not isinstance(stats, dict) or set(stats.keys()) != {"home", "away"}:
        raise errors.invalid_match_result("stats must have exactly home/away")

    for side in ("home", "away"):
        side_stats = stats[side]
        if not isinstance(side_stats, dict) or set(side_stats.keys()) != _STATS_KEYS:
            raise errors.invalid_match_result(f"stats.{side} must have exactly the 13 documented keys")
        if not isinstance(score[side], int) or score[side] != side_stats["goals"]:
            raise errors.invalid_match_result(f"score.{side} does not match stats.{side}.goals")

    last_minute = 0
    for i, iv in enumerate(body.get("interventions", [])):
        for field in ("minute", "action_key", "outcome_key"):
            if field not in iv:
                raise errors.invalid_match_result(f"interventions[{i}] missing {field!r}")
        minute, action_key, outcome_key = iv["minute"], iv["action_key"], iv["outcome_key"]
        if not (1 <= minute <= 95):
            raise errors.invalid_match_result(f"interventions[{i}].minute out of 1-95 range")
        if minute <= last_minute:
            raise errors.invalid_match_result(f"interventions[{i}].minute not strictly increasing")
        last_minute = minute

        schema = ACTION_SCHEMAS.get(action_key)
        if schema is None:
            raise errors.invalid_match_result(f"unknown action_key {action_key!r}")
        valid_outcomes = GRADED_OUTCOMES if schema == "graded" else BINARY_OUTCOMES
        if outcome_key not in valid_outcomes:
            raise errors.invalid_match_result(
                f"outcome_key {outcome_key!r} invalid for {schema} action {action_key!r}"
            )

    final_condition = body["final_condition"]
    if not isinstance(final_condition, int) or not (35 <= final_condition <= 100):
        raise errors.invalid_match_result("final_condition must be an integer in 35-100")
    if final_condition > pre_match_condition:
        raise errors.invalid_match_result("final_condition exceeds pre-match condition")


def apply_result(conn: sqlite3.Connection, career_id: str, fixture_id: str, body: dict) -> dict:
    """§5.6 M2. Writes the user's own fixture, then (§2 flow, D8) runs
    that same day's other fixtures through the normal background-sim path
    so standings are consistent immediately rather than waiting for the
    next T3 call."""
    fixture = conn.execute(
        "SELECT * FROM fixture WHERE career_id = ? AND fixture_id = ?", (career_id, fixture_id)
    ).fetchone()
    if fixture is None:
        raise errors.fixture_not_found(fixture_id)
    if fixture["status"] == "played":
        raise errors.fixture_already_played(fixture_id)

    pre_match_condition = conn.execute(
        "SELECT condition FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["condition"]
    validate_result(body, pre_match_condition)

    user_team_id = serializers.fetch_user_team_id(conn, career_id)
    season_id, competition_id = fixture["season_id"], fixture["competition_id"]
    on_date = fixture["kickoff_at"][:10]
    happened_at = f"{on_date}T22:00:00+03:00"

    is_league = conn.execute(
        "SELECT 1 FROM competition WHERE career_id = ? AND competition_id = ? AND kind = 'league'",
        (career_id, competition_id),
    ).fetchone() is not None

    rank_before = _user_rank(conn, career_id, season_id, competition_id, user_team_id) if is_league else None

    conn.execute(
        "UPDATE fixture SET status = 'played', home_score = ?, away_score = ?, match_id = ? "
        "WHERE career_id = ? AND fixture_id = ?",
        (body["score"]["home"], body["score"]["away"], body["match_id"], career_id, fixture_id),
    )
    for side in ("home", "away"):
        s = body["stats"][side]
        conn.execute(
            "INSERT INTO fixture_team_stat (career_id, fixture_id, side, goals, shots, "
            "shots_on_target, corners, dangerous_attacks, total_attacks, yellow_cards, "
            "red_cards, penalties, penalty_goals, fouls, substitutions, possession_ticks) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (career_id, fixture_id, side, s["goals"], s["shots"], s["shots_on_target"],
             s["corners"], s["dangerous_attacks"], s["total_attacks"], s["yellow_cards"],
             s["red_cards"], s["penalties"], s["penalty_goals"], s["fouls"],
             s["substitutions"], s["possession_ticks"]),
        )

    condition.set_from_match(conn, career_id, body["final_condition"])

    goal_count = sum(
        1 for iv in body.get("interventions", []) if is_goal(iv["action_key"], iv["outcome_key"])
    )

    ledger_entries = []
    contract = conn.execute(
        "SELECT * FROM player_contract WHERE career_id = ? AND player_id = ? ORDER BY signed_at DESC LIMIT 1",
        (career_id, config.USER_PLAYER_ID),
    ).fetchone()
    if contract:
        if contract["appearance_bonus"]:
            ledger_entries.append(wallet.apply(
                conn, career_id, contract["appearance_bonus"], "appearance_bonus",
                f"appearance_bonus:{fixture_id}", happened_at,
            ))
        if goal_count and contract["goal_bonus"]:
            ledger_entries.append(wallet.apply(
                conn, career_id, contract["goal_bonus"] * goal_count, "goal_bonus",
                f"goal_bonus:{fixture_id}", happened_at,
            ))

    conn.execute(
        "INSERT INTO player_season_stat (career_id, player_id, season_id, competition_id, "
        "appearances, starts, goals, assists, minutes, passes_completed, passes_attempted) "
        "VALUES (?, ?, ?, ?, 1, 1, ?, 0, 95, 0, 0) "
        "ON CONFLICT (career_id, player_id, season_id, competition_id) DO UPDATE SET "
        "appearances = appearances + 1, starts = starts + 1, goals = goals + excluded.goals, "
        "minutes = minutes + 95",
        (career_id, config.USER_PLAYER_ID, season_id, competition_id, goal_count),
    )

    seed = conn.execute("SELECT seed FROM career WHERE career_id = ?", (career_id,)).fetchone()["seed"]
    sim = daytime._simulate_day_fixtures(conn, career_id, on_date, seed)
    other_results = sim["results"]

    cup_round = daytime._next_drawable_cup_round(conn, career_id, on_date)
    if cup_round:
        daytime._draw_cup_round(conn, career_id, cup_round["round_no"], on_date, seed)

    rank_after = _user_rank(conn, career_id, season_id, competition_id, user_team_id) if is_league else None

    home_ref = serializers.fetch_team_ref(conn, career_id, fixture["home_team_id"])
    away_ref = serializers.fetch_team_ref(conn, career_id, fixture["away_team_id"])
    news_id = daytime._create_news(
        conn, career_id, "Maç",
        f"{home_ref['name']} {body['score']['home']}-{body['score']['away']} {away_ref['name']}",
        "Maç sonuçlandı.", on_date,
    )

    conn.commit()

    return {
        "career_state": serializers.fetch_career_state(conn, career_id),
        "fixture": {"fixture_id": fixture_id, "status": "played", "score": body["score"]},
        "other_results": other_results,
        "standing_delta": {"rank_before": rank_before, "rank_after": rank_after},
        "player_stat_delta": {"appearances": 1, "goals": goal_count, "minutes": 95},
        "ledger_entries": ledger_entries,
        "news_created": [news_id],
    }


def _user_rank(conn, career_id, season_id, competition_id, user_team_id) -> Optional[int]:
    standings = serializers.fetch_full_standings(conn, career_id, season_id, competition_id)
    own = next((s for s in standings if s["team_id"] == user_team_id), None)
    return own["rank"] if own else None


def abandon_match(conn: sqlite3.Connection, career_id: str, fixture_id: str) -> dict:
    """§5.6 M3, §6.4 - recovers a fixture whose match_engine session was
    lost: back to 'scheduled' so M1 hands out a fresh engine_payload."""
    fixture = conn.execute(
        "SELECT status FROM fixture WHERE career_id = ? AND fixture_id = ?", (career_id, fixture_id)
    ).fetchone()
    if fixture is None:
        raise errors.fixture_not_found(fixture_id)
    if fixture["status"] != "in_progress":
        raise errors.fixture_not_in_progress(fixture_id)

    conn.execute(
        "UPDATE fixture SET status = 'scheduled' WHERE career_id = ? AND fixture_id = ?",
        (career_id, fixture_id),
    )
    conn.commit()
    return {
        "career_state": serializers.fetch_career_state(conn, career_id),
        "fixture": {"fixture_id": fixture_id, "status": "scheduled"},
    }
