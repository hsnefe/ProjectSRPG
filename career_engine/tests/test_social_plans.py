"""§12.8, D58 - a `plan_days_ahead` social-offer template schedules a
`social_plan` instead of resolving on the spot; domain/social.py's plan
functions, the accept-time branch in api/routers/social.py, and the
attend/skip endpoints + advance gate that follow from it."""
import sqlite3

import pytest

from api import config
from content import validate_social_offers
from content.social_offers import SOCIAL_OFFERS
from domain import social
from tests.conftest import new_career


# --- the pool ---------------------------------------------------------------

def test_exactly_one_shipped_template_schedules_a_plan():
    """coach_extra_session is the only body that promises a specific future
    day ("yarın sabah") — the other six stay instant."""
    scheduled = [t["template_id"] for t in SOCIAL_OFFERS if t.get("plan_days_ahead")]
    assert scheduled == ["coach_extra_session"]
    assert social.template("coach_extra_session")["plan_days_ahead"] == 1


@pytest.mark.parametrize("plan_days_ahead", [0, -1, 1.5, "1", True])
def test_validator_rejects_a_bad_plan_days_ahead(plan_days_ahead):
    tpl = {
        "template_id": "t", "relationship_id": "coach",
        "weight": 1, "cooldown_days": 7, "min_score": 0, "max_score": 100,
        "title": "T", "body": "B", "accept_label": "E", "decline_label": "H",
        "accept": {"relationship_delta": 1, "effects": {}},
        "decline": {"relationship_delta": -1, "effects": {}},
        "plan_days_ahead": plan_days_ahead,
    }
    with pytest.raises(ValueError):
        validate_social_offers([tpl])


# --- domain.social plan functions -------------------------------------------

def test_create_list_and_resolve_a_plan(db_conn, career_id, player_id):
    assert social.list_due_plans(db_conn, career_id, "2026-08-02") == []

    plan = social.create_plan(
        db_conn, career_id, "so_x", "coach_extra_session", "coach", "2026-08-02",
    )
    assert plan["plan_id"].startswith("spl_")
    assert plan["status"] == social.PLAN_PENDING
    assert plan["title"] and plan["body"]  # authored text joined in

    # Not due yet.
    assert social.list_due_plans(db_conn, career_id, "2026-08-01") == []
    # Due today, and still due if "today" has moved past it (overdue).
    assert [p["plan_id"] for p in social.list_due_plans(db_conn, career_id, "2026-08-02")] == [plan["plan_id"]]
    assert [p["plan_id"] for p in social.list_due_plans(db_conn, career_id, "2026-08-05")] == [plan["plan_id"]]

    social.mark_plan_done(db_conn, career_id, plan["plan_id"])
    assert social.get_plan(db_conn, career_id, plan["plan_id"])["status"] == social.PLAN_DONE
    assert social.list_due_plans(db_conn, career_id, "2026-08-05") == []


def test_get_plan_unknown_is_none(db_conn, career_id):
    assert social.get_plan(db_conn, career_id, "spl_nope") is None


# --- accept-time branching (router) -----------------------------------------

def _open_offer(api_client, career_id, template_id, relationship_id="coach"):
    """A career sitting on one open offer for a specific template, bypassing
    the daily roll so the test controls exactly which template is answered
    (mirrors test_social_offers.py::test_an_offer_from_a_since_deleted_template_still_reads)."""
    opened_on = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["current_date"]
    conn = sqlite3.connect(config.DB_PATH)
    conn.execute(
        "INSERT INTO social_offer (career_id, offer_id, template_id, relationship_id, "
        "opened_on, status, resolved_on) VALUES (?, 'so_test0001', ?, ?, ?, 'open', NULL)",
        (career_id, template_id, relationship_id, opened_on),
    )
    conn.commit()
    conn.close()
    return opened_on


def test_accepting_a_plan_template_applies_relationship_now_but_defers_the_rest(api_client, mock_engine):
    career_id, _ = new_career(api_client)
    opened_on = _open_offer(api_client, career_id, "coach_extra_session")
    budget_before = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["day_budget"]

    resp = api_client.post(f"/careers/{career_id}/social/offers/so_test0001/accept")
    assert resp.status_code == 200, resp.json()
    body = resp.json()

    assert body["offer"]["status"] == "accepted"
    # The relationship moves immediately (decision #1).
    assert len(body["relationship_changes"]) == 1
    assert body["relationship_changes"][0]["delta"] > 0
    # Everything else is withheld (decision #2).
    assert body["attribute_changes"] == []
    assert body["ledger_entries"] == []
    assert body["career_state"]["day_budget"] == budget_before

    assert body["plan"] is not None
    assert body["plan"]["status"] == "pending"
    assert body["plan"]["template_id"] == "coach_extra_session"
    from datetime import date, timedelta
    assert body["plan"]["due_on"] == (date.fromisoformat(opened_on) + timedelta(days=1)).isoformat()

    # The plan isn't due yet, so it does not block today's advance.
    assert api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"}).status_code == 200


def test_declining_a_plan_template_creates_no_plan(api_client, mock_engine):
    career_id, _ = new_career(api_client)
    _open_offer(api_client, career_id, "coach_extra_session")

    body = api_client.post(f"/careers/{career_id}/social/offers/so_test0001/decline").json()
    assert body["plan"] is None
    assert api_client.get(f"/careers/{career_id}/social/plans").json()["plans"] == []


def test_accepting_an_instant_template_still_carries_a_null_plan(api_client, mock_engine):
    """Regression: the six templates without plan_days_ahead behave exactly
    as before, including the response shape (`plan` is always present, just
    null)."""
    career_id, _ = new_career(api_client)
    _open_offer(api_client, career_id, "team_console_night", relationship_id="team")

    body = api_client.post(f"/careers/{career_id}/social/offers/so_test0001/accept").json()
    assert body["plan"] is None
    assert api_client.get(f"/careers/{career_id}/social/plans").json()["plans"] == []


# --- the due day (router + advance gate) ------------------------------------

def _due_plan(api_client, career_id, status="pending"):
    """A plan due today, inserted directly (mirrors _open_offer above)."""
    today = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["current_date"]
    conn = sqlite3.connect(config.DB_PATH)
    conn.execute(
        "INSERT INTO social_plan (career_id, plan_id, offer_id, template_id, "
        "relationship_id, due_on, status) VALUES (?, 'spl_test0001', 'so_test0001', "
        "'coach_extra_session', 'coach', ?, ?)",
        (career_id, today, status),
    )
    conn.commit()
    conn.close()
    return today


def test_a_due_plan_blocks_advance(api_client, mock_engine):
    career_id, _ = new_career(api_client)
    _due_plan(api_client, career_id)

    resp = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})
    assert resp.status_code == 409
    assert resp.json()["code"] == "social_plan_pending"
    assert "spl_test0001" in resp.json()["message"]


def test_a_plan_due_tomorrow_stops_next_event_when_its_day_arrives(api_client, mock_engine):
    """Unlike the door gate above (already-due, blocks immediately), a plan
    due a day out doesn't block today — the day loop should walk forward
    and stop exactly when its due day arrives, the same way an arriving
    social offer does."""
    from datetime import date, timedelta

    career_id, _ = new_career(api_client)
    today = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["current_date"]
    tomorrow = (date.fromisoformat(today) + timedelta(days=1)).isoformat()
    conn = sqlite3.connect(config.DB_PATH)
    conn.execute(
        "INSERT INTO social_plan (career_id, plan_id, offer_id, template_id, "
        "relationship_id, due_on, status) VALUES (?, 'spl_test0001', 'so_test0001', "
        "'coach_extra_session', 'coach', ?, 'pending')",
        (career_id, tomorrow),
    )
    conn.commit()
    conn.close()

    body = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"}).json()
    assert body["stop_reason"] == "social_plan_due"
    assert body["stopped_on"] == tomorrow
    stopper = next(e for e in body["stopped_events"] if e["kind"] == "social_plan_due")
    assert stopper["ref_id"] == "spl_test0001"


def test_attending_spends_costs_and_applies_the_withheld_effects(api_client, mock_engine):
    career_id, _ = new_career(api_client)
    _due_plan(api_client, career_id)
    budget_before = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["day_budget"]

    resp = api_client.post(f"/careers/{career_id}/social/plans/spl_test0001/attend")
    assert resp.status_code == 200, resp.json()
    body = resp.json()

    assert body["plan"]["status"] == "done"
    costs = social.template("coach_extra_session")["costs"]
    for resource, amount in costs.items():
        assert body["career_state"]["day_budget"][resource] == budget_before[resource] - amount
    assert len(body["attribute_changes"]) == 1  # attribute:shooting

    # Resolved: the day can advance again.
    assert api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"}).status_code == 200


def test_attending_without_the_budget_changes_nothing(api_client, mock_engine):
    career_id, _ = new_career(api_client)
    _due_plan(api_client, career_id)

    conn = sqlite3.connect(config.DB_PATH)
    conn.execute("UPDATE day_budget SET remaining = 0 WHERE career_id = ?", (career_id,))
    conn.commit()
    conn.close()

    resp = api_client.post(f"/careers/{career_id}/social/plans/spl_test0001/attend")
    assert resp.status_code == 409
    assert resp.json()["code"] == "insufficient_budget"
    assert api_client.get(f"/careers/{career_id}/social/plans").json()["plans"][0]["status"] == "pending"


def test_skipping_misses_the_plan_with_a_bigger_penalty_than_declining(api_client, mock_engine):
    career_id, _ = new_career(api_client)
    _due_plan(api_client, career_id)
    before = api_client.get(f"/careers/{career_id}/relationships").json()["relationships"]
    before_score = next(r["score"] for r in before if r["relationship_id"] == "coach")

    resp = api_client.post(f"/careers/{career_id}/social/plans/spl_test0001/skip")
    assert resp.status_code == 200, resp.json()
    body = resp.json()

    assert body["plan"]["status"] == "missed"
    change = body["relationship_changes"][0]
    assert change["relationship_id"] == "coach"
    assert change["after"] == max(0, before_score + social.MISSED_PLAN_RELATIONSHIP_DELTA)
    decline_delta = social.template("coach_extra_session")["decline"]["relationship_delta"]
    assert social.MISSED_PLAN_RELATIONSHIP_DELTA < decline_delta

    # Resolved: the day can advance again.
    assert api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"}).status_code == 200


def test_a_resolved_plan_cannot_be_resolved_twice(api_client, mock_engine):
    career_id, _ = new_career(api_client)
    _due_plan(api_client, career_id)
    assert api_client.post(f"/careers/{career_id}/social/plans/spl_test0001/attend").status_code == 200

    second = api_client.post(f"/careers/{career_id}/social/plans/spl_test0001/skip")
    assert second.status_code == 409
    assert second.json()["code"] == "social_plan_not_open"


def test_an_unknown_plan_is_a_404(api_client, mock_engine):
    career_id, _ = new_career(api_client)
    resp = api_client.post(f"/careers/{career_id}/social/plans/spl_nope/attend")
    assert resp.status_code == 404
    assert resp.json()["code"] == "social_plan_not_found"


def test_r4_style_listing_is_empty_on_a_fresh_career(api_client):
    career_id, _ = new_career(api_client)
    assert api_client.get(f"/careers/{career_id}/social/plans").json() == {"plans": []}
