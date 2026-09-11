"""§5.6 M1-M3 - the user's own match: kicking it off, recording its result
(with D33/D34's strict validation), and recovering from a lost session.

Unlike T3's background fixtures, this match is played interactively via
FE + match_engine directly (D33) — career_engine never calls match_engine
for it, only hands out the payload (M1) and records what FE reports back
(M2)."""
import datetime as _dt
import random
import sqlite3
from typing import Optional

from api import config, errors, serializers
from catalog.match_actions import ACTION_SCHEMAS, OUTCOME_SETS, is_assist, is_goal
from domain import condition, daytime, formulas, relationships, wallet
from worlddata.formations import DEFAULT_FORMATION
from worlddata.teams import ALL_TEAMS

_STATS_KEYS = {
    "goals", "shots", "shots_on_target", "corners", "dangerous_attacks",
    "total_attacks", "yellow_cards", "red_cards", "penalties", "penalty_goals",
    "fouls", "substitutions", "possession_ticks",
}


def _team_row(conn: sqlite3.Connection, career_id: str, team_id: str) -> sqlite3.Row:
    return conn.execute(
        "SELECT * FROM team WHERE career_id = ? AND team_id = ?", (career_id, team_id)
    ).fetchone()


_FORMATIONS_BY_TEAM = {t["team_id"]: t["formation"] for t in ALL_TEAMS}


def _formation_for(team_id: str) -> str:
    """Takımın dizilişi. `team` tablosundan değil worlddata'dan okunuyor:
    diziliş D9 gereği her kariyerde aynı statik dünya verisi, tıpkı
    positions.py'nin rol kataloğu gibi — kariyer başına kopyalanırsa
    kopyayla kaynak ayrışabilir. Takım başına diziliş kariyer içinde
    değişebilir olsun istenirse 003_world.sql'e kolon eklenmesi gerekir."""
    return _FORMATIONS_BY_TEAM.get(team_id, DEFAULT_FORMATION)


def _team_engine_fields(row: sqlite3.Row) -> dict:
    return {"name": row["name"], "mentality": row["mentality"], **formulas.compute_team_rating(dict(row))}


def _not_match_day(conn: sqlite3.Connection, career_id: str, user_team_id: str, game_date: str):
    """The 409 M1 raises when today isn't a match day, carrying the next
    kickoff date and how far off it is (FE writes the countdown sentence,
    §1.3). A fixture still 'scheduled' with a kickoff already in the past
    is skipped: the user advanced past it, so it was played without them
    (§6.1's missed-match rule) or is about to be."""
    upcoming = conn.execute(
        "SELECT kickoff_at FROM fixture WHERE career_id = ? AND status = 'scheduled' "
        "AND (home_team_id = ? OR away_team_id = ?) AND kickoff_at > ? "
        "ORDER BY kickoff_at ASC LIMIT 1",
        (career_id, user_team_id, user_team_id, game_date),
    ).fetchone()
    if upcoming is None:
        return errors.not_match_day()
    kickoff_on = upcoming["kickoff_at"][:10]
    days_until = (_dt.date.fromisoformat(kickoff_on) - _dt.date.fromisoformat(game_date)).days
    return errors.not_match_day(kickoff_on, days_until)


def build_next_match_payload(conn: sqlite3.Connection, career_id: str) -> dict:
    """§5.6 M1. Marks the fixture 'in_progress' as a side effect of handing
    out its payload — the one exception to this being a GET — so a second
    call for the same fixture hits match_in_progress instead of minting a
    second, inconsistent engine_payload (§6.4).

    §6.1: only *today's* fixture is handed out. Without that gate the user
    can play the whole season inside a single game day — nothing else in
    the design forces `POST /advance` to ever be called, and the week
    between matches (the day loop this service exists to run) never
    happens."""
    user_team_id = serializers.fetch_user_team_id(conn, career_id)

    in_progress = conn.execute(
        "SELECT fixture_id FROM fixture WHERE career_id = ? AND status = 'in_progress' "
        "AND (home_team_id = ? OR away_team_id = ?)",
        (career_id, user_team_id, user_team_id),
    ).fetchone()
    if in_progress:
        raise errors.match_in_progress(in_progress["fixture_id"])

    game_date = conn.execute(
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"]

    fixture = conn.execute(
        "SELECT * FROM fixture WHERE career_id = ? AND status = 'scheduled' "
        "AND (home_team_id = ? OR away_team_id = ?) AND kickoff_at LIKE ? "
        "ORDER BY kickoff_at ASC LIMIT 1",
        (career_id, user_team_id, user_team_id, f"{game_date}%"),
    ).fetchone()
    if fixture is None:
        raise _not_match_day(conn, career_id, user_team_id, game_date)

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
        # Kullanıcının takımının dizilişi. `engine_payload`'ın **dışında**:
        # o gövde motora olduğu gibi POST'lanıyor ve motor diziliş bilmiyor.
        "formation_id": _formation_for(user_team_id),
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
        valid_outcomes = OUTCOME_SETS[schema]
        if outcome_key not in valid_outcomes:
            raise errors.invalid_match_result(
                f"outcome_key {outcome_key!r} invalid for {schema} action {action_key!r}"
            )

    # §5.6 M2 - the user's OWN discipline, not the team's. Optional: the field
    # only carries a non-zero value once match_engine attributes a card to a
    # named player, which v1 does not do (see _match_relationship_deltas).
    user_cards = body.get("user_cards")
    if user_cards is not None:
        if not isinstance(user_cards, dict) or set(user_cards.keys()) != {"yellow", "red"}:
            raise errors.invalid_match_result("user_cards must have exactly yellow/red")
        if not isinstance(user_cards["yellow"], int) or not (0 <= user_cards["yellow"] <= 2):
            raise errors.invalid_match_result("user_cards.yellow must be an integer in 0-2")
        if not isinstance(user_cards["red"], int) or not (0 <= user_cards["red"] <= 1):
            raise errors.invalid_match_result("user_cards.red must be an integer in 0-1")

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
    user_side = "home" if fixture["home_team_id"] == user_team_id else "away"
    opponent_side = "away" if user_side == "home" else "home"
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

    interventions = body.get("interventions", [])
    goal_count = sum(1 for iv in interventions if is_goal(iv["action_key"], iv["outcome_key"]))
    assist_count = sum(1 for iv in interventions if is_assist(iv["action_key"], iv["outcome_key"]))

    deltas, match_result = _match_relationship_deltas(
        body["score"], user_side, opponent_side,
        body.get("user_cards") or {"yellow": 0, "red": 0}, goal_count,
    )
    relationship_changes = [
        relationships.apply_delta(
            conn, career_id, rel_id, delta, f"match:{fixture_id}:{match_result}", happened_at,
        )
        for rel_id, delta in deltas.items()
    ]

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
        "VALUES (?, ?, ?, ?, 1, 1, ?, ?, 95, 0, 0) "
        "ON CONFLICT (career_id, player_id, season_id, competition_id) DO UPDATE SET "
        "appearances = appearances + 1, starts = starts + 1, goals = goals + excluded.goals, "
        "assists = assists + excluded.assists, minutes = minutes + 95",
        (career_id, config.USER_PLAYER_ID, season_id, competition_id, goal_count, assist_count),
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
        "player_stat_delta": {
            "appearances": 1, "goals": goal_count, "assists": assist_count, "minutes": 95,
        },
        "relationship_changes": relationship_changes,
        "ledger_entries": ledger_entries,
        "news_created": [news_id],
    }


def _match_relationship_deltas(
    score: dict, user_side: str, opponent_side: str, user_cards: dict, goal_count: int,
) -> tuple:
    """New M2 behavior: coach/team/fans/media each react to this one match,
    clamped to ±5. partner/family are deliberately untouched - the feature
    that asked for this only named these four, and worlddata/relationships
    .py's own note on partner/family starting at 0 ("you haven't called
    home yet") supports a match result not being their trigger; dialogue
    interactions (§5.4/R3) are their only path.

    Weighted by how much each side plausibly cares about a personal stat
    line vs. the bare result: coach weighs discipline + personal
    contribution heaviest (tactical trust); team is the most muted (the
    shared result matters more than your line); fans swing hardest on the
    scoreline and love goals; media is the most headline-driven - barely
    reacts to a plain draw, lights up for goals, and a sending-off is
    their biggest negative hook.

    Discipline reads `user_cards` - the USER's own cards - and never
    `stats[user_side]`, which is the whole team's block (_STATS_KEYS, the
    13 keys copied verbatim from match_engine). Reading the team block here
    punished the player for a team-mate's sending-off, contradicting
    §5.6's own wording ("sarı/kırmızı kart disiplini"), and the team's
    third yellow - routine in any match - fired the penalty nearly every
    game. It also double-counted: a red card already costs the side 15
    defence points in the engine (match_engine/models.py), so it is paid
    for in the scoreline these deltas are computed from.

    In v1 `user_cards` is always zero, and that is the correct answer
    rather than a stub: match_engine books an anonymous defender and never
    puts the carded player's identity on the wire, so the user cannot be
    sent off. The field is where FE writes the real count the day the
    engine attributes a card."""
    user_goals, opp_goals = score[user_side], score[opponent_side]
    result = "win" if user_goals > opp_goals else "loss" if user_goals < opp_goals else "draw"
    reds, yellows = user_cards["red"], user_cards["yellow"]

    # Thresholds are on the PERSONAL scale now, not the team's: one player
    # can collect at most two yellows (the second is itself a dismissal), so
    # the old team-shaped cut-offs of 3 and 2 would have been unreachable
    # and never-not-reached respectively.
    coach = {"win": 3, "draw": 1, "loss": -2}[result]
    coach += 1 if goal_count >= 1 else 0
    coach -= 2 if reds >= 1 else 0
    coach -= 1 if yellows >= 2 else 0

    team = {"win": 2, "draw": 0, "loss": -1}[result]
    team += 1 if goal_count >= 1 else 0
    team -= 1 if reds >= 1 else 0

    fans = {"win": 3, "draw": 0, "loss": -2}[result]
    fans += min(2, goal_count)
    fans -= 1 if reds >= 1 else 0

    media = {"win": 1, "draw": 0, "loss": -1}[result]
    media += min(2, goal_count)
    media -= 2 if reds >= 1 else 0
    media -= 1 if yellows >= 1 else 0

    def clamp(v):
        return max(-5, min(5, v))

    deltas = {
        "coach": clamp(coach), "team": clamp(team), "fans": clamp(fans), "media": clamp(media),
    }
    return deltas, result


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
