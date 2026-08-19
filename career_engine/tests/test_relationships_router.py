import pytest


@pytest.fixture
def created_career(api_client):
    return api_client.post(
        "/careers",
        json={"player_name": "Efe Kaan", "position": "Orta saha", "team_id": "t_ykz", "seed": 42},
    ).json()


def test_list_relationships_returns_five_cards(api_client, created_career):
    resp = api_client.get(f"/careers/{created_career['career_id']}/relationships")
    assert resp.status_code == 200
    rels = resp.json()["relationships"]
    assert {r["relationship_id"] for r in rels} == {"coach", "team", "media", "partner", "family"}
    assert all(r["score"] == 50 for r in rels)
    assert all(r["has_pending_request"] is False for r in rels)

    coach = next(r for r in rels if r["relationship_id"] == "coach")
    assert coach["category"] == "Antrenör"
    assert coach["person_name"] == "Mert Çalışkan"
    assert coach["traits"]["trust"] == 50.0  # CoachTraits default


def test_get_relationship_detail_includes_bio_and_hobbies(api_client, created_career):
    career_id = created_career["career_id"]
    resp = api_client.get(f"/careers/{career_id}/relationships/coach")
    assert resp.status_code == 200
    body = resp.json()

    assert body["age"] == 48
    assert body["occupation"] == "Baş antrenör"
    assert "Satranç" in body["hobbies"]
    assert body["recent_events"] == []


def test_get_relationship_detail_unknown_id_errors(api_client, created_career):
    resp = api_client.get(f"/careers/{created_career['career_id']}/relationships/stranger")
    assert resp.status_code == 422


def test_interact_applies_relationship_and_attribute_deltas(api_client, created_career):
    career_id = created_career["career_id"]
    resp = api_client.post(
        f"/careers/{career_id}/relationships/media/interact",
        json={"dialogue_id": "media_01", "choice_path": ["start", "r0"]},
    )
    assert resp.status_code == 200
    body = resp.json()

    assert body["relationship_changes"] == [
        {"relationship_id": "media", "before": 50, "after": 53, "delta": 3}
    ]
    assert body["attribute_changes"] == [
        {"key": "charisma", "before": 74.0, "after": 74.2}
    ]

    detail = api_client.get(f"/careers/{career_id}/relationships/media").json()
    assert detail["score"] == 53
    assert len(detail["recent_events"]) == 1
    assert detail["recent_events"][0]["reason"] == "dialogue:media_01:r0"


def test_interact_wrong_relationship_for_dialogue_errors(api_client, created_career):
    career_id = created_career["career_id"]
    resp = api_client.post(
        f"/careers/{career_id}/relationships/coach/interact",
        json={"dialogue_id": "media_01", "choice_path": ["start", "r0"]},
    )
    assert resp.status_code == 422


def test_interact_unknown_leaf_errors(api_client, created_career):
    career_id = created_career["career_id"]
    resp = api_client.post(
        f"/careers/{career_id}/relationships/coach/interact",
        json={"dialogue_id": "coach_01", "choice_path": ["start", "r99"]},
    )
    assert resp.status_code == 422


def test_interact_negative_delta_clamps_at_zero(api_client, created_career):
    career_id = created_career["career_id"]
    for _ in range(30):
        resp = api_client.post(
            f"/careers/{career_id}/relationships/media/interact",
            json={"dialogue_id": "media_01", "choice_path": ["start", "r1"]},  # -3 each
        )
    assert resp.status_code == 200
    assert resp.json()["relationship_changes"][0]["after"] == 0
