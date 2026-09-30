"""One continuous session through every domain area, exercising the same
sequence a real FE integration would: pick a club, create a career, train,
shop, play a match, advance the world, read the results, then delete the
career and verify nothing is left behind (INV-9).

Router-level tests (test_*_router.py) cover each endpoint's edge cases in
isolation; this test's job is different — proving the pieces compose.
"""
import sqlite3

from api import config
from catalog.shop import SHOP_ITEMS

# Read from the catalog, not copied: a reprice (the ₺ -> ₭ move) should not
# break a test that is about money moving, not about what boots cost.
BOOTS_PRICE = next(i["price"] for i in SHOP_ITEMS if i["catalog_id"] == "personal-boots")
from tests.conftest import grant_money, set_attribute
from worlddata.relationships import STARTING_SCORES


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
    # 1. Read the creation form's options: a nationality, a position with its
    #    roles, and a dream club to aim at.
    options = api_client.get("/careers/options").json()
    assert options["nationalities"][0]["country_code"] == "TR"
    midfield = next(p for p in options["positions"] if p["position"] == "Orta saha")
    role_id = midfield["roles"][0]["role_id"]
    target = next(c for c in options["target_teams"] if c["team"]["team_id"] == "t_gal")

    # 2. Create the career. The club played for is assigned from nationality
    #    (§3), not chosen — only the target is.
    created = api_client.post(
        "/careers",
        json={
            "first_name": "Efe", "last_name": "Kaan", "nationality": "TR",
            "position": "Orta saha", "role": role_id,
            "target_team_id": target["team"]["team_id"], "seed": 7,
        },
    )
    assert created.status_code == 201
    career_id = created.json()["career_id"]
    assert created.json()["player"]["target_team"]["team_id"] == "t_gal"

    # 3. Sit the skill exams — grades in, attribute points out (§2).
    exams = api_client.post(
        f"/careers/{career_id}/skill-exams",
        json={"results": [
            {"exam_id": "shooting", "level": 5},
            {"exam_id": "passing", "level": 3},
            {"exam_id": "tackling", "level": 1},
        ]},
    )
    assert exams.status_code == 200
    by_exam = {r["exam_id"]: r for r in exams.json()["results"]}
    assert by_exam["shooting"]["applied"] == 5.0
    assert by_exam["tackling"]["applied"] == 1.0

    # An exam only pays out once.
    again = api_client.post(
        f"/careers/{career_id}/skill-exams",
        json={"results": [{"exam_id": "shooting", "level": 5}]},
    )
    assert again.status_code == 409
    assert again.json()["code"] == "skill_exam_already_taken"

    # 4. Hub shows the season opener as the next fixture.
    hub = api_client.get(f"/careers/{career_id}").json()
    assert hub["next_fixture"] is not None
    assert hub["standing_summary"]["competition_id"] == "c_lig2"

    # 5. Train — spends budget, raises an attribute.
    train = api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": "sut"})
    assert train.status_code == 200
    assert train.json()["attribute_changes"][0]["key"] == "shooting"

    # 6. Buy something — money moves, budget doesn't. A career starts at
    #    STARTING_MONEY (§4), which is far below shop prices, so fund it first.
    grant_money(career_id, 20000)
    buy = api_client.post(f"/careers/{career_id}/purchases", json={"catalog_id": "personal-boots"})
    assert buy.status_code == 200
    money_after_purchase = buy.json()["career_state"]["money"]
    assert money_after_purchase == config.STARTING_MONEY + 20000 - BOOTS_PRICE

    # 7. Chat with the coach. The conciliatory reply is gated on empathy
    #    6 (D42) and a fresh career sits at 58.0 — level 5 — so it bounces
    #    first, without touching the score.
    locked = api_client.post(
        f"/careers/{career_id}/relationships/coach/interact",
        json={"dialogue_id": "coach_01", "choice_path": ["start", "r0"]},
    )
    assert locked.status_code == 409
    assert locked.json()["code"] == "requirement_not_met"
    unchanged = api_client.get(f"/careers/{career_id}/relationships/coach").json()
    assert unchanged["score"] == STARTING_SCORES["coach"]
    assert unchanged["recent_events"] == []

    set_attribute(career_id, "empathy", 60.0)
    interact = api_client.post(
        f"/careers/{career_id}/relationships/coach/interact",
        json={"dialogue_id": "coach_01", "choice_path": ["start", "r0"]},
    )
    assert interact.status_code == 200
    assert interact.json()["relationship_changes"][0]["after"] == STARTING_SCORES["coach"] + 3

    # 8. Walk the preparation week to the opening match (§6.1 — a match is
    #    only playable on its own day, so the day loop is what gets us there).
    blocked = api_client.get(f"/careers/{career_id}/matches/next")
    assert blocked.status_code == 409
    assert blocked.json()["code"] == "not_match_day"

    advanced = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"}).json()
    assert advanced["stop_reason"] == "match"
    assert advanced["days_advanced"] == 7

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

    # 9. Standings now reflect the played match — the user's and, from the
    #    day loop's own background sim, every other team's round 1 too.
    standings = api_client.get(f"/careers/{career_id}/standings", params={"competition": "c_lig2"}).json()
    user_row = next(r for r in standings["rows"] if r["is_user_team"])
    assert user_row["played"] == 1
    assert all(r["played"] == 1 for r in standings["rows"])  # INV-12

    # 10. Player stats picked it up too.
    stats = api_client.get(f"/careers/{career_id}/player/stats").json()
    assert stats["rows"][0]["goals"] == 1
    assert stats["rows"][0]["competition_kind"] == "lig"

    # 11. Advance the world again — the next match is a week out.
    advance = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"})
    assert advance.status_code == 200
    assert advance.json()["days_advanced"] >= 1

    news = api_client.get(f"/careers/{career_id}/news").json()
    assert len(news["items"]) >= 1  # at least the match report from step 7

    # 12. Delete the career — verify INV-9 exhaustively, not just spot-checked.
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
