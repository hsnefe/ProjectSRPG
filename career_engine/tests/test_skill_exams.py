"""§2 - the Şut/Pas/Müdahale exams, at both the domain and the router level."""
import pytest

from api.errors import ApiError
from catalog.skill_exams import MAX_LEVEL, MIN_LEVEL, SKILL_EXAMS, get_exam
from domain import attributes, skill_exams
from tests.conftest import create_career
from worlddata.attributes import BASE_SKILL_VALUE, ROLE_BONUS_PER_SLOT


@pytest.fixture
def created_career(api_client):
    return create_career(api_client)


def _submit(api_client, career_id, results):
    return api_client.post(f"/careers/{career_id}/skill-exams", json={"results": results})


def _attr(api_client, career_id, key):
    body = api_client.get(f"/careers/{career_id}/player").json()
    return next(a for a in body["attributes"] if a["key"] == key)["value"]


# --- catalog ---------------------------------------------------------------

def test_every_exam_targets_a_distinct_attribute():
    keys = [e["attribute_key"] for e in SKILL_EXAMS]
    assert sorted(keys) == ["passing", "shooting", "tackling"]
    assert len(set(keys)) == len(keys)


# --- grading ---------------------------------------------------------------

def test_each_level_is_worth_one_point(api_client, created_career):
    """The grading scale: one point per level, so grade 5 is +5."""
    career_id = created_career["career_id"]
    before = _attr(api_client, career_id, "shooting")

    resp = _submit(api_client, career_id, [{"exam_id": "shooting", "level": 5}])
    assert resp.status_code == 200

    result = resp.json()["results"][0]
    assert result["attribute_key"] == "shooting"
    assert result["before"] == before
    assert result["applied"] == 5.0
    assert _attr(api_client, career_id, "shooting") == before + 5.0


def test_lowest_grade_still_awards_its_level(api_client, created_career):
    career_id = created_career["career_id"]
    before = _attr(api_client, career_id, "tackling")

    _submit(api_client, career_id, [{"exam_id": "tackling", "level": MIN_LEVEL}])
    assert _attr(api_client, career_id, "tackling") == before + float(MIN_LEVEL)


def test_exam_points_stack_on_top_of_the_role_bonus(api_client):
    """§2 - the exam adds to the role's starting spread, it doesn't replace
    it. merkez_orta_saha spends both slots on passing, so passing starts at
    base + 2*bonus and the exam lifts it from there."""
    body = create_career(api_client, position="Orta saha", role="merkez_orta_saha")
    career_id = body["career_id"]

    expected_start = BASE_SKILL_VALUE + 2 * ROLE_BONUS_PER_SLOT
    assert _attr(api_client, career_id, "passing") == expected_start

    _submit(api_client, career_id, [{"exam_id": "passing", "level": 3}])
    assert _attr(api_client, career_id, "passing") == expected_start + 3.0


def test_all_three_exams_apply_in_one_request(api_client, created_career):
    career_id = created_career["career_id"]
    resp = _submit(api_client, career_id, [
        {"exam_id": "shooting", "level": 2},
        {"exam_id": "passing", "level": 4},
        {"exam_id": "tackling", "level": 5},
    ])
    assert resp.status_code == 200
    applied = {r["exam_id"]: r["applied"] for r in resp.json()["results"]}
    assert applied == {"shooting": 2.0, "passing": 4.0, "tackling": 5.0}


def test_exam_never_exceeds_its_max_value(db_conn, monkeypatch):
    """max_value is the exam's own ceiling, separate from the 0-100 clamp:
    an attribute already at the cap gains nothing rather than overshooting."""
    from domain import onboarding

    career_id = onboarding.create_career(
        db_conn, first_name="Efe", last_name="Kaan", nationality="TR",
        position="Forvet", role="firsatci_forvet", target_team_id="t_gal", seed=1,
    )
    db_conn.commit()

    exam = get_exam("shooting")
    monkeypatch.setitem(exam, "max_value", 25.0)

    # firsatci_forvet doubles down on shooting: base 20 + 2*2 = 24.
    before = attributes.get_value(db_conn, career_id, "p_user", "shooting")
    assert before == 24.0

    changes = skill_exams.apply_results(
        db_conn, career_id, "p_user", [{"exam_id": "shooting", "level": 5}], "2026-08-01"
    )
    # Grade 5 is worth +5, but the cap allows only +1.
    assert changes[0]["applied"] == 1.0
    assert attributes.get_value(db_conn, career_id, "p_user", "shooting") == 25.0


# --- validation ------------------------------------------------------------

@pytest.mark.parametrize("level", [0, MAX_LEVEL + 1, -3])
def test_level_outside_the_scale_is_rejected(api_client, created_career, level):
    career_id = created_career["career_id"]
    resp = _submit(api_client, career_id, [{"exam_id": "shooting", "level": level}])
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_request"


def test_unknown_exam_id_is_rejected(api_client, created_career):
    career_id = created_career["career_id"]
    resp = _submit(api_client, career_id, [{"exam_id": "heading", "level": 3}])
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_request"


def test_duplicate_exam_in_one_request_is_rejected(api_client, created_career):
    career_id = created_career["career_id"]
    resp = _submit(api_client, career_id, [
        {"exam_id": "shooting", "level": 1},
        {"exam_id": "shooting", "level": 5},
    ])
    assert resp.status_code == 422


def test_empty_results_is_rejected(api_client, created_career):
    career_id = created_career["career_id"]
    resp = _submit(api_client, career_id, [])
    assert resp.status_code == 422


def test_resubmitting_an_exam_is_refused(api_client, created_career):
    career_id = created_career["career_id"]
    assert _submit(api_client, career_id, [{"exam_id": "shooting", "level": 3}]).status_code == 200

    resp = _submit(api_client, career_id, [{"exam_id": "shooting", "level": 5}])
    assert resp.status_code == 409
    assert resp.json()["code"] == "skill_exam_already_taken"


def test_a_refused_batch_applies_nothing(api_client, created_career):
    """Validation runs over the whole batch first, so a bad grade at the end
    can't leave the earlier exams applied."""
    career_id = created_career["career_id"]
    before = _attr(api_client, career_id, "shooting")

    resp = _submit(api_client, career_id, [
        {"exam_id": "shooting", "level": 5},
        {"exam_id": "passing", "level": 99},
    ])
    assert resp.status_code == 422
    assert _attr(api_client, career_id, "shooting") == before


def test_a_partly_taken_batch_applies_nothing(api_client, created_career):
    career_id = created_career["career_id"]
    _submit(api_client, career_id, [{"exam_id": "passing", "level": 2}])
    before = _attr(api_client, career_id, "shooting")

    resp = _submit(api_client, career_id, [
        {"exam_id": "shooting", "level": 5},
        {"exam_id": "passing", "level": 2},   # already taken
    ])
    assert resp.status_code == 409
    assert _attr(api_client, career_id, "shooting") == before


def test_exams_do_not_touch_strength_or_flexibility(api_client, created_career):
    """§2 - Güç and Esneklik are exam-proof."""
    career_id = created_career["career_id"]
    before = {k: _attr(api_client, career_id, k) for k in ("strength", "flexibility")}

    _submit(api_client, career_id, [
        {"exam_id": "shooting", "level": 5},
        {"exam_id": "passing", "level": 5},
        {"exam_id": "tackling", "level": 5},
    ])

    after = {k: _attr(api_client, career_id, k) for k in ("strength", "flexibility")}
    assert after == before


def test_unknown_career_404s(api_client):
    resp = _submit(api_client, "car_doesnotexist", [{"exam_id": "shooting", "level": 1}])
    assert resp.status_code == 404


def test_domain_layer_raises_api_error_for_bad_level(db_conn):
    from domain import onboarding

    career_id = onboarding.create_career(
        db_conn, first_name="Efe", last_name="Kaan", nationality="TR",
        position="Orta saha", role="regista", target_team_id="t_gal", seed=1,
    )
    db_conn.commit()

    with pytest.raises(ApiError) as exc_info:
        skill_exams.apply_results(
            db_conn, career_id, "p_user", [{"exam_id": "passing", "level": 0}], "2026-08-01"
        )
    assert exc_info.value.code == "invalid_request"
