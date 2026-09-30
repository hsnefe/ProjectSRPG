"""§5.4 R4-R6, §6.3 D53 - the social offer pool, its validator, and
domain/social.py's generation and resolution."""
import datetime as _dt

import pytest

from api import config
from content import validate_social_offers
from content.social_offers import SOCIAL_OFFERS
from domain import social


@pytest.fixture
def offer_career(db_conn, career_id, player_id):
    """A career with all six relationships at their §4 starting scores —
    the state maybe_generate() reads to decide what is eligible."""
    from worlddata.relationships import STARTING_SCORES

    for relationship_id, score in STARTING_SCORES.items():
        db_conn.execute(
            "INSERT INTO relationship "
            "(career_id, relationship_id, kind, category, score, person_name, contact_name) "
            "VALUES (?, ?, ?, ?, ?, 'Ad', 'Kısa ad')",
            (career_id, relationship_id, relationship_id, relationship_id, score),
        )
    db_conn.commit()
    return career_id


def always_offer(monkeypatch):
    """Takes the daily dice out of the equation. Every test below is about
    WHICH offer arrives and what happens to it, not about how often."""
    monkeypatch.setattr(config, "SOCIAL_OFFER_DAILY_CHANCE", 1.0)


# --- the pool -------------------------------------------------------------

def test_the_shipped_pool_validates():
    validate_social_offers(SOCIAL_OFFERS)  # would already have raised at import


def test_every_relationship_has_at_least_one_template():
    """Otherwise has_pending_request could never be true for some cards —
    a mechanic silently unreachable for part of its own surface."""
    covered = {t["relationship_id"] for t in SOCIAL_OFFERS}
    assert covered == set(config.RELATIONSHIP_KINDS)


def test_every_template_offers_a_way_out():
    """INV-40's content-side half: the answer is mandatory, so a template
    with no decline branch would be an offer the player cannot refuse."""
    for template in SOCIAL_OFFERS:
        assert "decline" in template
        assert "costs" not in template["decline"]


@pytest.mark.parametrize("broken", [
    {"relationship_id": "coach"},                                    # no template_id
    {"template_id": "x", "relationship_id": "agent"},                # unknown relationship
    {"template_id": "x", "relationship_id": "coach", "title": ""},   # empty title
])
def test_validator_rejects_malformed_templates(broken):
    with pytest.raises(ValueError):
        validate_social_offers([broken])


def _valid(**overrides):
    return {**{
        "template_id": "t", "relationship_id": "coach",
        "weight": 1, "cooldown_days": 7, "min_score": 0, "max_score": 100,
        "title": "T", "body": "B", "accept_label": "E", "decline_label": "H",
        "accept": {"relationship_delta": 1, "effects": {}},
        "decline": {"relationship_delta": -1, "effects": {}},
    }, **overrides}


def test_validator_accepts_a_minimal_template():
    validate_social_offers([_valid()])


@pytest.mark.parametrize("overrides", [
    {"weight": 0},
    {"cooldown_days": -1},
    {"min_score": 60, "max_score": 40},
    {"accept": {"relationship_delta": 1, "effects": {"nonsense:key": 1}}},
    {"accept": {"relationship_delta": True, "effects": {}}},  # bool reads as +1
    {"costs": {"money": 100}},                                 # money is an effect, not a cost
    {"requires": {"speed": 3}},                                # not an attribute
])
def test_validator_rejects_bad_fields(overrides):
    with pytest.raises(ValueError):
        validate_social_offers([_valid(**overrides)])


# --- generation -----------------------------------------------------------

def test_a_quiet_day_produces_nothing(db_conn, offer_career, monkeypatch):
    monkeypatch.setattr(config, "SOCIAL_OFFER_DAILY_CHANCE", 0.0)
    assert social.maybe_generate(db_conn, offer_career, "2026-08-01", 42) is None
    assert social.list_open(db_conn, offer_career) == []


def test_a_generated_offer_carries_its_authored_text(db_conn, offer_career, monkeypatch):
    always_offer(monkeypatch)
    offer = social.maybe_generate(db_conn, offer_career, "2026-08-01", 42)

    assert offer["offer_id"].startswith("so_")
    assert offer["status"] == "open"
    assert offer["opened_on"] == "2026-08-01"
    assert offer["title"] and offer["body"]
    assert offer["accept_label"] and offer["decline_label"]
    # The payoff is never served (catalog/dialogue.public_catalog()'s split).
    assert "accept" not in offer and "relationship_delta" not in offer


def test_generation_is_deterministic_from_the_seed(db_conn, career_id, player_id, monkeypatch):
    """INV-7 extended to offers: the same career replayed to the same date
    is made the same offer. Two independent databases, same seed."""
    always_offer(monkeypatch)
    from db.connection import get_connection
    from db.migrate import apply_migrations
    from worlddata.relationships import STARTING_SCORES

    picks = []
    for _ in range(2):
        conn = get_connection(":memory:")
        apply_migrations(conn)
        conn.execute(
            "INSERT INTO career (career_id, created_at, seed, schema_version) "
            "VALUES ('c', '2026-01-01T00:00:00+03:00', 7, 1)"
        )
        conn.execute(
            "INSERT INTO player (career_id, player_id, name, position, birth_date, team_id, is_user) "
            "VALUES ('c', 'p_user', 'E', 'Orta saha', '2004-08-19', 't_ykz', 1)"
        )
        for relationship_id, score in STARTING_SCORES.items():
            conn.execute(
                "INSERT INTO relationship "
                "(career_id, relationship_id, kind, category, score, person_name, contact_name) "
                "VALUES ('c', ?, ?, ?, ?, 'Ad', 'Kısa ad')",
                (relationship_id, relationship_id, relationship_id, score),
            )
        picks.append(social.maybe_generate(conn, "c", "2026-09-12", 7)["template_id"])
        conn.close()

    assert picks[0] == picks[1]


def test_at_most_one_offer_is_open_at_a_time(db_conn, offer_career, monkeypatch):
    """INV-39 - not a queue. A week of ignored offers must not be able to
    land at once."""
    always_offer(monkeypatch)
    first = social.maybe_generate(db_conn, offer_career, "2026-08-01", 42)
    assert first is not None

    assert social.maybe_generate(db_conn, offer_career, "2026-08-02", 42) is None
    assert len(social.list_open(db_conn, offer_career)) == 1

    social.resolve(db_conn, offer_career, first["offer_id"], "decline", "2026-08-02")
    assert social.maybe_generate(db_conn, offer_career, "2026-08-03", 42) is not None


def test_a_template_respects_its_own_cooldown(db_conn, offer_career, monkeypatch):
    """The same conversation must not repeat two days running, even though
    resolving the first one unblocks generation immediately."""
    always_offer(monkeypatch)
    date = _dt.date(2026, 8, 1)
    seen = []
    for _ in range(6):
        offer = social.maybe_generate(db_conn, offer_career, date.isoformat(), 42)
        if offer:
            seen.append((date, offer["template_id"]))
            social.resolve(db_conn, offer_career, offer["offer_id"], "decline", date.isoformat())
        date += _dt.timedelta(days=1)

    by_template = {}
    for when, template_id in seen:
        cooldown = social.template(template_id)["cooldown_days"]
        if template_id in by_template:
            assert (when - by_template[template_id]).days >= cooldown
        by_template[template_id] = when


def test_a_relationship_outside_the_score_window_is_skipped(db_conn, offer_career, monkeypatch):
    """team_dinner wants a score of at least 20. At 0 the squad is not
    inviting anyone to dinner."""
    always_offer(monkeypatch)
    db_conn.execute("UPDATE relationship SET score = 0 WHERE career_id = ?", (offer_career,))

    for day in range(1, 15):
        offer = social.maybe_generate(db_conn, offer_career, f"2026-08-{day:02d}", 42)
        if offer is None:
            continue
        assert social.template(offer["template_id"])["min_score"] == 0
        social.resolve(db_conn, offer_career, offer["offer_id"], "decline", f"2026-08-{day:02d}")


def test_an_unmet_requirement_keeps_the_offer_from_being_made(
    db_conn, offer_career, player_id, monkeypatch
):
    """D42 as eligibility, not enforcement: an offer the player could only
    decline is a notification, not an offer. media_interview_request wants
    empathy level 3, and a player with none is never asked."""
    always_offer(monkeypatch)
    db_conn.execute(
        "INSERT INTO player_attribute (career_id, player_id, attribute_key, value) "
        "VALUES (?, ?, 'empathy', 5)",  # level 0
        (offer_career, player_id),
    )

    for day in range(1, 25):
        offer = social.maybe_generate(db_conn, offer_career, f"2026-08-{day:02d}", 42)
        if offer is None:
            continue
        assert offer["template_id"] != "media_interview_request"
        social.resolve(db_conn, offer_career, offer["offer_id"], "decline", f"2026-08-{day:02d}")


# --- resolution -----------------------------------------------------------

@pytest.mark.parametrize("decision,expected", [("accept", "accepted"), ("decline", "declined")])
def test_resolve_closes_the_offer(db_conn, offer_career, monkeypatch, decision, expected):
    always_offer(monkeypatch)
    offer = social.maybe_generate(db_conn, offer_career, "2026-08-01", 42)

    resolved = social.resolve(db_conn, offer_career, offer["offer_id"], decision, "2026-08-01")
    assert resolved["status"] == expected
    assert resolved["resolved_on"] == "2026-08-01"
    assert social.list_open(db_conn, offer_career) == []


def test_pending_by_relationship_answers_for_all_six_at_once(
    db_conn, offer_career, monkeypatch
):
    always_offer(monkeypatch)
    assert social.pending_by_relationship(db_conn, offer_career) == set()

    offer = social.maybe_generate(db_conn, offer_career, "2026-08-01", 42)
    assert social.pending_by_relationship(db_conn, offer_career) == {offer["relationship_id"]}

    social.resolve(db_conn, offer_career, offer["offer_id"], "accept", "2026-08-01")
    assert social.pending_by_relationship(db_conn, offer_career) == set()


def test_an_offer_from_a_since_deleted_template_still_reads(db_conn, offer_career):
    """A stored row points at authored content that may have been edited
    away. That must degrade to empty text, not raise inside the day loop."""
    db_conn.execute(
        "INSERT INTO social_offer (career_id, offer_id, template_id, relationship_id, "
        "opened_on, status, resolved_on) VALUES (?, 'so_gone', 'no_such_template', "
        "'coach', '2026-08-01', 'open', NULL)",
        (offer_career,),
    )
    offer = social.get(db_conn, offer_career, "so_gone")
    assert offer["title"] == ""
    assert offer["relationship_id"] == "coach"


# --- the day loop (§6.3) --------------------------------------------------

@pytest.fixture
def offers_on(monkeypatch):
    """Turns the conftest-wide off switch back on for the router tests
    below, so an offer lands on the first advanced day."""
    monkeypatch.setattr(config, "SOCIAL_OFFER_DAILY_CHANCE", 1.0)


def _first_offer(api_client, career_id):
    day = api_client.get(f"/careers/{career_id}/day").json()
    events = [e for e in day["events"] if e["kind"] == "social_offer"]
    return events[0] if events else None


def test_an_arriving_offer_stops_the_advance(api_client, mock_engine, offers_on):
    from tests.conftest import new_career

    career_id, _ = new_career(api_client)
    body = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"}).json()

    assert body["stop_reason"] == "social_offer"
    stopper = next(e for e in body["stopped_events"] if e["kind"] == "social_offer")
    assert stopper["ref_id"].startswith("so_")
    assert stopper["opened_on"] == body["stopped_on"]


def test_time_cannot_move_while_an_offer_waits(api_client, mock_engine, offers_on):
    """D53 - the answer is mandatory, and the refusal names the offer so the
    caller's correct reaction is to open it rather than retry."""
    from tests.conftest import new_career

    career_id, _ = new_career(api_client)
    first = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"}).json()
    offer_id = next(e["ref_id"] for e in first["stopped_events"] if e["kind"] == "social_offer")

    blocked = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})
    assert blocked.status_code == 409
    assert blocked.json()["code"] == "social_offer_pending"
    assert offer_id in blocked.json()["message"]

    frozen = api_client.get(f"/careers/{career_id}/day").json()
    assert frozen["career_state"]["current_date"] == first["stopped_on"]


def test_t1_keeps_reporting_an_open_offer(api_client, mock_engine, offers_on):
    """The stop is edge-triggered but the STATE is not: the player should
    keep seeing the offer on the hub for as long as it is unanswered."""
    from tests.conftest import new_career

    career_id, _ = new_career(api_client)
    api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"})
    assert _first_offer(api_client, career_id) is not None


# --- R4-R6 (§5.4) ---------------------------------------------------------

def _open_offer(api_client, mock_engine=None):
    """A career sitting on one open offer, plus that offer's body."""
    from tests.conftest import new_career

    career_id, _ = new_career(api_client)
    advanced = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"}).json()
    assert advanced["stop_reason"] == "social_offer"

    offers = api_client.get(f"/careers/{career_id}/social/offers").json()["offers"]
    assert len(offers) == 1
    return career_id, offers[0]


def test_r4_serves_the_text_and_the_gate_but_never_the_payoff(
    api_client, mock_engine, offers_on
):
    career_id, offer = _open_offer(api_client)

    assert offer["offer_id"].startswith("so_")
    assert offer["status"] == "open"
    assert offer["title"] and offer["body"]
    assert offer["accept_label"] and offer["decline_label"]
    assert offer["relationship"]["relationship_id"] == offer["relationship_id"]
    assert "person_name" in offer["relationship"]
    # The gate is served (D42 — FE greys the choice out); the reward is not.
    assert "requires" in offer and "costs" in offer
    assert "accept" not in offer and "decline" not in offer


def test_accepting_moves_the_relationship_and_frees_the_calendar(
    api_client, mock_engine, offers_on
):
    career_id, offer = _open_offer(api_client)
    before = api_client.get(f"/careers/{career_id}/relationships").json()["relationships"]
    before_score = next(
        r["score"] for r in before if r["relationship_id"] == offer["relationship_id"]
    )

    resp = api_client.post(f"/careers/{career_id}/social/offers/{offer['offer_id']}/accept")
    assert resp.status_code == 200, resp.json()
    body = resp.json()

    assert body["offer"]["status"] == "accepted"
    assert len(body["relationship_changes"]) == 1
    change = body["relationship_changes"][0]
    assert change["relationship_id"] == offer["relationship_id"]
    assert change["after"] == before_score + change["delta"]
    assert change["delta"] > 0  # accepting is what the other side wanted

    # THE FREEZE TEST: an answered offer must let time move again.
    resumed = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"})
    assert resumed.status_code == 200
    assert resumed.json()["days_advanced"] >= 1


def test_declining_costs_the_relationship_but_nothing_else(
    api_client, mock_engine, offers_on
):
    career_id, offer = _open_offer(api_client)
    budget_before = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["day_budget"]
    money_before = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["money"]

    body = api_client.post(
        f"/careers/{career_id}/social/offers/{offer['offer_id']}/decline"
    ).json()

    assert body["offer"]["status"] == "declined"
    assert body["relationship_changes"][0]["delta"] < 0
    assert body["ledger_entries"] == []
    assert body["career_state"]["day_budget"] == budget_before
    assert body["career_state"]["money"] == money_before


def test_accepting_spends_the_template_s_costs(api_client, mock_engine, offers_on):
    career_id, offer = _open_offer(api_client)
    before = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["day_budget"]

    body = api_client.post(
        f"/careers/{career_id}/social/offers/{offer['offer_id']}/accept"
    ).json()

    for resource, amount in offer["costs"].items():
        assert body["career_state"]["day_budget"][resource] == before[resource] - amount


def test_declining_works_with_no_budget_and_no_money(api_client, mock_engine, offers_on):
    """INV-40 - the answer is mandatory, so the way out can never fail. A
    player with an empty day and an empty wallet must still be able to clear
    the offer, or a shortfall would wedge the career for good."""
    import sqlite3

    career_id, offer = _open_offer(api_client)
    conn = sqlite3.connect(config.DB_PATH)
    conn.execute("UPDATE day_budget SET remaining = 0 WHERE career_id = ?", (career_id,))
    conn.commit()
    conn.close()

    resp = api_client.post(f"/careers/{career_id}/social/offers/{offer['offer_id']}/decline")
    assert resp.status_code == 200
    assert api_client.post(
        f"/careers/{career_id}/advance", json={"to": "next_day"}
    ).status_code == 200


def test_accepting_without_the_budget_changes_nothing(api_client, mock_engine, offers_on):
    """INV-4/INV-30 - a refused accept leaves the offer open and every
    counter untouched, so the player can still decline it."""
    import sqlite3

    career_id, offer = _open_offer(api_client)
    if not offer["costs"]:
        pytest.skip("this offer is free; the budget path is not exercised by it")

    conn = sqlite3.connect(config.DB_PATH)
    conn.execute("UPDATE day_budget SET remaining = 0 WHERE career_id = ?", (career_id,))
    conn.commit()
    conn.close()
    before = api_client.get(f"/careers/{career_id}/relationships").json()["relationships"]

    resp = api_client.post(f"/careers/{career_id}/social/offers/{offer['offer_id']}/accept")
    assert resp.status_code == 409
    assert resp.json()["code"] == "insufficient_budget"

    after = api_client.get(f"/careers/{career_id}/relationships").json()["relationships"]
    assert after == before
    assert len(api_client.get(f"/careers/{career_id}/social/offers").json()["offers"]) == 1


def test_answering_twice_is_refused(api_client, mock_engine, offers_on):
    career_id, offer = _open_offer(api_client)
    assert api_client.post(
        f"/careers/{career_id}/social/offers/{offer['offer_id']}/accept"
    ).status_code == 200

    second = api_client.post(f"/careers/{career_id}/social/offers/{offer['offer_id']}/decline")
    assert second.status_code == 409
    assert second.json()["code"] == "social_offer_not_open"


def test_an_unknown_offer_is_a_404(api_client, mock_engine, offers_on):
    from tests.conftest import new_career

    career_id, _ = new_career(api_client)
    resp = api_client.post(f"/careers/{career_id}/social/offers/so_nope/accept")
    assert resp.status_code == 404
    assert resp.json()["code"] == "social_offer_not_found"


def test_r1_flags_exactly_the_card_with_an_offer_waiting(api_client, mock_engine, offers_on):
    career_id, offer = _open_offer(api_client)
    cards = api_client.get(f"/careers/{career_id}/relationships").json()["relationships"]

    flagged = [c["relationship_id"] for c in cards if c["has_pending_request"]]
    assert flagged == [offer["relationship_id"]]

    api_client.post(f"/careers/{career_id}/social/offers/{offer['offer_id']}/decline")
    cards = api_client.get(f"/careers/{career_id}/relationships").json()["relationships"]
    assert not any(c["has_pending_request"] for c in cards)


def test_r4_is_empty_on_a_career_that_has_never_been_offered_anything(api_client):
    from tests.conftest import new_career

    career_id, _ = new_career(api_client)
    assert api_client.get(f"/careers/{career_id}/social/offers").json() == {"offers": []}
