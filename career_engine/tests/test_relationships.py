import pytest

from api.errors import ApiError
from domain import relationships


def test_apply_delta_updates_score_and_logs_event(db_conn, career_id, seeded_relationship):
    result = relationships.apply_delta(
        db_conn, career_id, seeded_relationship, 3, "dialogue:coach_01:choice_2", "2026-03-12T18:00:00+03:00"
    )
    db_conn.commit()

    assert result == {"relationship_id": "coach", "before": 50, "after": 53, "delta": 3}
    assert relationships.get_score(db_conn, career_id, seeded_relationship) == 53


def test_apply_delta_clamps_at_bounds(db_conn, career_id, seeded_relationship):
    relationships.apply_delta(db_conn, career_id, seeded_relationship, 1000, "test:overflow", "2026-03-12")
    db_conn.commit()
    assert relationships.get_score(db_conn, career_id, seeded_relationship) == 100

    relationships.apply_delta(db_conn, career_id, seeded_relationship, -1000, "test:underflow", "2026-03-13")
    db_conn.commit()
    assert relationships.get_score(db_conn, career_id, seeded_relationship) == 0


def test_decay_does_not_touch_last_contact_at(db_conn, career_id, seeded_relationship):
    relationships.apply_delta(
        db_conn, career_id, seeded_relationship, 5, "dialogue:x", "2026-03-01", touches_contact=True
    )
    relationships.apply_delta(
        db_conn, career_id, seeded_relationship, -2, "decay", "2026-03-10", touches_contact=False
    )
    db_conn.commit()

    row = db_conn.execute(
        "SELECT last_contact_at FROM relationship WHERE career_id = ? AND relationship_id = ?",
        (career_id, seeded_relationship),
    ).fetchone()
    assert row["last_contact_at"] == "2026-03-01"


def test_replay_matches_stored_score_inv15(db_conn, career_id, seeded_relationship):
    relationships.apply_delta(db_conn, career_id, seeded_relationship, 3, "a", "2026-01-01")
    relationships.apply_delta(db_conn, career_id, seeded_relationship, -10, "b", "2026-01-02")
    relationships.apply_delta(db_conn, career_id, seeded_relationship, 7, "c", "2026-01-03")
    db_conn.commit()

    stored = relationships.get_score(db_conn, career_id, seeded_relationship)
    replayed = relationships.replay_score(db_conn, career_id, seeded_relationship, base_score=50)
    assert stored == replayed


@pytest.mark.parametrize(
    "kind,traits",
    [
        ("coach", {"trust": 74, "promised_minutes": 60, "tactical_fit": 0.8}),
        ("media", {"outlet": "Spor Manşet", "tone": "olumlu", "interviews_given": 7}),
        ("partner", {"together_since": "2025-11-02", "gift_count": 3, "mood": "özlemiş"}),
        ("team", {"anything_goes": True}),
        ("family", {"whatever": 1}),
    ],
)
def test_validate_traits_accepts_documented_shapes(kind, traits):
    validated = relationships.validate_traits(kind, traits)
    assert validated["hobbies"] == []


def test_validate_traits_rejects_wrong_type():
    with pytest.raises(ApiError) as exc_info:
        relationships.validate_traits("coach", {"trust": "not-a-number"})
    assert exc_info.value.code == "invalid_request"


def test_validate_traits_rejects_unknown_kind():
    with pytest.raises(ApiError) as exc_info:
        relationships.validate_traits("stranger", {})
    assert exc_info.value.code == "invalid_request"
