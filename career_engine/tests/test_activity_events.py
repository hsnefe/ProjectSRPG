"""§13.4 - activity events: T2's roll, T5, T6, and D76's expiry."""
import pytest

from api import config
from tests.conftest import create_career, grant_money, set_attribute


@pytest.fixture
def created_career(api_client):
    return create_career(api_client)


@pytest.fixture
def always_event(monkeypatch):
    """The roll is a random per-action event, so it is off for the rest of the
    suite by luck and on here by force — tests/test_social_offers.py::always_offer's
    pattern. Only a constant moves; the code path under test is the real one.
    """
    from catalog.lifestyle import LIFESTYLE_ITEMS

    for item in LIFESTYLE_ITEMS:
        monkeypatch.setitem(item, "event_chance", 1.0)


@pytest.fixture
def force_template(monkeypatch):
    """Narrows the pool to one template without touching the roll itself.

    An activity draws from several templates by weight, so a test that needs
    a SPECIFIC one ("the option that introduces someone") would otherwise be
    asserting the outcome of a weighted pick alongside what it is actually
    about — and would start failing the day a template's weight moved. Only
    the candidate list narrows; the dice, the eligibility check and the
    resolution path are all the real ones.
    """
    def _force(template_id):
        from content.activity_events import template as get_template

        tpl = get_template(template_id)
        assert tpl is not None, template_id
        # domain/activity_events.py binds `for_catalog` at import, so the
        # patch has to land on the domain module's own name, not content's.
        monkeypatch.setattr("domain.activity_events.for_catalog", lambda catalog_id: [tpl])

    return _force


@pytest.fixture
def never_event(monkeypatch):
    from catalog.lifestyle import LIFESTYLE_ITEMS

    for item in LIFESTYLE_ITEMS:
        monkeypatch.setitem(item, "event_chance", 0.0)


def _db():
    from db.connection import get_connection
    return get_connection(config.DB_PATH)


def _do(api_client, career_id, catalog_id="sos-kafe"):
    return api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": catalog_id})


# --- the roll ---------------------------------------------------------------

def test_action_without_an_event_reports_null(api_client, created_career, never_event):
    career_id = created_career["career_id"]
    grant_money(career_id, 1000)
    body = _do(api_client, career_id).json()
    assert body["event"] is None
    # ...and the activity itself still applied in full (INV-3).
    assert body["applied_costs"] == {"time": 60}
    assert body["career_state"]["day_budget"]["time"] == 720 - 60


def test_action_can_spawn_an_event(api_client, created_career, always_event):
    career_id = created_career["career_id"]
    grant_money(career_id, 1000)
    body = _do(api_client, career_id).json()

    event = body["event"]
    assert event is not None
    assert event["event_id"].startswith("ae_")
    assert event["status"] == "open"
    assert event["catalog_id"] == "sos-kafe"
    assert event["title"] and event["body"]

    # D42 - the gate travels so an unaffordable option can be greyed out...
    assert all("requires" in o and "costs" in o for o in event["options"])
    # ...but the payoff never does (R4's split).
    assert all("effects" not in o for o in event["options"])
    assert all("starts_relationship" not in o for o in event["options"])


def test_training_never_spawns_an_event(api_client, created_career, always_event):
    """§13.4 - only lifestyle rows carry event_chance. Nothing is supposed to
    happen to you during a shooting drill."""
    career_id = created_career["career_id"]
    assert _do(api_client, career_id, "sut").json()["event"] is None


def test_only_one_event_is_open_at_a_time(api_client, created_career, always_event):
    """INV-62 - a modal is not a queue (INV-39's twin)."""
    career_id = created_career["career_id"]
    grant_money(career_id, 1000)
    first = _do(api_client, career_id).json()["event"]
    assert first is not None

    second = _do(api_client, career_id, "sos-arkadas").json()["event"]
    assert second is None   # the second action still applied; it just rolled nothing

    assert len(api_client.get(f"/careers/{career_id}/activity-events").json()["events"]) == 1


def test_the_roll_is_deterministic(api_client, always_event):
    """INV-7 - the same career replayed the same way meets the same stranger."""
    ids = []
    for _ in range(2):
        career = create_career(api_client, seed=7171)
        career_id = career["career_id"]
        grant_money(career_id, 1000)
        ids.append(_do(api_client, career_id).json()["event"]["template_id"])
    assert ids[0] == ids[1]


# --- T5 ---------------------------------------------------------------------

def test_list_activity_events_is_empty_without_one(api_client, created_career, never_event):
    resp = api_client.get(f"/careers/{created_career['career_id']}/activity-events")
    assert resp.status_code == 200
    assert resp.json()["events"] == []


def test_list_activity_events_recovers_an_open_one(api_client, created_career, always_event):
    """The reason T5 exists: D76 does not gate the day loop, so a player who
    closed the app must be able to find the event again."""
    career_id = created_career["career_id"]
    grant_money(career_id, 1000)
    opened = _do(api_client, career_id).json()["event"]

    listed = api_client.get(f"/careers/{career_id}/activity-events").json()["events"]
    assert [e["event_id"] for e in listed] == [opened["event_id"]]


# --- T6 ---------------------------------------------------------------------

def _open_event(api_client, career_id, catalog_id="sos-kafe"):
    grant_money(career_id, 1000)
    return _do(api_client, career_id, catalog_id).json()["event"]


def test_choose_applies_the_option(api_client, created_career, always_event, force_template):
    career_id = created_career["career_id"]
    force_template("taraftar-cocuk-forma")
    event = _open_event(api_client, career_id, "sos-taraftar")
    # taraftar-cocuk-forma's ungated option pays the fans.
    option = next(o for o in event["options"] if not o["requires"])

    before_budget = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["day_budget"]
    resp = api_client.post(
        f"/careers/{career_id}/activity-events/{event['event_id']}/choose/{option['option_id']}"
    )
    assert resp.status_code == 200
    body = resp.json()

    assert body["event"]["status"] == "resolved"
    assert body["event"]["chosen_option"] == option["option_id"]
    assert "career_state" in body          # D28/INV-18
    after_budget = body["career_state"]["day_budget"]
    for key, amount in option["costs"].items():
        assert after_budget[key] == before_budget[key] - amount


def test_choose_unknown_option_is_422(api_client, created_career, always_event):
    career_id = created_career["career_id"]
    event = _open_event(api_client, career_id)
    resp = api_client.post(
        f"/careers/{career_id}/activity-events/{event['event_id']}/choose/nope"
    )
    assert resp.status_code == 422


def test_choose_unknown_event_is_404(api_client, created_career):
    resp = api_client.post(
        f"/careers/{created_career['career_id']}/activity-events/ae_missing/choose/x"
    )
    assert resp.status_code == 404
    assert resp.json()["code"] == "activity_event_not_found"


def test_choosing_twice_is_refused(api_client, created_career, always_event, force_template):
    career_id = created_career["career_id"]
    force_template("taraftar-cocuk-forma")
    event = _open_event(api_client, career_id, "sos-taraftar")
    option = next(o for o in event["options"] if not o["requires"])
    path = f"/careers/{career_id}/activity-events/{event['event_id']}/choose/{option['option_id']}"

    assert api_client.post(path).status_code == 200
    again = api_client.post(path)
    assert again.status_code == 409
    assert again.json()["code"] == "activity_event_not_open"


def test_gated_option_is_refused_and_leaves_the_event_open(
    api_client, created_career, always_event, force_template
):
    """INV-30's shape: a rejected choice writes nothing and the player picks
    again rather than losing the moment to a 409."""
    career_id = created_career["career_id"]
    force_template("kafe-taniyan-birisi")
    set_attribute(career_id, "courage", 20.0)   # level 2, under every gate
    event = _open_event(api_client, career_id)
    gated = next((o for o in event["options"] if o["requires"]), None)
    assert gated is not None, "this template should have a gated option"

    before = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["day_budget"]
    resp = api_client.post(
        f"/careers/{career_id}/activity-events/{event['event_id']}/choose/{gated['option_id']}"
    )
    assert resp.status_code == 409
    assert resp.json()["code"] == "requirement_not_met"

    after = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["day_budget"]
    assert after == before
    still_open = api_client.get(f"/careers/{career_id}/activity-events").json()["events"]
    assert [e["event_id"] for e in still_open] == [event["event_id"]]


# --- §13.4 -> §13.2, the one bridge ----------------------------------------

def test_an_option_can_introduce_a_partner(
    api_client, created_career, always_event, force_template
):
    career_id = created_career["career_id"]
    force_template("kafe-taniyan-birisi")
    set_attribute(career_id, "courage", 60.0)   # clears the option's gate
    event = _open_event(api_client, career_id)
    assert event["template_id"] == "kafe-taniyan-birisi"

    resp = api_client.post(
        f"/careers/{career_id}/activity-events/{event['event_id']}/choose/masasina_git"
    )
    assert resp.status_code == 200
    assert resp.json()["relationship_state_changes"] == [
        {"relationship_id": "partner", "before": "absent", "after": "courting"}
    ]

    rels = api_client.get(f"/careers/{career_id}/relationships").json()["relationships"]
    partner = next(r for r in rels if r["relationship_id"] == "partner")
    assert partner["state"] == "courting"


def test_introducing_does_nothing_once_a_partner_exists(
    api_client, created_career, always_event, force_template
):
    """§13.4 - which is what lets the template stay in the pool forever."""
    from domain import relationships

    career_id = created_career["career_id"]
    force_template("kafe-taniyan-birisi")
    set_attribute(career_id, "courage", 60.0)
    conn = _db()
    try:
        relationships.set_state(conn, career_id, "partner", config.STATE_ACTIVE)
        conn.commit()
    finally:
        conn.close()

    event = _open_event(api_client, career_id)
    resp = api_client.post(
        f"/careers/{career_id}/activity-events/{event['event_id']}/choose/masasina_git"
    )
    assert resp.status_code == 200
    assert resp.json()["relationship_state_changes"] == []


# --- D76 / INV-63 -----------------------------------------------------------

def test_advance_is_not_blocked_by_an_open_event(api_client, created_career, always_event):
    """D76 - the difference between an invitation and a moment. A social plan
    stops the day; a cafe conversation does not."""
    career_id = created_career["career_id"]
    event = _open_event(api_client, career_id)

    resp = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})
    assert resp.status_code == 200
    assert resp.json()["days_advanced"] == 1


def test_advancing_expires_an_unanswered_event_without_applying_it(
    api_client, created_career, always_event, force_template
):
    """INV-63 - it goes to `expired` and writes nothing at all."""
    career_id = created_career["career_id"]
    force_template("taraftar-cocuk-forma")
    event = _open_event(api_client, career_id, "sos-taraftar")

    fans_before = next(
        r["score"] for r in api_client.get(f"/careers/{career_id}/relationships").json()["relationships"]
        if r["relationship_id"] == "fans"
    )

    api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})

    assert api_client.get(f"/careers/{career_id}/activity-events").json()["events"] == []
    conn = _db()
    try:
        status = conn.execute(
            "SELECT status FROM activity_event WHERE career_id = ? AND event_id = ?",
            (career_id, event["event_id"]),
        ).fetchone()["status"]
    finally:
        conn.close()
    assert status == "expired"

    fans_after = next(
        r["score"] for r in api_client.get(f"/careers/{career_id}/relationships").json()["relationships"]
        if r["relationship_id"] == "fans"
    )
    assert fans_after == fans_before   # neither branch was applied

    # ...and it cannot be answered afterwards.
    resp = api_client.post(
        f"/careers/{career_id}/activity-events/{event['event_id']}/choose/imza_ver"
    )
    assert resp.status_code == 409
    assert resp.json()["code"] == "activity_event_not_open"
