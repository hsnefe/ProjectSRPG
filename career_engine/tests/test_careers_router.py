def test_get_options_returns_tier2_clubs_only(api_client):
    resp = api_client.get("/careers/options")
    assert resp.status_code == 200
    body = resp.json()
    assert set(body["positions"]) == {"Kaleci", "Defans", "Orta saha", "Forvet"}
    assert len(body["clubs"]) == 14
    assert all(c["competition"]["competition_id"] == "c_lig2" for c in body["clubs"])
    assert all(c["strength_hint"] in ("zayıf", "orta", "güçlü") for c in body["clubs"])


def test_create_career_returns_201_and_hub_shape(api_client):
    resp = api_client.post(
        "/careers",
        json={"player_name": "Efe Kaan", "position": "Orta saha", "team_id": "t_ykz", "seed": 42},
    )
    assert resp.status_code == 201
    body = resp.json()

    assert body["career_id"].startswith("car_")
    assert body["career_state"]["money"] == 48200
    assert body["career_state"]["condition"] == 72
    assert body["player"]["name"] == "Efe Kaan"
    assert body["player"]["team"]["team_id"] == "t_ykz"
    assert body["next_fixture"] is not None
    assert body["next_fixture"]["competition"]["competition_id"] in ("c_lig2", "c_kupa")
    assert body["standing_summary"]["competition_id"] == "c_lig2"
    assert body["standing_summary"]["played"] == 0
    assert body["news_preview"] == []


def test_create_career_rejects_tier1_club(api_client):
    resp = api_client.post(
        "/careers",
        json={"player_name": "X", "position": "Orta saha", "team_id": "t_bkt"},
    )
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_request"


def test_get_career_matches_create_response(api_client):
    created = api_client.post(
        "/careers",
        json={"player_name": "Efe Kaan", "position": "Forvet", "team_id": "t_dnz", "seed": 5},
    ).json()

    fetched = api_client.get(f"/careers/{created['career_id']}").json()
    assert fetched == created


def test_get_career_404_for_unknown_id(api_client):
    resp = api_client.get("/careers/car_doesnotexist")
    assert resp.status_code == 404
    assert resp.json()["code"] == "career_not_found"


def test_list_careers_includes_created_career(api_client):
    created = api_client.post(
        "/careers",
        json={"player_name": "Efe Kaan", "position": "Orta saha", "team_id": "t_krt"},
    ).json()

    listed = api_client.get("/careers").json()["careers"]
    ids = [c["career_id"] for c in listed]
    assert created["career_id"] in ids


def test_delete_career_removes_it(api_client):
    created = api_client.post(
        "/careers",
        json={"player_name": "Efe Kaan", "position": "Orta saha", "team_id": "t_yes"},
    ).json()
    career_id = created["career_id"]

    resp = api_client.delete(f"/careers/{career_id}")
    assert resp.status_code == 204

    resp = api_client.get(f"/careers/{career_id}")
    assert resp.status_code == 404


def test_delete_unknown_career_404s(api_client):
    resp = api_client.delete("/careers/car_doesnotexist")
    assert resp.status_code == 404
