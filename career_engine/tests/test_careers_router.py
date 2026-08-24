from api import config
from catalog.skill_exams import MAX_LEVEL
from tests.conftest import CAREER_PAYLOAD, create_career
from worlddata.positions import POSITIONS, ROLES
from worlddata.teams import ALL_TEAMS, TIER2_TEAMS


def test_get_options_lists_nationalities_positions_and_roles(api_client):
    resp = api_client.get("/careers/options")
    assert resp.status_code == 200
    body = resp.json()

    assert [n["country_code"] for n in body["nationalities"]] == ["TR"]

    # Kaleci is out in v1 — a position with no role can't produce a career.
    assert [p["position"] for p in body["positions"]] == list(POSITIONS)
    assert "Kaleci" not in [p["position"] for p in body["positions"]]

    listed_roles = [r["role_id"] for p in body["positions"] for r in p["roles"]]
    assert sorted(listed_roles) == sorted(r["role_id"] for r in ROLES)
    assert all(
        len(r["attributes"]) == 2
        for p in body["positions"] for r in p["roles"]
    )

    # Any club may be a dream club, not just the bottom tier.
    assert len(body["target_teams"]) == len(ALL_TEAMS)
    assert all(c["strength_hint"] in ("zayıf", "orta", "güçlü") for c in body["target_teams"])


def test_get_options_exposes_exam_and_starting_value_tables(api_client):
    body = api_client.get("/careers/options").json()

    assert [e["exam_id"] for e in body["skill_exams"]] == ["shooting", "passing", "tackling"]
    assert all(e["max_level"] == MAX_LEVEL for e in body["skill_exams"])

    starting = body["starting_values"]
    assert starting["money"] == config.STARTING_MONEY
    assert starting["condition"] == config.STARTING_CONDITION
    assert starting["relationships"] == {
        "coach": 70, "team": 50, "media": 10, "fans": 40, "partner": 0, "family": 0,
    }


def test_create_career_returns_201_and_hub_shape(api_client):
    body = create_career(api_client)

    assert body["career_id"].startswith("car_")
    assert body["career_state"]["money"] == config.STARTING_MONEY
    assert body["career_state"]["condition"] == config.STARTING_CONDITION
    assert body["player"]["name"] == "Efe Kaan"
    assert body["player"]["first_name"] == "Efe"
    assert body["player"]["last_name"] == "Kaan"
    assert body["player"]["nationality"] == "TR"
    assert body["player"]["role"] == "merkez_orta_saha"
    assert body["player"]["role_name"] == "Merkez Orta Saha"
    assert body["next_fixture"] is not None
    assert body["standing_summary"]["competition_id"] == "c_lig2"
    assert body["standing_summary"]["played"] == 0
    assert body["news_preview"] == []


def test_create_career_assigns_a_bottom_tier_club_and_keeps_the_target(api_client):
    """§3 - the club you play for is assigned from your nationality's bottom
    league; the club you named is only the one you're aiming at."""
    body = create_career(api_client, target_team_id="t_gal")

    tier2_ids = {t["team_id"] for t in TIER2_TEAMS}
    assert body["player"]["team"]["team_id"] in tier2_ids
    assert body["player"]["target_team"]["team_id"] == "t_gal"
    assert body["player"]["team"]["team_id"] != "t_gal"


def test_create_career_rejects_role_from_another_position(api_client):
    resp = api_client.post(
        "/careers",
        json={**CAREER_PAYLOAD, "position": "Defans", "role": "firsatci_forvet"},
    )
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_request"
    assert "firsatci_forvet" in resp.json()["message"]


def test_create_career_rejects_unknown_role(api_client):
    resp = api_client.post("/careers", json={**CAREER_PAYLOAD, "role": "sweeper_keeper"})
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_request"


def test_create_career_rejects_goalkeeper_position(api_client):
    """Kaleci is disabled for v1 — it has no roles, so it isn't a position."""
    resp = api_client.post(
        "/careers",
        json={**CAREER_PAYLOAD, "position": "Kaleci", "role": "merkez_orta_saha"},
    )
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_request"


def test_create_career_rejects_unknown_nationality(api_client):
    resp = api_client.post("/careers", json={**CAREER_PAYLOAD, "nationality": "DE"})
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_request"


def test_create_career_rejects_unknown_target_team(api_client):
    resp = api_client.post("/careers", json={**CAREER_PAYLOAD, "target_team_id": "t_nope"})
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_request"


def test_create_career_rejects_blank_name(api_client):
    resp = api_client.post("/careers", json={**CAREER_PAYLOAD, "first_name": "   "})
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_request"


def test_get_career_matches_create_response(api_client):
    created = create_career(api_client, position="Forvet", role="hedef_adam", seed=5)

    fetched = api_client.get(f"/careers/{created['career_id']}").json()
    assert fetched == created


def test_get_career_404_for_unknown_id(api_client):
    resp = api_client.get("/careers/car_doesnotexist")
    assert resp.status_code == 404
    assert resp.json()["code"] == "career_not_found"


def test_list_careers_includes_created_career(api_client):
    created = create_career(api_client)

    listed = api_client.get("/careers").json()["careers"]
    ids = [c["career_id"] for c in listed]
    assert created["career_id"] in ids

    row = next(c for c in listed if c["career_id"] == created["career_id"])
    assert isinstance(row["player_age"], int)
    assert row["player_age"] == created["player"]["age"]


def test_delete_career_removes_it(api_client):
    career_id = create_career(api_client)["career_id"]

    resp = api_client.delete(f"/careers/{career_id}")
    assert resp.status_code == 204

    resp = api_client.get(f"/careers/{career_id}")
    assert resp.status_code == 404


def test_delete_unknown_career_404s(api_client):
    resp = api_client.delete("/careers/car_doesnotexist")
    assert resp.status_code == 404
