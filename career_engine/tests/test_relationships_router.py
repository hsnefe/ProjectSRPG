import pytest

from tests.conftest import create_career, set_attribute
from worlddata.relationships import STARTING_SCORES


@pytest.fixture
def created_career(api_client):
    return create_career(api_client)


def test_list_relationships_returns_a_card_per_kind_at_its_starting_score(api_client, created_career):
    resp = api_client.get(f"/careers/{created_career['career_id']}/relationships")
    assert resp.status_code == 200
    rels = resp.json()["relationships"]
    assert {r["relationship_id"] for r in rels} == set(STARTING_SCORES)
    # §4 - each kind starts at its own score, not a flat 50.
    assert {r["relationship_id"]: r["score"] for r in rels} == STARTING_SCORES
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
    # media_01:r0 is the only leaf with attribute_effects, and D42 gates it
    # at charisma 8. This test is about the deltas; the gate itself is
    # covered separately below.
    set_attribute(career_id, "charisma", 80.0)
    resp = api_client.post(
        f"/careers/{career_id}/relationships/media/interact",
        json={"dialogue_id": "media_01", "choice_path": ["start", "r0"]},
    )
    assert resp.status_code == 200
    body = resp.json()

    media_start = STARTING_SCORES["media"]
    assert body["relationship_changes"] == [
        {
            "relationship_id": "media", "before": media_start,
            "after": media_start + 3, "delta": 3,
        }
    ]
    assert body["attribute_changes"] == [
        {"key": "charisma", "before": 80.0, "after": 80.2}
    ]

    detail = api_client.get(f"/careers/{career_id}/relationships/media").json()
    assert detail["score"] == media_start + 3
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


# --- D42: the dialogue gate ----------------------------------------------

def test_interact_locked_leaf_is_refused_and_writes_nothing(api_client, created_career):
    """INV-30 — a refused choice must leave no trace at all: not the score,
    not the event log, not the attribute the leaf would have moved."""
    career_id = created_career["career_id"]
    before = api_client.get(f"/careers/{career_id}/relationships/media").json()
    charisma_before = next(
        a for a in api_client.get(f"/careers/{career_id}/player").json()["attributes"]
        if a["key"] == "charisma"
    )
    assert charisma_before["level"] == 7  # media_01:r0 wants 8

    resp = api_client.post(
        f"/careers/{career_id}/relationships/media/interact",
        json={"dialogue_id": "media_01", "choice_path": ["start", "r0"]},
    )
    assert resp.status_code == 409
    assert resp.json()["code"] == "requirement_not_met"

    after = api_client.get(f"/careers/{career_id}/relationships/media").json()
    assert after["score"] == before["score"]
    assert after["recent_events"] == []
    assert after["last_contact_at"] == before["last_contact_at"]
    charisma_after = next(
        a for a in api_client.get(f"/careers/{career_id}/player").json()["attributes"]
        if a["key"] == "charisma"
    )
    assert charisma_after["value"] == charisma_before["value"]


def test_interact_locked_leaf_opens_once_the_level_is_reached(api_client, created_career):
    career_id = created_career["career_id"]
    payload = {"dialogue_id": "media_01", "choice_path": ["start", "r0"]}
    assert api_client.post(f"/careers/{career_id}/relationships/media/interact",
                           json=payload).status_code == 409

    set_attribute(career_id, "charisma", 79.9)   # still level 7
    assert api_client.post(f"/careers/{career_id}/relationships/media/interact",
                           json=payload).status_code == 409

    set_attribute(career_id, "charisma", 80.0)   # exactly level 8
    assert api_client.post(f"/careers/{career_id}/relationships/media/interact",
                           json=payload).status_code == 200


def test_interact_ungated_leaf_of_a_gated_tree_always_works(api_client, created_career):
    """INV-32's point, from the caller's side: a fresh career can always
    hold up its end of every conversation."""
    career_id = created_career["career_id"]
    resp = api_client.post(
        f"/careers/{career_id}/relationships/media/interact",
        json={"dialogue_id": "media_01", "choice_path": ["start", "r1"]},
    )
    assert resp.status_code == 200


def test_interact_unknown_leaf_is_still_422_not_409(api_client, created_career):
    """The gate must not swallow the shape check: a leaf that doesn't exist
    is a malformed request (422), not an unmet requirement (409)."""
    career_id = created_career["career_id"]
    resp = api_client.post(
        f"/careers/{career_id}/relationships/media/interact",
        json={"dialogue_id": "media_01", "choice_path": ["start", "r404"]},
    )
    assert resp.status_code == 422
