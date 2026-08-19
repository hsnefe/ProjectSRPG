import pytest


@pytest.fixture
def created_career(api_client):
    return api_client.post(
        "/careers",
        json={"player_name": "Efe Kaan", "position": "Orta saha", "team_id": "t_ykz", "seed": 42},
    ).json()


def test_get_competitions_marks_user_participation(api_client, created_career):
    resp = api_client.get(f"/careers/{created_career['career_id']}/competitions")
    assert resp.status_code == 200
    comps = {c["competition_id"]: c for c in resp.json()["competitions"]}

    assert set(comps.keys()) == {"c_lig1", "c_lig2", "c_kupa"}
    assert comps["c_lig2"]["user_participates"] is True
    assert comps["c_kupa"]["user_participates"] is True
    assert comps["c_lig1"]["user_participates"] is False
    assert comps["c_lig1"]["team_count"] == 18
    assert comps["c_lig2"]["team_count"] == 14


def test_get_standings_lists_all_teams_at_zero_before_any_match(api_client, created_career):
    resp = api_client.get(
        f"/careers/{created_career['career_id']}/standings", params={"competition": "c_lig2"}
    )
    assert resp.status_code == 200
    body = resp.json()

    assert body["competition"]["competition_id"] == "c_lig2"
    assert len(body["rows"]) == 14
    assert all(r["played"] == 0 for r in body["rows"])
    assert body["promotion_slots"] == 2
    assert body["relegation_slots"] == 0
    user_row = next(r for r in body["rows"] if r["is_user_team"])
    assert user_row["team"]["team_id"] == "t_ykz"


def test_get_standings_404s_for_cup(api_client, created_career):
    resp = api_client.get(
        f"/careers/{created_career['career_id']}/standings", params={"competition": "c_kupa"}
    )
    assert resp.status_code == 409
    assert resp.json()["code"] == "no_standings"


def test_get_fixtures_filters_by_competition_and_paginates(api_client, created_career):
    career_id = created_career["career_id"]
    resp = api_client.get(f"/careers/{career_id}/fixtures", params={"competition": "c_lig2", "limit": 5})
    assert resp.status_code == 200
    body = resp.json()

    assert len(body["fixtures"]) == 5
    assert all(f["competition"]["competition_id"] == "c_lig2" for f in body["fixtures"])
    assert body["next_before"] is not None
    assert len(body["rounds"]) == 26


def test_get_fixtures_cup_rounds_visible_before_drawn(api_client, created_career):
    career_id = created_career["career_id"]
    resp = api_client.get(f"/careers/{career_id}/fixtures", params={"competition": "c_kupa"})
    body = resp.json()

    assert len(body["rounds"]) == 5
    assert body["rounds"][0]["drawn"] is True   # round 1, drawn at onboarding
    assert body["rounds"][1]["drawn"] is False  # round 2+, undrawn (§3.3)


def test_get_fixtures_team_filter(api_client, created_career):
    career_id = created_career["career_id"]
    resp = api_client.get(f"/careers/{career_id}/fixtures", params={"team_id": "t_ykz", "limit": 100})
    body = resp.json()
    assert all(f["is_user_match"] for f in body["fixtures"])


def test_get_team_returns_ratings_and_standing(api_client, created_career):
    career_id = created_career["career_id"]
    resp = api_client.get(f"/careers/{career_id}/teams/t_ykz")
    assert resp.status_code == 200
    body = resp.json()

    assert body["team"]["team_id"] == "t_ykz"
    assert body["country"] == "TR"
    assert set(body["ratings"].keys()) == {"attack", "midfield", "defense", "goalkeeper"}
    assert body["competition"]["competition_id"] == "c_lig2"
    assert body["standing"]["played"] == 0


def test_get_team_unknown_id_errors(api_client, created_career):
    resp = api_client.get(f"/careers/{created_career['career_id']}/teams/t_doesnotexist")
    assert resp.status_code == 422
