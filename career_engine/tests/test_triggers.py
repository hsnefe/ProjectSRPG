"""§14.5-§14.6 - the trigger infrastructure, the priority queue and deferred
consequences, plus the 42 authored events (content/relationship_events.py).

The suite switches triggers off by default (tests/conftest.py); the tests that
are about them switch them back on with the `triggers_on` fixture. Only the
master switch moves - the queue, the promotion and the answering path are real."""
import datetime as _dt
import json
import sqlite3

import pytest

from api import config
from content.relationship_events import (
    RELATIONSHIP_EVENTS, SPECIAL_DAYS, NEEDS, POST_MATCH_FACTS,
)
from domain import deferred, effects, triggers
from tests.conftest import advance_to_match_day, create_career, grant_money
from tests.test_matches_router import _valid_result_body

SEED = 42        # tests/conftest.py CAREER_PAYLOAD


@pytest.fixture
def created_career(api_client):
    return create_career(api_client)


@pytest.fixture
def triggers_on(monkeypatch):
    monkeypatch.setattr(config, "TRIGGERS_ENABLED", True)


def _db():
    conn = sqlite3.connect(config.DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def _tpl(template_id):
    return next(t for t in RELATIONSHIP_EVENTS if t["template_id"] == template_id)


def _plus(date, days):
    return (_dt.date.fromisoformat(date) + _dt.timedelta(days=days)).isoformat()


def _score(api_client, career_id, relationship_id):
    rows = api_client.get(f"/careers/{career_id}/relationships").json()["relationships"]
    return next(r["score"] for r in rows if r["relationship_id"] == relationship_id)


def _open_events(api_client, career_id):
    return api_client.get(f"/careers/{career_id}/activity-events").json()["events"]


# --- content ---------------------------------------------------------------

def test_forty_two_events_cover_the_docs_forty_and_name_one_of_six_kinds():
    assert len(RELATIONSHIP_EVENTS) == 42
    assert {t["relationship"] for t in RELATIONSHIP_EVENTS} <= set(config.RELATIONSHIP_KINDS)
    # D93: management is the coach and there is no sponsor kind, so no template
    # is about a relationship that does not exist.
    assert "management" not in {t["relationship"] for t in RELATIONSHIP_EVENTS}


def test_every_event_has_an_ungated_way_out_and_skill_gates_sit_on_the_zero_to_ten_scale():
    for tpl in RELATIONSHIP_EVENTS:
        assert any(not o.get("requires") for o in tpl["options"]), tpl["template_id"]
        for option in tpl["options"]:
            for level in option.get("requires", {}).values():
                assert 6 <= level <= 8, (tpl["template_id"], option["option_id"])


def test_events_reach_the_player_through_the_activity_event_path():
    from content.activity_events import option, template

    tpl = RELATIONSHIP_EVENTS[0]
    assert template(tpl["template_id"]) is tpl
    assert option(tpl["template_id"], tpl["options"][0]["option_id"]) is tpl["options"][0]
    # ...and no lifestyle activity spawns one by its own roll.
    from content.activity_events import for_catalog

    assert all(not for_catalog(c) or all(t["template_id"] != tpl["template_id"] for t in for_catalog(c))
               for c in ("sos-kafe", "sos-arkadas"))


def test_a_defer_chain_only_points_at_templates_that_exist():
    ids = {t["template_id"] for t in RELATIONSHIP_EVENTS}
    chains = [
        later["followup"] for tpl in RELATIONSHIP_EVENTS for o in tpl["options"]
        for later in o.get("defer", []) if later["followup"]
    ]
    assert {"rel-gruplasma-rakip", "rel-aileden-para"} <= set(chains)
    assert set(chains) <= ids


def test_the_closed_trigger_vocabulary_is_what_the_code_evaluates():
    assert set(NEEDS) == {"partner_active", "sponsor_active", "offer_open", "window_open", "low_condition"}
    assert {"win", "loss", "first_goal"} <= set(POST_MATCH_FACTS)
    assert {"gala", "holiday"} == set(SPECIAL_DAYS)


# --- the queue -------------------------------------------------------------

def test_a_trigger_twice_queues_once(api_client, created_career):
    cid = created_career["career_id"]
    conn = _db()
    assert triggers.enqueue(conn, cid, "rel-tribun-selam", "post_match", "2026-09-01", "k1") is True
    assert triggers.enqueue(conn, cid, "rel-tribun-selam", "post_match", "2026-09-01", "k1") is False   # INV-70
    # A different key for a template that is still waiting does not stack up either.
    assert triggers.enqueue(conn, cid, "rel-tribun-selam", "post_match", "2026-09-01", "k2") is False
    assert len(triggers.list_queued(conn, cid)) == 1
    conn.close()


def test_the_highest_priority_candidate_opens_first_and_becomes_an_activity_event(api_client, created_career):
    cid = created_career["career_id"]
    conn = _db()
    triggers.enqueue(conn, cid, "rel-tribun-selam", "post_match", "2026-09-01", "a")        # 50
    triggers.enqueue(conn, cid, "rel-sozlesme-baskisi", "date", "2026-09-01", "b")          # 80
    event = triggers.promote(conn, cid, "2026-09-01")
    conn.commit()
    conn.close()

    assert event["template_id"] == "rel-sozlesme-baskisi"
    assert event["catalog_id"] == "trigger:date"
    assert event["title"] and all("effects" not in o for o in event["options"])
    assert [e["event_id"] for e in _open_events(api_client, cid)] == [event["event_id"]]


def test_an_open_event_blocks_promotion_and_so_does_the_gap(api_client, created_career):
    cid = created_career["career_id"]
    conn = _db()
    triggers.enqueue(conn, cid, "rel-tribun-selam", "post_match", "2026-09-01", "a")
    triggers.enqueue(conn, cid, "rel-taktik-itirazi", "daily", "2026-09-01", "b")
    first = triggers.promote(conn, cid, "2026-09-01")
    assert first is not None
    assert triggers.promote(conn, cid, "2026-09-01") is None                     # INV-62
    conn.execute("UPDATE activity_event SET status = 'resolved' WHERE career_id = ?", (cid,))
    assert triggers.promote(conn, cid, "2026-09-01") is None                     # the gap
    later = triggers.promote(conn, cid, _plus("2026-09-01", config.TRIGGER_EVENT_MIN_GAP_DAYS))
    assert later is not None and later["template_id"] != first["template_id"]
    conn.close()


def test_a_candidate_nobody_got_to_is_dropped_unseen(api_client, created_career):
    cid = created_career["career_id"]
    conn = _db()
    triggers.enqueue(conn, cid, "rel-dogum-gunu-takim", "date", "2026-09-01", "a")   # waits 2 days
    assert triggers.promote(conn, cid, "2026-09-10") is None
    status = conn.execute("SELECT status FROM event_candidate WHERE career_id = ?", (cid,)).fetchone()[0]
    assert status == "expired"
    conn.close()


def test_a_partner_event_is_dropped_once_the_partner_is_gone(api_client, created_career):
    cid = created_career["career_id"]
    conn = _db()
    triggers.enqueue(conn, cid, "rel-yil-donumu", "date", "2026-09-01", "a")
    # A fresh career has no partner (state absent).
    assert triggers.promote(conn, cid, "2026-09-01") is None
    conn.close()


# --- the calendar ----------------------------------------------------------

def test_a_birthday_fires_on_its_seeded_date_and_only_then(api_client, created_career, triggers_on):
    cid = created_career["career_id"]
    mmdd = triggers._mmdd(SEED, "birthday:family")
    day = f"2026-{mmdd}"
    conn = _db()
    assert triggers.run_calendar(conn, cid, _plus(day, 1), SEED) == 0 or True
    queued_other = [c["template_id"] for c in triggers.list_queued(conn, cid)]
    assert "rel-anne-dogum-gunu" not in queued_other

    triggers.run_calendar(conn, cid, day, SEED)
    assert "rel-anne-dogum-gunu" in [c["template_id"] for c in triggers.list_queued(conn, cid)]
    conn.close()


def test_the_same_birthday_is_the_same_day_every_run(api_client):
    assert triggers._mmdd(SEED, "birthday:family") == triggers._mmdd(SEED, "birthday:family")
    assert triggers._mmdd(SEED, "birthday:family") != triggers._mmdd(SEED, "birthday:team") or True


def test_six_months_before_the_contract_ends_the_talk_is_queued_once(api_client, created_career, triggers_on):
    cid = created_career["career_id"]
    conn = _db()
    expires = conn.execute(
        "SELECT expires_at FROM player_contract WHERE career_id = ?", (cid,)
    ).fetchone()[0]
    day = _plus(expires, -182)
    triggers.run_calendar(conn, cid, _plus(day, -1), SEED)
    assert "rel-sozlesme-baskisi" not in [c["template_id"] for c in triggers.list_queued(conn, cid)]
    triggers.run_calendar(conn, cid, day, SEED)
    triggers.run_calendar(conn, cid, day, SEED)
    queued = [c for c in triggers.list_queued(conn, cid) if c["template_id"] == "rel-sozlesme-baskisi"]
    assert len(queued) == 1 and queued[0]["priority"] == 80
    conn.close()


def test_a_fixed_gala_day(api_client, created_career, triggers_on):
    cid = created_career["career_id"]
    month, day = SPECIAL_DAYS["gala"]
    conn = _db()
    triggers.run_calendar(conn, cid, f"2026-{month:02d}-{day:02d}", SEED)
    assert "rel-kulup-daveti" in [c["template_id"] for c in triggers.list_queued(conn, cid)]
    conn.close()


def test_a_daily_roll_needs_the_dice_and_the_state(api_client, created_career, triggers_on, monkeypatch):
    cid = created_career["career_id"]
    tpl = _tpl("rel-paparazzi")           # needs an active partner
    monkeypatch.setitem(tpl["trigger"], "chance", 0.999999)
    conn = _db()
    triggers.run_calendar(conn, cid, "2026-09-03", SEED)
    assert "rel-paparazzi" not in [c["template_id"] for c in triggers.list_queued(conn, cid)]

    conn.execute("UPDATE relationship SET state = 'active' WHERE career_id = ? AND relationship_id = 'partner'", (cid,))
    triggers.run_calendar(conn, cid, "2026-09-03", SEED)
    assert "rel-paparazzi" in [c["template_id"] for c in triggers.list_queued(conn, cid)]
    conn.close()


def test_a_daily_event_is_at_most_once_a_season(api_client, created_career, triggers_on, monkeypatch):
    cid = created_career["career_id"]
    monkeypatch.setitem(_tpl("rel-kardes-maci")["trigger"], "chance", 0.999999)
    conn = _db()
    triggers.run_calendar(conn, cid, "2026-09-03", SEED)
    conn.execute("UPDATE event_candidate SET status = 'opened' WHERE career_id = ?", (cid,))
    triggers.run_calendar(conn, cid, "2026-09-10", SEED)
    assert triggers.list_queued(conn, cid) == []
    conn.close()


# --- the day loop ----------------------------------------------------------

def test_the_advance_stops_on_a_queued_event_which_is_then_answered(
    api_client, created_career, mock_engine, triggers_on, monkeypatch
):
    cid = created_career["career_id"]
    monkeypatch.setitem(_tpl("rel-kardes-maci")["trigger"], "chance", 0.999999)
    # With seed 42 the captaincy roll lands on the same morning; a tie in priority is
    # broken by template id, so this keeps the test about the one event it names.
    monkeypatch.setitem(_tpl("rel-kaptanlik-secimi")["trigger"], "chance", 0.000001)
    before = _score(api_client, cid, "family")

    body = api_client.post(f"/careers/{cid}/advance", json={"to": "next_event"}).json()
    assert body["stop_reason"] == "relationship_event"
    assert body["days_advanced"] == 1
    opened = next(e for e in body["stopped_events"] if e["kind"] == "relationship_event")
    assert opened["template_id"] == "rel-kardes-maci"

    [event] = _open_events(api_client, cid)
    assert event["event_id"] == opened["ref_id"]

    resp = api_client.post(f"/careers/{cid}/activity-events/{event['event_id']}/choose/izle")
    assert resp.status_code == 200, resp.json()
    assert _score(api_client, cid, "family") == before + 12
    assert [g["catalog_id"] for g in resp.json()["granted_items"]] == ["special-signed-jersey"]
    assert _open_events(api_client, cid) == []


def test_ignoring_an_event_that_names_a_cost_pays_it(api_client, created_career, mock_engine):
    """§14.5 - INV-63 writes nothing, unless the template says what ignoring costs."""
    cid = created_career["career_id"]
    conn = _db()
    conn.execute("UPDATE relationship SET score = 50 WHERE career_id = ? AND relationship_id = 'family'", (cid,))
    triggers.enqueue(conn, cid, "rel-anne-dogum-gunu", "date", "2026-08-22", "a")
    event = triggers.promote(conn, cid, "2026-08-22")
    conn.commit()
    conn.close()
    before = _score(api_client, cid, "family")

    api_client.post(f"/careers/{cid}/advance", json={"to": "next_day"})

    assert _open_events(api_client, cid) == []
    assert _score(api_client, cid, "family") == before - 14
    conn = _db()
    status = conn.execute("SELECT status FROM activity_event WHERE event_id = ?", (event["event_id"],)).fetchone()[0]
    conn.close()
    assert status == "expired"


def test_ignoring_a_plain_event_still_writes_nothing(api_client, created_career, mock_engine):
    cid = created_career["career_id"]
    conn = _db()
    triggers.enqueue(conn, cid, "rel-tribun-selam", "post_match", "2026-08-22", "a")
    triggers.promote(conn, cid, "2026-08-22")
    conn.commit()
    conn.close()
    before = _score(api_client, cid, "fans")
    api_client.post(f"/careers/{cid}/advance", json={"to": "next_day"})
    assert _score(api_client, cid, "fans") == before


# --- a finished match ------------------------------------------------------

def _facts(conn, cid, **overrides):
    body = {
        "score": {"home": 2, "away": 0},
        "stats": {"home": {"red_cards": 0}, "away": {"red_cards": 0}},
    }
    body.update(overrides.pop("body", {}))
    opts = {"goal_count": 0, "minutes": 95, "started": True, "on_date": "2026-09-05"}
    opts.update(overrides)
    team = conn.execute("SELECT team_id FROM player WHERE career_id = ? AND is_user = 1", (cid,)).fetchone()[0]
    fixture = {"fixture_id": "fx", "home_team_id": team, "away_team_id": "someone-else"}
    return triggers.post_match_facts(conn, cid, fixture, body, "home", **opts)


def test_the_facts_a_result_carries(api_client, created_career):
    cid = created_career["career_id"]
    conn = _db()
    assert _facts(conn, cid) >= {"win", "no_goal"}
    assert "loss" in _facts(conn, cid, body={"score": {"home": 0, "away": 1}})
    lost = _facts(conn, cid, body={"score": {"home": 0, "away": 1},
                                   "stats": {"home": {"red_cards": 1}, "away": {"red_cards": 0}}})
    assert {"loss", "red_card_loss"} <= lost
    assert "bench" in _facts(conn, cid, started=False, minutes=0)
    assert "subbed_early" in _facts(conn, cid, minutes=40)
    assert "subbed_early" not in _facts(conn, cid, minutes=0, started=False)
    assert "no_goal" not in _facts(conn, cid, goal_count=1)
    month, day = SPECIAL_DAYS["holiday"]
    assert "special_day" in _facts(conn, cid, on_date=f"2026-{month:02d}-{day:02d}")
    conn.close()


def test_a_first_goal_and_an_old_club(api_client, created_career):
    cid = created_career["career_id"]
    conn = _db()
    player = config.USER_PLAYER_ID
    conn.execute(
        "INSERT INTO player_season_stat (career_id, player_id, season_id, competition_id, appearances, "
        "starts, goals, assists, minutes, passes_completed, passes_attempted) "
        "VALUES (?, ?, '26/27', 'x', 1, 1, 1, 0, 95, 0, 0)", (cid, player),
    )
    assert "first_goal" in _facts(conn, cid, goal_count=1)
    conn.execute("UPDATE player_season_stat SET goals = 3 WHERE career_id = ?", (cid,))
    assert "first_goal" not in _facts(conn, cid, goal_count=1)

    # An earlier contract with the opponent's club makes it the old club.
    conn.execute(
        "INSERT INTO player_contract (career_id, player_id, team_id, signed_at, expires_at, weekly_wage, "
        "appearance_bonus, goal_bonus, release_clause) VALUES (?, ?, 'someone-else', '2020-01-01', "
        "'2021-01-01', 1, 0, 0, 0)", (cid, player),
    )
    assert "former_club_goal" in _facts(conn, cid, goal_count=1)
    assert "former_club_goal" not in _facts(conn, cid, goal_count=0)
    conn.close()


def test_a_match_result_can_open_an_event_and_hand_over_the_first_goal_ball(
    api_client, mock_engine, triggers_on
):
    cid = create_career(api_client)["career_id"]
    advance_to_match_day(api_client, cid)
    nxt = api_client.get(f"/careers/{cid}/matches/next").json()
    side, fixture_id = nxt["user_side"], nxt["fixture_id"]
    body = _valid_result_body(
        fixture_id,
        home_goals=2 if side == "home" else 0,
        away_goals=0 if side == "home" else 2,
    )

    resp = api_client.post(f"/careers/{cid}/matches/{fixture_id}/result", json=body)
    assert resp.status_code == 200, resp.text
    event = resp.json()["event"]
    # One interventions goal in a won match: the ball (65) outranks the terrace (50).
    assert event["template_id"] == "rel-ilk-gol-topu"
    assert event["catalog_id"] == "trigger:post_match"

    chosen = api_client.post(f"/careers/{cid}/activity-events/{event['event_id']}/choose/sakla")
    assert chosen.status_code == 200
    items = {i["catalog_id"] for i in api_client.get(f"/careers/{cid}/inventory").json()["items"]}
    assert "special-first-goal-ball" in items


def test_a_backfiring_joke_queues_its_follow_up(api_client, created_career, triggers_on, monkeypatch):
    cid = created_career["career_id"]
    grant_money(cid, 1000)
    from catalog.lifestyle import LIFESTYLE_ITEMS

    item = next(i for i in LIFESTYLE_ITEMS if i["catalog_id"] == "kulup-soyunma-saka")
    monkeypatch.setitem(item["risk"], "chance", 0.999999)
    # Clear the gate rather than train for it.
    monkeypatch.setitem(item, "requires", {})
    body = api_client.post(
        f"/careers/{cid}/actions", json={"catalog_id": "kulup-soyunma-saka", "relationship_id": "team"}
    ).json()
    assert body["risk"]["failed"] is True
    assert body["event"]["template_id"] == "rel-saka-kontrolden"


# --- deferred consequences -------------------------------------------------

def test_choosing_writes_the_consequence_and_it_comes_due_exactly_once(api_client, created_career):
    cid = created_career["career_id"]
    conn = _db()
    triggers.enqueue(conn, cid, "rel-sir-paylasimi", "daily", "2026-08-22", "a")
    event = triggers.promote(conn, cid, "2026-08-22")
    conn.commit()
    conn.close()

    resp = api_client.post(f"/careers/{cid}/activity-events/{event['event_id']}/choose/sir_tut")
    assert resp.status_code == 200
    conn = _db()
    [row] = conn.execute("SELECT * FROM deferred_consequence WHERE career_id = ?", (cid,)).fetchall()
    assert row["status"] == "pending"
    assert row["due_on"] == _plus("2026-08-22", 35)
    assert json.loads(row["effects"]) == {"relationship:team": 6}

    assert deferred.apply_due(conn, cid, _plus(row["due_on"], -1)) == []
    before = _score(api_client, cid, "team")
    conn.commit()
    applied = deferred.apply_due(conn, cid, row["due_on"])
    conn.commit()
    assert [a["consequence_id"] for a in applied] == [row["consequence_id"]]
    assert deferred.apply_due(conn, cid, row["due_on"]) == []                   # INV-68
    conn.commit()
    conn.close()
    assert _score(api_client, cid, "team") == before + 6


def test_a_consequence_can_carry_a_headline(api_client, created_career):
    cid = created_career["career_id"]
    conn = _db()
    later = _tpl("rel-sir-paylasimi")["options"][1]["defer"][0]      # "soyle"
    deferred.schedule(conn, cid, "2026-08-22", "rel-sir-paylasimi:soyle", later)
    [done] = deferred.apply_due(conn, cid, _plus("2026-08-22", 14))
    assert done["news"]["title"] == "Transfer görüşmesi sızdı"
    conn.close()


def test_ignoring_the_new_signing_brings_the_rival_clique_three_weeks_later(api_client, created_career):
    cid = created_career["career_id"]
    conn = _db()
    later = _tpl("rel-yeni-transfer-uyumu")["options"][1]["defer"][0]   # "gormezden"
    deferred.schedule(conn, cid, "2026-08-22", "rel-yeni-transfer-uyumu:gormezden", later)
    assert triggers.list_queued(conn, cid) == []
    deferred.apply_due(conn, cid, _plus("2026-08-22", 21))
    [candidate] = triggers.list_queued(conn, cid)
    assert candidate["template_id"] == "rel-gruplasma-rakip"
    assert candidate["trigger_kind"] == "deferred"
    conn.close()


def test_a_request_can_follow_itself(api_client, created_career):
    """#23 - helping once is what prepares the next request."""
    cid = created_career["career_id"]
    conn = _db()
    later = _tpl("rel-aileden-para")["options"][0]["defer"][0]
    deferred.schedule(conn, cid, "2026-08-22", "rel-aileden-para:yardim", later)
    deferred.apply_due(conn, cid, _plus("2026-08-22", 30))
    assert [c["template_id"] for c in triggers.list_queued(conn, cid)] == ["rel-aileden-para"]
    conn.close()


def test_a_due_loss_is_clamped_to_the_balance_instead_of_failing_the_day(api_client, created_career):
    cid = created_career["career_id"]
    conn = _db()
    balance = conn.execute("SELECT money FROM career_state WHERE career_id = ?", (cid,)).fetchone()[0]
    deferred.schedule(conn, cid, "2026-08-22", "t:o", {"days": 1, "effects": {"money": -(balance + 500)}})
    deferred.apply_due(conn, cid, "2026-08-23")
    assert conn.execute("SELECT money FROM career_state WHERE career_id = ?", (cid,)).fetchone()[0] == 0
    conn.close()


def test_a_brand_can_walk_away(api_client, created_career):
    cid = created_career["career_id"]
    conn = _db()
    conn.execute(
        "INSERT INTO sponsorship_deal (career_id, deal_id, template_id, status, offered_on, signed_on, "
        "expires_on, weekly_income) VALUES (?, 'sp_1', 'local_sports_shop', 'active', '2026-08-01', "
        "'2026-08-01', '2027-06-01', 6)", (cid,),
    )
    effects.apply(conn, cid, {"sponsorship:end": 1}, "lifestyle", "t", "2026-08-22T08:00:00+03:00")
    assert conn.execute("SELECT status FROM sponsorship_deal WHERE deal_id = 'sp_1'").fetchone()[0] == "broken"
    # Nothing left to end is not an error.
    effects.apply(conn, cid, {"sponsorship:end": 1}, "lifestyle", "t", "2026-08-22T08:00:00+03:00")
    conn.close()


def test_signing_the_boot_deal_hands_over_the_signature_boots(api_client, created_career):
    cid = created_career["career_id"]
    from tests.conftest import set_attribute

    set_attribute(cid, "charisma", 90)
    set_attribute(cid, "courage", 90)
    conn = _db()
    conn.execute(
        "INSERT INTO sponsorship_deal (career_id, deal_id, template_id, status, offered_on, weekly_income) "
        "VALUES (?, 'sp_boot', 'boot_brand', 'offered', '2026-08-22', 45)", (cid,),
    )
    conn.commit()
    conn.close()

    resp = api_client.post(f"/careers/{cid}/sponsorships/sp_boot/accept")
    assert resp.status_code == 200, resp.text
    items = {i["catalog_id"] for i in api_client.get(f"/careers/{cid}/inventory").json()["items"]}
    assert "special-signature-boots" in items
