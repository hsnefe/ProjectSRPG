"""§12.9, D59/D60 - two invitations for one evening.

Covers both sources (two plans falling due together, which is certain, and the
low-chance day that opens two offers at once), the advance gate that stands in
front of them, and the `choose` endpoint that closes both sides in one
transaction.

Also holds the regression for `daytime.resolve_pending_today`, which used to
raise NameError on any day the sponsorship roll actually hit.
"""
import sqlite3

from api import config
from domain import social, sponsorship
from tests.conftest import new_career


def _today(api_client, career_id):
    return api_client.get(f"/careers/{career_id}/day").json()["career_state"]["current_date"]


def _insert_plan(career_id, plan_id, template_id, relationship_id, due_on):
    conn = sqlite3.connect(config.DB_PATH)
    conn.execute(
        "INSERT INTO social_plan (career_id, plan_id, offer_id, template_id, "
        "relationship_id, due_on, status) VALUES (?, ?, 'so_seed', ?, ?, ?, 'pending')",
        (career_id, plan_id, template_id, relationship_id, due_on),
    )
    conn.commit()
    conn.close()


def _two_due_plans(api_client, career_id, due_on=None):
    """The certain source: two promises for the same evening."""
    due_on = due_on or _today(api_client, career_id)
    _insert_plan(career_id, "spl_test0001", "coach_extra_session", "coach", due_on)
    _insert_plan(career_id, "spl_test0002", "team_dinner", "team", due_on)
    return due_on


def _conflict(api_client, career_id):
    conflicts = api_client.get(f"/careers/{career_id}/social/conflicts").json()["conflicts"]
    return conflicts[0] if conflicts else None


# --- the certain source: two plans on one day -------------------------------

def test_two_plans_due_together_always_make_a_conflict(api_client, mock_engine):
    career_id, _ = new_career(api_client)
    due_on = _two_due_plans(api_client, career_id)

    conflict = _conflict(api_client, career_id)
    assert conflict is not None
    assert conflict["source"] == "plan"
    assert conflict["due_on"] == due_on
    assert conflict["status"] == "open"
    assert conflict["chosen_ref"] is None
    assert {s["ref_id"] for s in conflict["sides"]} == {"spl_test0001", "spl_test0002"}
    assert {s["relationship_id"] for s in conflict["sides"]} == {"coach", "team"}
    # The people behind the two evenings travel with them (§5.8: FE writes the
    # label, BE supplies the name and the score).
    assert all(s["relationship"]["contact_name"] for s in conflict["sides"])


def test_the_conflict_is_sticky(api_client, mock_engine):
    """Lazy and sticky, like §12.2's squad decision: T1 and the advance gate
    have to be looking at the same conflict row, not two freshly-decided ones."""
    career_id, _ = new_career(api_client)
    _two_due_plans(api_client, career_id)

    first = _conflict(api_client, career_id)["conflict_id"]
    assert _conflict(api_client, career_id)["conflict_id"] == first
    # The advance gate names the same one.
    resp = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})
    assert first in resp.json()["message"]


def test_a_single_due_plan_is_not_a_conflict(api_client, mock_engine):
    """Regression on §12.8: one plan still goes down the plain attend/skip
    path and still raises its own gate code."""
    career_id, _ = new_career(api_client)
    _insert_plan(
        career_id, "spl_test0001", "coach_extra_session", "coach",
        _today(api_client, career_id),
    )

    assert _conflict(api_client, career_id) is None
    resp = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})
    assert resp.json()["code"] == "social_plan_pending"


def test_a_due_conflict_blocks_advance_before_the_plan_gate(api_client, mock_engine):
    career_id, _ = new_career(api_client)
    _two_due_plans(api_client, career_id)

    resp = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})
    assert resp.status_code == 409
    body = resp.json()
    assert body["code"] == "social_conflict_pending"
    assert "scf_" in body["message"]


def test_a_conflict_due_tomorrow_stops_the_loop_on_its_day(api_client, mock_engine):
    career_id, _ = new_career(api_client)
    today = _today(api_client, career_id)
    from datetime import date, timedelta
    tomorrow = (date.fromisoformat(today) + timedelta(days=1)).isoformat()
    _two_due_plans(api_client, career_id, due_on=tomorrow)

    body = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"}).json()
    assert body["stop_reason"] == "social_conflict_due"
    assert body["stopped_on"] == tomorrow
    kinds = [e["kind"] for e in body["stopped_events"]]
    assert "social_conflict_due" in kinds
    # The two halves are reported once, as the conflict — not again on their own.
    assert "social_plan_due" not in kinds


# --- choosing ---------------------------------------------------------------

def test_choosing_closes_both_sides_and_returns_both_changes(api_client, mock_engine):
    career_id, _ = new_career(api_client)
    _two_due_plans(api_client, career_id)
    conflict = _conflict(api_client, career_id)

    resp = api_client.post(
        f"/careers/{career_id}/social/conflicts/{conflict['conflict_id']}"
        f"/choose/spl_test0001"
    )
    assert resp.status_code == 200, resp.json()
    body = resp.json()

    assert body["conflict"]["status"] == "resolved"
    assert body["conflict"]["chosen_ref"] == "spl_test0001"

    # INV-52: exactly two, one each way.
    changes = {c["relationship_id"]: c for c in body["relationship_changes"]}
    assert set(changes) == {"coach", "team"}
    assert changes["coach"]["delta"] == social.CHOSEN_CONFLICT_RELATIONSHIP_DELTA
    assert changes["team"]["delta"] == social.MISSED_PLAN_RELATIONSHIP_DELTA
    assert changes["coach"]["after"] > changes["coach"]["before"]
    assert changes["team"]["after"] < changes["team"]["before"]

    plans = {
        r[0]: r[1]
        for r in sqlite3.connect(config.DB_PATH)
        .execute("SELECT plan_id, status FROM social_plan WHERE career_id = ?", (career_id,))
        .fetchall()
    }
    assert plans == {"spl_test0001": "done", "spl_test0002": "missed"}

    # And time moves again.
    assert api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"}).status_code == 200


def test_choosing_spends_nothing(api_client, mock_engine):
    """D60. The chosen template costs 2h and 20 energy as a plain plan; a
    conflict charges neither, because the answer is mandatory and INV-40's
    argument does not stop applying just because both doors cost something."""
    career_id, _ = new_career(api_client)
    _two_due_plans(api_client, career_id)
    conflict = _conflict(api_client, career_id)
    before = api_client.get(f"/careers/{career_id}/day").json()["career_state"]

    body = api_client.post(
        f"/careers/{career_id}/social/conflicts/{conflict['conflict_id']}"
        f"/choose/spl_test0001"
    ).json()

    assert body["career_state"]["day_budget"] == before["day_budget"]
    assert body["career_state"]["money"] == before["money"]


def test_choosing_works_with_an_empty_day_budget(api_client, mock_engine):
    """The soft-lock this rule exists to prevent: a player who already spent
    the day must still be able to answer."""
    career_id, _ = new_career(api_client)
    _two_due_plans(api_client, career_id)
    conflict = _conflict(api_client, career_id)
    conn = sqlite3.connect(config.DB_PATH)
    conn.execute("UPDATE day_budget SET remaining = 0 WHERE career_id = ?", (career_id,))
    conn.commit()
    conn.close()

    resp = api_client.post(
        f"/careers/{career_id}/social/conflicts/{conflict['conflict_id']}"
        f"/choose/spl_test0002"
    )
    assert resp.status_code == 200, resp.json()


def test_either_side_can_be_chosen(api_client, mock_engine):
    career_id, _ = new_career(api_client)
    _two_due_plans(api_client, career_id)
    conflict = _conflict(api_client, career_id)

    body = api_client.post(
        f"/careers/{career_id}/social/conflicts/{conflict['conflict_id']}"
        f"/choose/spl_test0002"
    ).json()

    changes = {c["relationship_id"]: c["delta"] for c in body["relationship_changes"]}
    assert changes["team"] == social.CHOSEN_CONFLICT_RELATIONSHIP_DELTA
    assert changes["coach"] == social.MISSED_PLAN_RELATIONSHIP_DELTA


def test_choosing_twice_is_refused(api_client, mock_engine):
    career_id, _ = new_career(api_client)
    _two_due_plans(api_client, career_id)
    cid = _conflict(api_client, career_id)["conflict_id"]

    api_client.post(f"/careers/{career_id}/social/conflicts/{cid}/choose/spl_test0001")
    resp = api_client.post(f"/careers/{career_id}/social/conflicts/{cid}/choose/spl_test0002")
    assert resp.status_code == 409
    assert resp.json()["code"] == "social_conflict_not_open"


def test_unknown_conflict_is_404(api_client, mock_engine):
    career_id, _ = new_career(api_client)
    resp = api_client.post(
        f"/careers/{career_id}/social/conflicts/scf_nope/choose/spl_test0001"
    )
    assert resp.status_code == 404
    assert resp.json()["code"] == "social_conflict_not_found"


def test_a_ref_from_outside_the_conflict_is_422(api_client, mock_engine):
    career_id, _ = new_career(api_client)
    _two_due_plans(api_client, career_id)
    cid = _conflict(api_client, career_id)["conflict_id"]

    resp = api_client.post(f"/careers/{career_id}/social/conflicts/{cid}/choose/spl_other")
    assert resp.status_code == 422
    assert resp.json()["code"] == "invalid_request"
    # The message names the two that would have worked (§1.3: FE writes the
    # sentence, so the ids have to travel).
    assert "spl_test0001" in resp.json()["message"]


def test_a_side_cannot_be_answered_on_its_own(api_client, mock_engine):
    """INV-53. Attending one half would leave the other half's penalty
    unwritten and the conflict row open forever."""
    career_id, _ = new_career(api_client)
    _two_due_plans(api_client, career_id)
    _conflict(api_client, career_id)  # materialise it

    for verb in ("attend", "skip"):
        resp = api_client.post(f"/careers/{career_id}/social/plans/spl_test0001/{verb}")
        assert resp.status_code == 409, verb
        assert resp.json()["code"] == "social_conflict_member"


# --- the low-chance source: two offers at once ------------------------------

def _always_conflict(monkeypatch):
    monkeypatch.setattr(config, "SOCIAL_CONFLICT_DAILY_CHANCE", 1.0)


def test_a_conflict_day_opens_two_offers_for_two_different_people(db_conn, career_id, seeded_relationship, monkeypatch):
    _always_conflict(monkeypatch)
    db_conn.execute(
        "INSERT INTO relationship (career_id, relationship_id, kind, category, score, "
        "person_name, contact_name, last_contact_at, traits) VALUES "
        "(?, 'partner', 'partner', 'Sevgili', 60, 'Deniz', 'Deniz', NULL, '{}')",
        (career_id,),
    )

    conflict = social.maybe_generate_conflict(db_conn, career_id, "2026-09-12", 7)

    assert conflict is not None
    assert conflict["source"] == "offer"
    assert len(conflict["sides"]) == 2
    rels = [s["relationship_id"] for s in conflict["sides"]]
    assert len(set(rels)) == 2, "a dilemma needs two different people"
    # Both halves really are open offers.
    assert len(social.list_open(db_conn, career_id)) == 2


def test_the_conflict_roll_is_off_by_default(db_conn, career_id, seeded_relationship):
    """The autouse fixture zeroes it, and at 0.0 the roll is a hard no."""
    assert social.maybe_generate_conflict(db_conn, career_id, "2026-09-12", 7) is None


def test_the_conflict_roll_is_deterministic_from_the_seed(career_id, seeded_relationship, monkeypatch):
    """INV-7, checked the way test_social_offers does it: two independent
    databases, the same seed and date, the same pair."""
    _always_conflict(monkeypatch)
    from db.connection import get_connection
    from db.migrate import apply_migrations

    picks = []
    for _ in range(2):
        conn = get_connection(":memory:")
        apply_migrations(conn)
        conn.execute(
            "INSERT INTO career (career_id, created_at, seed, schema_version) "
            "VALUES ('c', '2026-01-01T00:00:00+03:00', 1, 1)"
        )
        for rid, kind, cat in (("coach", "coach", "Antrenör"), ("partner", "partner", "Sevgili")):
            conn.execute(
                "INSERT INTO relationship (career_id, relationship_id, kind, category, score, "
                "person_name, contact_name, last_contact_at, traits) "
                "VALUES ('c', ?, ?, ?, 50, 'X', 'X', NULL, '{}')",
                (rid, kind, cat),
            )
        conflict = social.maybe_generate_conflict(conn, "c", "2026-09-12", 7)
        picks.append(tuple(sorted(s["template_id"] for s in conflict["sides"])))
        conn.close()

    assert picks[0] == picks[1]


def test_the_offer_conflict_costs_the_loser_less_than_a_broken_promise(db_conn, career_id, seeded_relationship, monkeypatch):
    """D59's whole point: nobody was promised anything on a spontaneous day,
    so turning one down is a decline, not a broken appointment."""
    _always_conflict(monkeypatch)
    db_conn.execute(
        "INSERT INTO relationship (career_id, relationship_id, kind, category, score, "
        "person_name, contact_name, last_contact_at, traits) VALUES "
        "(?, 'partner', 'partner', 'Sevgili', 60, 'Deniz', 'Deniz', NULL, '{}')",
        (career_id,),
    )
    conflict = social.maybe_generate_conflict(db_conn, career_id, "2026-09-12", 7)

    for side in conflict["sides"]:
        decline_delta = social.template(side["template_id"])["decline"]["relationship_delta"]
        assert abs(decline_delta) < abs(social.MISSED_PLAN_RELATIONSHIP_DELTA)


def test_a_plan_day_does_not_also_roll_a_spontaneous_conflict(db_conn, career_id, seeded_relationship, monkeypatch):
    """The certain source owns a day that already has a promise on it."""
    _always_conflict(monkeypatch)
    db_conn.execute(
        "INSERT INTO social_plan (career_id, plan_id, offer_id, template_id, "
        "relationship_id, due_on, status) VALUES (?, 'spl_x', 'so_x', "
        "'coach_extra_session', 'coach', '2026-09-12', 'pending')",
        (career_id,),
    )

    assert social.maybe_generate_conflict(db_conn, career_id, "2026-09-12", 7) is None


def test_an_open_offer_blocks_the_conflict_roll(db_conn, career_id, seeded_relationship, monkeypatch):
    """INV-39 narrowed, not repealed: one open offer OR one pair, never both."""
    _always_conflict(monkeypatch)
    db_conn.execute(
        "INSERT INTO social_offer (career_id, offer_id, template_id, relationship_id, "
        "opened_on, status, resolved_on) VALUES (?, 'so_x', 'team_dinner', 'team', "
        "'2026-09-11', 'open', NULL)",
        (career_id,),
    )

    assert social.maybe_generate_conflict(db_conn, career_id, "2026-09-12", 7) is None


# --- regression: the day being left behind ----------------------------------

def test_a_sponsorship_roll_on_the_current_day_does_not_crash_advance(api_client, mock_engine, monkeypatch):
    """`resolve_pending_today` appended to a name that did not exist, so every
    day the 4% roll actually hit raised NameError out of T3 — and a fixed
    append would still have been dropped by a return value with no such key."""
    monkeypatch.setattr(sponsorship, "DAILY_CHANCE", 1.0)
    career_id, _ = new_career(api_client)

    resp = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})
    assert resp.status_code == 200, resp.json()
    kinds = [e["kind"] for e in resp.json()["stopped_events"]]
    assert "sponsorship_offer" in kinds


def test_the_reported_delta_is_the_one_actually_applied(api_client, mock_engine):
    """`partner` starts at 0, so a -12 has nowhere to go. apply_delta clamps
    and reports the post-clamp value; the screen animates `before -> after`
    rather than recomputing, so the two have to agree."""
    career_id, _ = new_career(api_client)
    due_on = _today(api_client, career_id)
    _insert_plan(career_id, "spl_test0001", "coach_extra_session", "coach", due_on)
    _insert_plan(career_id, "spl_test0002", "partner_evening_out", "partner", due_on)
    cid = _conflict(api_client, career_id)["conflict_id"]

    body = api_client.post(
        f"/careers/{career_id}/social/conflicts/{cid}/choose/spl_test0001"
    ).json()

    partner = next(c for c in body["relationship_changes"] if c["relationship_id"] == "partner")
    assert partner["before"] == 0
    assert partner["after"] == 0
    assert partner["delta"] == 0, "not -12: the score had nowhere left to fall"
