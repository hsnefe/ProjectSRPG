"""§11.5 S1 - turning one season into the next.

Until this module a career had a hard stop: `advance` refused to move past
the season boundary and there was nothing to do about it. §11 closed that
gap by making the end of a season a thing the player acts on rather than a
wall, and this is the action.

D46 put it behind its own endpoint rather than inside `advance`, so FE gets
a season-end screen: the user sees the final table, then starts the rollover
themselves. D47 keeps it to one call that does NOT move `game_date` - the
summer is played normally, day by day, with training and money and
relationships all still running.

Everything here happens in one transaction (INV-36). A half-applied rollover
- entries moved but no fixtures generated - would leave a career that cannot
advance and cannot roll over again.
"""
import random
import sqlite3
from typing import List

from api import config, errors, serializers
from domain import daytime, season as season_mod
from worlddata.competitions import COMPETITION_RULES, CUP_TEAM_IDS, continental_slots


def _leagues(conn: sqlite3.Connection, career_id: str) -> List[sqlite3.Row]:
    return conn.execute(
        "SELECT * FROM competition WHERE career_id = ? AND kind = 'league' "
        "ORDER BY tier",
        (career_id,),
    ).fetchall()


def _rule(competition_id: str) -> dict:
    return COMPETITION_RULES.get(competition_id, {
        "promote_count": 0, "relegate_count": 0,
        "promotes_to_competition_id": None, "relegates_to_competition_id": None,
    })


def _write_season_results(
    conn: sqlite3.Connection, career_id: str, season_id: str, league: sqlite3.Row
) -> List[dict]:
    """The final table, frozen. INV-2 says the standings can always be
    re-derived from `fixture`, and they can - but the *outcomes* cannot: the
    quota size and the promotion count may change between versions, and a
    past season's verdict must not change with them.

    Four flags rather than one 'outcome' enum because the top team is
    champion AND a continental entrant at the same time; one column cannot
    hold both.
    """
    table = serializers.fetch_full_standings(conn, career_id, season_id, league["competition_id"])
    rule = _rule(league["competition_id"])
    slots = continental_slots(league["international_score"])
    relegate_count = rule["relegate_count"]
    promote_count = rule["promote_count"]

    written = []
    for row in table:
        rank = row["rank"]
        is_champion = rank == 1
        continental = rank <= slots
        promoted = promote_count > 0 and rank <= promote_count
        relegated = relegate_count > 0 and rank > len(table) - relegate_count

        conn.execute(
            "INSERT INTO season_result (career_id, season_id, competition_id, team_id, "
            "final_rank, is_champion, continental, promoted, relegated) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (career_id, season_id, league["competition_id"], row["team_id"], rank,
             int(is_champion), int(continental), int(promoted), int(relegated)),
        )
        written.append({
            "team_id": row["team_id"], "final_rank": rank,
            "is_champion": is_champion, "continental": continental,
            "promoted": promoted, "relegated": relegated,
        })
    return written


def _next_season_league_teams(
    conn: sqlite3.Connection, career_id: str, season_id: str
) -> dict:
    """Who plays where next season, after promotion and relegation.

    Built by moving teams between the league lists rather than by rebuilding
    from worlddata, because worlddata only knows where everyone started.
    Promotions equal relegations by construction (§11.4), so each league
    keeps its size (INV-34) and every team lands in exactly one of them
    (INV-37).
    """
    current = season_mod.league_teams_for(conn, career_id, season_id)
    moving_up, moving_down = {}, {}

    for competition_id in current:
        rule = _rule(competition_id)
        results = conn.execute(
            "SELECT team_id, promoted, relegated FROM season_result "
            "WHERE career_id = ? AND season_id = ? AND competition_id = ?",
            (career_id, season_id, competition_id),
        ).fetchall()
        for row in results:
            if row["promoted"] and rule["promotes_to_competition_id"]:
                moving_up.setdefault(rule["promotes_to_competition_id"], []).append(row["team_id"])
            elif row["relegated"] and rule["relegates_to_competition_id"]:
                moving_down.setdefault(rule["relegates_to_competition_id"], []).append(row["team_id"])

    moved = {tid for ids in moving_up.values() for tid in ids}
    moved |= {tid for ids in moving_down.values() for tid in ids}

    out = {}
    for competition_id, team_ids in current.items():
        stayed = [t for t in team_ids if t not in moved]
        arrived = moving_up.get(competition_id, []) + moving_down.get(competition_id, [])
        out[competition_id] = sorted(stayed + arrived)
    return out


def _user_outcomes(
    conn: sqlite3.Connection, career_id: str, season_id: str, user_team_id: str
) -> dict:
    row = conn.execute(
        "SELECT * FROM season_result WHERE career_id = ? AND season_id = ? AND team_id = ?",
        (career_id, season_id, user_team_id),
    ).fetchone()
    if row is None:
        return {"final_rank": None, "outcomes": [], "moved_with_team": False}

    outcomes = []
    if row["is_champion"]:
        outcomes.append("champion")
    if row["continental"]:
        outcomes.append("continental")
    if row["promoted"]:
        outcomes.append("promoted")
    if row["relegated"]:
        outcomes.append("relegated")
    return {
        "final_rank": row["final_rank"],
        "outcomes": outcomes,
        "moved_with_team": bool(row["promoted"] or row["relegated"]),
    }


def _fixture_news(
    conn: sqlite3.Connection, career_id: str, new_season_id: str,
    user_team_id: str, on_date: str,
) -> str:
    """The new fixture list, announced through the news layer rather than
    left for the player to discover in the calendar. Only the user's own
    opening run is named - a bulletin listing 306 fixtures is not news."""
    rows = conn.execute(
        "SELECT f.kickoff_at, f.home_team_id, f.away_team_id, c.name AS competition "
        "FROM fixture f JOIN competition c ON c.career_id = f.career_id "
        "AND c.competition_id = f.competition_id "
        "WHERE f.career_id = ? AND f.season_id = ? "
        "AND (f.home_team_id = ? OR f.away_team_id = ?) "
        "ORDER BY f.kickoff_at ASC LIMIT 5",
        (career_id, new_season_id, user_team_id, user_team_id),
    ).fetchall()

    lines = []
    for row in rows:
        home = serializers.fetch_team_ref(conn, career_id, row["home_team_id"])
        away = serializers.fetch_team_ref(conn, career_id, row["away_team_id"])
        at_home = row["home_team_id"] == user_team_id
        opponent = (away if at_home else home)["name"]
        where = "evinde" if at_home else "deplasmanda"
        lines.append(
            f"{row['kickoff_at'][:10]} · {row['competition']} · {where} {opponent}"
        )

    return daytime._create_news(
        conn, career_id, "Analiz",
        f"{new_season_id} fikstürü çekildi",
        "Yeni sezonun programı belli oldu. İlk maçların:\n" + "\n".join(lines),
        on_date,
    )


def _result_news(
    conn: sqlite3.Connection, career_id: str, season_id: str,
    league: sqlite3.Row, results: List[dict], on_date: str,
) -> List[str]:
    news_ids = []
    champion = next((r for r in results if r["is_champion"]), None)
    if champion:
        team = serializers.fetch_team_ref(conn, career_id, champion["team_id"])
        news_ids.append(daytime._create_news(
            conn, career_id, "Analiz",
            f"{team['name']} {league['name']} şampiyonu",
            f"{season_id} sezonu {team['name']}'in şampiyonluğuyla kapandı.",
            on_date,
        ))

    promoted = [r for r in results if r["promoted"]]
    relegated = [r for r in results if r["relegated"]]
    if promoted or relegated:
        def names(rows):
            return ", ".join(
                serializers.fetch_team_ref(conn, career_id, r["team_id"])["name"]
                for r in rows
            ) or "-"
        news_ids.append(daytime._create_news(
            conn, career_id, "Analiz",
            f"{league['name']} kümede kalma ve terfi tablosu",
            f"Çıkanlar: {names(promoted)}\nDüşenler: {names(relegated)}",
            on_date,
        ))
    return news_ids


def summary(conn: sqlite3.Connection, career_id: str, season_id: str) -> dict:
    """§11.6 SeasonSummary. Reads `season_result`, not the live table: this
    is what was decided, and it must keep saying so after the rules change.

    The cup does not appear - a knockout has no table, the same reason W2
    answers `no_standings` for it.
    """
    leagues = []
    slots = {}
    for league in _leagues(conn, career_id):
        rows = conn.execute(
            "SELECT * FROM season_result WHERE career_id = ? AND season_id = ? "
            "AND competition_id = ? ORDER BY final_rank",
            (career_id, season_id, league["competition_id"]),
        ).fetchall()
        if not rows:
            continue

        table = {
            r["team_id"]: r for r in
            serializers.fetch_full_standings(conn, career_id, season_id, league["competition_id"])
        }
        champion = next((r for r in rows if r["is_champion"]), None)
        slots[league["competition_id"]] = continental_slots(league["international_score"])

        entries = []
        for row in rows:
            stat = table.get(row["team_id"], {})
            outcomes = []
            if row["is_champion"]:
                outcomes.append("champion")
            if row["continental"]:
                outcomes.append("continental")
            if row["promoted"]:
                outcomes.append("promoted")
            if row["relegated"]:
                outcomes.append("relegated")
            entries.append({
                "team": serializers.fetch_team_ref(conn, career_id, row["team_id"]),
                "final_rank": row["final_rank"],
                "outcomes": outcomes,
                "played": stat.get("played", 0),
                "won": stat.get("won", 0),
                "drawn": stat.get("drawn", 0),
                "lost": stat.get("lost", 0),
                "goals_for": stat.get("goals_for", 0),
                "goals_against": stat.get("goals_against", 0),
                "goal_difference": stat.get("goal_difference", 0),
                "points": stat.get("points", 0),
            })

        leagues.append({
            "competition": serializers.competition_ref(league),
            "champion": (
                serializers.fetch_team_ref(conn, career_id, champion["team_id"])
                if champion else None
            ),
            "rows": entries,
        })

    return {"season_id": season_id, "leagues": leagues, "continental_slots": slots}


def run(conn: sqlite3.Connection, career_id: str) -> dict:
    """§11.5's five steps, in one transaction. Does not commit; the handler
    owns that (INV-3/INV-36)."""
    game_date = conn.execute(
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"]

    finished = conn.execute(
        "SELECT * FROM season WHERE career_id = ? ORDER BY starts_on DESC LIMIT 1",
        (career_id,),
    ).fetchone()
    previous_season_id = finished["season_id"]

    seed = conn.execute(
        "SELECT seed FROM career WHERE career_id = ?", (career_id,)
    ).fetchone()["seed"]
    user_team_id = serializers.fetch_user_team_id(conn, career_id)

    news_created = []

    # 1 + 5. Final standings frozen per league, with their news.
    for league in _leagues(conn, career_id):
        results = _write_season_results(conn, career_id, previous_season_id, league)
        news_created.extend(
            _result_news(conn, career_id, previous_season_id, league, results, game_date)
        )

    user = _user_outcomes(conn, career_id, previous_season_id, user_team_id)

    # 2 + 4. Promotion and relegation decide next season's divisions, then
    # the shared builder writes the whole season from them.
    calendar = season_mod.calendar_after(finished)
    league_teams = _next_season_league_teams(conn, career_id, previous_season_id)
    season_mod.create_season(
        conn, career_id, calendar,
        league_teams=league_teams,
        # The career's own seed, so INV-7 holds across seasons: the same seed
        # and the same decisions produce the same world in year five as in
        # year one. Mixed with the season id so season two is not a copy of
        # season one's fixture order.
        rng=random.Random(f"{seed}:season:{calendar.season_id}"),
        cup_team_ids=CUP_TEAM_IDS,
    )

    news_created.append(
        _fixture_news(conn, career_id, calendar.season_id, user_team_id, game_date)
    )

    # The career's own season_id follows the world. game_date does NOT move
    # (D47) - the summer is played day by day like any other stretch.
    conn.execute(
        "UPDATE career_state SET season_id = ? WHERE career_id = ?",
        (calendar.season_id, career_id),
    )

    new_league_id = serializers.fetch_user_league_competition_id(
        conn, career_id, calendar.season_id
    )
    return {
        "previous_season_id": previous_season_id,
        "new_season_id": calendar.season_id,
        "summary": summary(conn, career_id, previous_season_id),
        "user": {
            "team": serializers.fetch_team_ref(conn, career_id, user_team_id),
            "competition": (
                serializers.fetch_competition_ref(conn, career_id, new_league_id)
                if new_league_id else None
            ),
            **user,
            # §11.7's contract check lands here in the next commit; until
            # then a contract simply carries on.
            "contract_status": "active",
        },
        "offers": [],
        "news_created": news_created,
    }
