"""§13.1 club-scoped relationships and §13.2 the partner lifecycle."""
import pytest

from api import config
from tests.conftest import create_career, grant_money, seed_social, set_attribute
from worlddata.relationships import CLUB_STAFF_POOL, STARTING_SCORES


@pytest.fixture
def created_career(api_client):
    return create_career(api_client)


def _db():
    from db.connection import get_connection
    return get_connection(config.DB_PATH)


def _relationship(career_id, relationship_id):
    conn = _db()
    try:
        return dict(conn.execute(
            "SELECT * FROM relationship WHERE career_id = ? AND relationship_id = ?",
            (career_id, relationship_id),
        ).fetchone())
    finally:
        conn.close()


# --- §13.1 scope ------------------------------------------------------------

def test_new_career_seeds_scope_and_team(api_client, created_career):
    """INV-56 - a club-scoped row always names the club it belongs to, and
    that club is the player's."""
    career_id = created_career["career_id"]
    conn = _db()
    try:
        rows = {
            r["relationship_id"]: dict(r)
            for r in conn.execute(
                "SELECT relationship_id, scope, team_id FROM relationship WHERE career_id = ?",
                (career_id,),
            ).fetchall()
        }
        team_id = conn.execute(
            "SELECT team_id FROM player WHERE career_id = ? AND is_user = 1", (career_id,)
        ).fetchone()["team_id"]
    finally:
        conn.close()

    for rid in config.CLUB_SCOPED_RELATIONSHIPS:
        assert rows[rid]["scope"] == "club"
        assert rows[rid]["team_id"] == team_id

    for rid in ("media", "partner", "family"):
        assert rows[rid]["scope"] == "career"
        assert rows[rid]["team_id"] is None


def test_club_identity_is_deterministic():
    """INV-7 - the same career replayed meets the same people. The pool is
    indexed, not rolled."""
    from domain import relationships

    a = relationships.club_identity(41, "t_dnz", "coach")
    b = relationships.club_identity(41, "t_dnz", "coach")
    assert a == b
    assert a in CLUB_STAFF_POOL["coach"]

    # ...and a different club is allowed to be a different person. Not
    # guaranteed for any given pair (three entries, so collisions exist), but
    # the key must at least reach more than one of them across the world.
    seen = {
        relationships.club_identity(41, f"t_{i}", "coach")["person_name"]
        for i in range(30)
    }
    assert len(seen) > 1


def test_transfer_resets_score_traits_and_identity(api_client, created_career, db_conn):
    """§13.1/D69 - all three layers, in the transaction that moves the player."""
    from domain import relationships, transfer

    career_id = created_career["career_id"]
    conn = _db()
    try:
        # A coach who trusts this player and a stand that loves them.
        relationships.apply_delta(conn, career_id, "coach", 25, "test", "2026-09-01T00:00:00+03:00")
        relationships.apply_trait_delta(conn, career_id, "coach", trust=30.0)
        relationships.apply_delta(conn, career_id, "fans", 30, "test", "2026-09-01T00:00:00+03:00")
        # ...and a family that does not move with the club.
        relationships.apply_delta(conn, career_id, "family", 20, "test", "2026-09-01T00:00:00+03:00")
        conn.commit()

        new_team = conn.execute(
            "SELECT team_id FROM team WHERE career_id = ? AND team_id != "
            "(SELECT team_id FROM player WHERE career_id = ? AND is_user = 1) LIMIT 1",
            (career_id, career_id),
        ).fetchone()["team_id"]
        seed = conn.execute(
            "SELECT seed FROM career WHERE career_id = ?", (career_id,)
        ).fetchone()["seed"]

        before_coach = dict(conn.execute(
            "SELECT score, person_name FROM relationship WHERE career_id = ? AND relationship_id = 'coach'",
            (career_id,),
        ).fetchone())
        assert before_coach["score"] == STARTING_SCORES["coach"] + 25

        resets = relationships.reset_for_club(
            conn, career_id, new_team, seed, "2026-09-02T00:00:00+03:00"
        )
        conn.commit()
    finally:
        conn.close()

    assert {r["relationship_id"] for r in resets} == set(config.CLUB_SCOPED_RELATIONSHIPS)

    coach = _relationship(career_id, "coach")
    assert coach["score"] == STARTING_SCORES["coach"]          # 1 - score
    assert coach["team_id"] == new_team
    assert coach["last_contact_at"] is None

    import json
    assert json.loads(coach["traits"])["trust"] == 50.0        # 2 - traits (§12.2's input)

    expected = relationships.club_identity(seed, new_team, "coach")
    assert coach["person_name"] == expected["person_name"]     # 3 - identity
    assert coach["person_name"] != before_coach["person_name"]

    # ...and the career-scoped side is untouched.
    family = _relationship(career_id, "family")
    assert family["score"] == STARTING_SCORES["family"] + 20
    assert family["person_name"] == "Sevgi Yılmaz"


def test_reset_keeps_the_event_log_replayable(api_client, created_career):
    """INV-57, and the reason reset_for_club goes through apply_delta rather
    than a bare UPDATE: §3.4 promises the stored score can be rebuilt from
    relationship_event, and a silent reset would break that on the first
    transfer."""
    from domain import relationships

    career_id = created_career["career_id"]
    conn = _db()
    try:
        relationships.apply_delta(conn, career_id, "coach", 25, "test", "2026-09-01T00:00:00+03:00")
        relationships.reset_for_club(
            conn, career_id, "t_other", 7, "2026-09-02T00:00:00+03:00"
        )
        conn.commit()

        stored = relationships.get_score(conn, career_id, "coach")
        replayed = relationships.replay_score(conn, career_id, "coach")
    finally:
        conn.close()

    assert stored == replayed == STARTING_SCORES["coach"]


def test_season_rollover_does_not_reset(api_client, created_career):
    """§13.1 - the trigger is player.team_id changing, nothing else. A club
    that gets promoted is still the same club."""
    from domain import relationships, rollover  # noqa: F401  (import proves the module loads)

    career_id = created_career["career_id"]
    conn = _db()
    try:
        relationships.apply_delta(conn, career_id, "coach", 20, "test", "2026-09-01T00:00:00+03:00")
        conn.commit()
        before = relationships.get_score(conn, career_id, "coach")
    finally:
        conn.close()

    # Nothing in the rollover path touches relationships; asserted as a
    # regression guard rather than by driving a whole season.
    import inspect
    from domain import rollover as rollover_mod
    assert "reset_for_club" not in inspect.getsource(rollover_mod)
    assert before == STARTING_SCORES["coach"] + 20


# --- §13.2 partner lifecycle ------------------------------------------------

def test_partner_starts_absent_and_is_not_listed(api_client, created_career):
    """INV-58. The row exists (get_score has something to return) but R1 does
    not serve it."""
    career_id = created_career["career_id"]
    assert _relationship(career_id, "partner")["state"] == config.STATE_ABSENT

    rels = api_client.get(f"/careers/{career_id}/relationships").json()["relationships"]
    assert "partner" not in {r["relationship_id"] for r in rels}
    assert len(rels) == 5


def test_interact_with_an_absent_relationship_is_refused(api_client, created_career):
    """§13.2 - and before D42's gate, so the message is about the person, not
    a threshold."""
    career_id = created_career["career_id"]
    before = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["day_budget"]

    resp = api_client.post(
        f"/careers/{career_id}/relationships/partner/interact",
        json={"dialogue_id": "partner_01", "choice_path": ["start", "r0"]},
    )
    assert resp.status_code == 409
    assert resp.json()["code"] == "relationship_absent"

    after = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["day_budget"]
    assert after == before   # nothing spent


def _make_courting(career_id):
    from domain import relationships
    conn = _db()
    try:
        relationships.set_state(conn, career_id, "partner", config.STATE_COURTING)
        conn.commit()
    finally:
        conn.close()


def test_courting_partner_is_listed_and_can_be_established(api_client, created_career):
    """§13.2/D72 - the leaf that turns a courting relationship into a real one."""
    career_id = created_career["career_id"]
    seed_social(career_id)
    _make_courting(career_id)

    rels = api_client.get(f"/careers/{career_id}/relationships").json()["relationships"]
    partner = next(r for r in rels if r["relationship_id"] == "partner")
    assert partner["state"] == config.STATE_COURTING

    resp = api_client.post(
        f"/careers/{career_id}/relationships/partner/interact",
        json={"dialogue_id": "partner_01", "choice_path": ["start", "c0"]},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["relationship_state_changes"] == [
        {"relationship_id": "partner", "before": "courting", "after": "active"}
    ]
    assert _relationship(career_id, "partner")["state"] == config.STATE_ACTIVE


def test_courting_can_be_turned_down(api_client, created_career):
    career_id = created_career["career_id"]
    _make_courting(career_id)

    resp = api_client.post(
        f"/careers/{career_id}/relationships/partner/interact",
        json={"dialogue_id": "partner_01", "choice_path": ["start", "c1"]},
    )
    assert resp.status_code == 200
    assert resp.json()["relationship_state_changes"] == [
        {"relationship_id": "partner", "before": "courting", "after": "absent"}
    ]
    # ...and the card goes away again.
    rels = api_client.get(f"/careers/{career_id}/relationships").json()["relationships"]
    assert "partner" not in {r["relationship_id"] for r in rels}


def test_sets_state_is_ignored_once_the_relationship_is_active(api_client, created_career):
    """§13.2/D72 - the same tree serves both phases; a leaf cannot re-open a
    relationship that already exists."""
    from domain import relationships

    career_id = created_career["career_id"]
    conn = _db()
    try:
        relationships.set_state(conn, career_id, "partner", config.STATE_ACTIVE)
        relationships.apply_delta(conn, career_id, "partner", 40, "test", "2026-09-01T00:00:00+03:00")
        conn.commit()
    finally:
        conn.close()

    resp = api_client.post(
        f"/careers/{career_id}/relationships/partner/interact",
        json={"dialogue_id": "partner_01", "choice_path": ["start", "c1"]},   # sets_state: absent
    )
    assert resp.status_code == 200
    assert resp.json()["relationship_state_changes"] == []
    assert _relationship(career_id, "partner")["state"] == config.STATE_ACTIVE


def test_partner_ends_when_the_score_reaches_zero(api_client, created_career):
    """§13.2 - handled at the single write path, so all three ways in (decay,
    a bad leaf, a missed plan) get the same answer."""
    from domain import relationships

    career_id = created_career["career_id"]
    conn = _db()
    try:
        relationships.set_state(conn, career_id, "partner", config.STATE_ACTIVE)
        relationships.apply_delta(conn, career_id, "partner", 5, "test", "2026-09-01T00:00:00+03:00")
        conn.commit()
        assert relationships.get_state(conn, career_id, "partner") == config.STATE_ACTIVE

        relationships.apply_delta(conn, career_id, "partner", -99, "decay", "2026-09-02T00:00:00+03:00")
        conn.commit()

        assert relationships.get_score(conn, career_id, "partner") == 0
        assert relationships.get_state(conn, career_id, "partner") == config.STATE_ABSENT
        reasons = [
            r["reason"] for r in conn.execute(
                "SELECT reason FROM relationship_event WHERE career_id = ? AND relationship_id = 'partner'",
                (career_id,),
            ).fetchall()
        ]
        assert "partner_ended" in reasons
    finally:
        conn.close()


def test_only_partner_has_a_state_machine(api_client, created_career):
    """INV-59 - a content typo cannot give the coach a lifecycle."""
    from api.errors import ApiError
    from domain import relationships

    career_id = created_career["career_id"]
    conn = _db()
    try:
        with pytest.raises(ApiError):
            relationships.set_state(conn, career_id, "coach", config.STATE_ABSENT)

        # ...and a coach on zero is still a coach.
        relationships.apply_delta(conn, career_id, "coach", -99, "decay", "2026-09-02T00:00:00+03:00")
        conn.commit()
        assert relationships.get_score(conn, career_id, "coach") == 0
        assert relationships.get_state(conn, career_id, "coach") == config.STATE_ACTIVE
    finally:
        conn.close()
