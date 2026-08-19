"""One continuous session through every domain area, exercising the same
sequence a real FE integration would: pick a club, create a career, train,
shop, play a match, advance the world, read the results, then delete the
career and verify nothing is left behind (INV-9).

Router-level tests (test_*_router.py) cover each endpoint's edge cases in
isolation; this test's job is different — proving the pieces compose.
"""
import sqlite3

from api import config


def _all_career_scoped_tables(conn: sqlite3.Connection) -> list:
    # NOT GLOB, not NOT LIKE: LIKE's '_' is a single-character wildcard (it
    # would match everything, excluding every table), GLOB's '_' is literal
    # and only '*'/'?' are wildcards — the actual match we want here is
    # "starts with a real underscore", i.e. _schema_migrations only.
    rows = conn.execute(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT GLOB '_*'"
    ).fetchall()
    tables = []
    for r in rows:
        cols = [c["name"] for c in conn.execute(f"PRAGMA table_info({r['name']})").fetchall()]
        if "career_id" in cols:
            tables.append(r["name"])
    return tables


def _stats(goals=0):
    return {
        "goals": goals, "shots": 12, "shots_on_target": 5, "corners": 6,
        "dangerous_attacks": 10, "total_attacks": 22, "yellow_cards": 2,
        "red_cards": 0, "penalties": 0, "penalty_goals": 0, "fouls": 8,
        "substitutions": 3, "possession_ticks": 55,
    }


def test_full_career_session(api_client, mock_engine):
    # 1. Pick a club.
    options = api_client.get("/careers/options").json()
    club = next(c for c in options["clubs"] if c["team"]["team_id"] == "t_ykz")
    assert club["competition"]["competition_id"] == "c_lig2"

    # 2. Create the career.
    created = api_client.post(
        "/careers",
        json={"player_name": "Efe Kaan", "position": "Orta saha", "team_id": "t_ykz", "seed": 7},
    )
    assert created.status_code == 201
    career_id = created.json()["career_id"]

    # 3. Hub shows the season opener as the next fixture.
    hub = api_client.get(f"/careers/{career_id}").json()
    assert hub["next_fixture"] is not None
    assert hub["standing_summary"]["competition_id"] == "c_lig2"

    # 4. Train — spends budget, raises an attribute.
    train = api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": "sut"})
    assert train.status_code == 200
    assert train.json()["attribute_changes"][0]["key"] == "shooting"

    # 5. Buy something — money moves, budget doesn't.
    buy = api_client.post(f"/careers/{career_id}/purchases", json={"catalog_id": "personal-boots"})
    assert buy.status_code == 200
    money_after_purchase = buy.json()["career_state"]["money"]
    assert money_after_purchase == config.STARTING_MONEY - 8900

    # 6. Chat with the coach.
    interact = api_client.post(
        f"/careers/{career_id}/relationships/coach/interact",
        json={"dialogue_id": "coach_01", "choice_path": ["start", "r0"]},
    )
    assert interact.status_code == 200
    assert interact.json()["relationship_changes"][0]["after"] == 53

    # 7. Play the opening match.
    next_match = api_client.get(f"/careers/{career_id}/matches/next").json()
    fixture_id = next_match["fixture_id"]
    assert next_match["engine_payload"]["user_condition"] == config.STARTING_CONDITION

    result = api_client.post(
        f"/careers/{career_id}/matches/{fixture_id}/result",
        json={
            "match_id": "m_e2e_test",
            "score": {"home": 2, "away": 1} if next_match["user_side"] == "home" else {"home": 1, "away": 2},
            "stats": {
                "home": _stats(2 if next_match["user_side"] == "home" else 1),
                "away": _stats(1 if next_match["user_side"] == "home" else 2),
            },
            "final_possession_home": 54.0,
            "final_condition": 58,
            "interventions": [
                {"minute": 40, "action_key": "finish_power", "outcome_key": "great"},
                {"minute": 70, "action_key": "long_shot", "outcome_key": "bad"},
            ],
        },
    )
    assert result.status_code == 200
    assert result.json()["player_stat_delta"]["goals"] == 1
    assert len(result.json()["other_results"]) > 0

    # 8. Standings now reflect the played match.
    standings = api_client.get(f"/careers/{career_id}/standings", params={"competition": "c_lig2"}).json()
    user_row = next(r for r in standings["rows"] if r["is_user_team"])
    assert user_row["played"] == 1

    # 9. Player stats picked it up too.
    stats = api_client.get(f"/careers/{career_id}/player/stats").json()
    assert stats["rows"][0]["goals"] == 1
    assert stats["rows"][0]["competition_kind"] == "lig"

    # 10. Advance the world — days pass, other fixtures resolve, news appears.
    advance = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"})
    assert advance.status_code == 200
    assert advance.json()["days_advanced"] >= 1

    news = api_client.get(f"/careers/{career_id}/news").json()
    assert len(news["items"]) >= 1  # at least the match report from step 7

    # 11. Delete the career — verify INV-9 exhaustively, not just spot-checked.
    conn = sqlite3.connect(config.DB_PATH)
    conn.row_factory = sqlite3.Row
    tables = _all_career_scoped_tables(conn)
    assert len(tables) >= 20  # sanity: we actually found the real table list

    before_counts = {
        t: conn.execute(f"SELECT COUNT(*) c FROM {t} WHERE career_id = ?", (career_id,)).fetchone()["c"]
        for t in tables
    }
    assert sum(before_counts.values()) > 0
    conn.close()

    delete_resp = api_client.delete(f"/careers/{career_id}")
    assert delete_resp.status_code == 204

    conn = sqlite3.connect(config.DB_PATH)
    conn.row_factory = sqlite3.Row
    after_counts = {
        t: conn.execute(f"SELECT COUNT(*) c FROM {t} WHERE career_id = ?", (career_id,)).fetchone()["c"]
        for t in tables
    }
    conn.close()

    leftover = {t: n for t, n in after_counts.items() if n > 0}
    assert leftover == {}, f"INV-9 violated — rows survived career deletion: {leftover}"

    assert api_client.get(f"/careers/{career_id}").status_code == 404
