import datetime as _dt
import sqlite3

import pytest

from api import config
from domain import onboarding

# §11.1 - dates come from the derived calendar, not spelled out. The season
# used to open on a hard-coded 2026-08-01; now it is "the last Saturday of
# August, minus a preparation week" and these follow it.
SEASON_START = onboarding.SEASON_STARTS_ON
LEAGUE_ROUND_1 = onboarding.FIRST_SEASON.league_starts_on.isoformat()


def _plus_days(iso: str, days: int) -> str:
    return (_dt.date.fromisoformat(iso) + _dt.timedelta(days=days)).isoformat()


def _first_monday_from(iso: str) -> str:
    day = _dt.date.fromisoformat(iso)
    return (day + _dt.timedelta(days=(0 - day.weekday()) % 7)).isoformat()
from catalog.shop import SHOP_ITEMS

BOOTS_PRICE = next(i["price"] for i in SHOP_ITEMS if i["catalog_id"] == "personal-boots")
from tests.conftest import (
    advance_to_match_day,
    create_career,
    grant_money,
    play_users_match,
    set_attribute,
)
from worlddata.attributes import BASE_SKILL_VALUE
from worlddata.relationships import STARTING_SCORES


@pytest.fixture
def created_career(api_client):
    return create_career(api_client)


# --- T1 -----------------------------------------------------------------

def test_get_day_fresh_career_opens_on_a_preparation_week(api_client, created_career):
    # League round 1 is a week after the season opens
    # (onboarding.LEAGUE_STARTS_ON), so day 1 is a quiet day the user spends
    # training and resting — not a match day.
    resp = api_client.get(f"/careers/{created_career['career_id']}/day")
    assert resp.status_code == 200
    body = resp.json()
    assert body["career_state"]["current_date"] == SEASON_START
    assert body["is_match_day"] is False
    assert not any(e["kind"] == "match" for e in body["events"])


# --- T2 -------------------------------------------------------------------

def test_post_action_training_spends_budget_and_applies_effects(api_client, created_career):
    career_id = created_career["career_id"]
    resp = api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": "sut"})
    assert resp.status_code == 200
    body = resp.json()

    assert body["applied_costs"] == {"time": 60, "energy": 18}
    base = BASE_SKILL_VALUE  # merkez_orta_saha spends no slot on shooting
    assert body["attribute_changes"] == [
        {"key": "shooting", "before": base, "after": base + 1.2,
         "level_before": 2, "level_after": 2}
    ]
    assert body["career_state"]["day_budget"]["time"] == 720 - 60
    assert body["career_state"]["day_budget"]["energy"] == 100 - 18


def test_post_action_unknown_catalog_id_errors(api_client, created_career):
    resp = api_client.post(f"/careers/{created_career['career_id']}/actions", json={"catalog_id": "does-not-exist"})
    assert resp.status_code == 422


def test_post_action_insufficient_budget_changes_nothing(api_client, created_career):
    career_id = created_career["career_id"]
    # ev-uyku costs 540 min; two of them exceed the 720 min/day pool.
    first = api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": "ev-uyku"})
    assert first.status_code == 200
    before = api_client.get(f"/careers/{career_id}/player").json()["attributes"]

    second = api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": "ev-uyku"})
    assert second.status_code == 409
    assert second.json()["code"] == "insufficient_budget"

    after = api_client.get(f"/careers/{career_id}/player").json()["attributes"]
    assert before == after  # INV-4: nothing applied on failure


def test_post_action_lifestyle_relationship_effect(api_client, created_career):
    career_id = created_career["career_id"]
    resp = api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": "sos-aile"})
    assert resp.status_code == 200
    body = resp.json()
    family_start = STARTING_SCORES["family"]
    assert body["relationship_changes"] == [
        {
            "relationship_id": "family", "before": family_start,
            "after": family_start + 3, "delta": 3,
        }
    ]


# --- T4 -------------------------------------------------------------------

def test_post_purchase_charges_money_and_records_inventory(api_client, created_career):
    career_id = created_career["career_id"]
    grant_money(career_id, 20000)
    funded = config.STARTING_MONEY + 20000

    resp = api_client.post(f"/careers/{career_id}/purchases", json={"catalog_id": "personal-boots"})
    assert resp.status_code == 200
    body = resp.json()

    assert body["item"]["price_paid"] == BOOTS_PRICE
    assert body["career_state"]["money"] == funded - BOOTS_PRICE
    # T4 does not touch the day's budget (§6.2 - money is an effect, not a cost).
    assert body["career_state"]["day_budget"]["time"] == 720


def test_post_purchase_already_owned_errors(api_client, created_career):
    career_id = created_career["career_id"]
    grant_money(career_id, 20000)
    api_client.post(f"/careers/{career_id}/purchases", json={"catalog_id": "personal-boots"})
    resp = api_client.post(f"/careers/{career_id}/purchases", json={"catalog_id": "personal-boots"})
    assert resp.status_code == 409
    assert resp.json()["code"] == "already_owned"


def test_post_purchase_insufficient_funds(api_client, created_career):
    career_id = created_career["career_id"]
    resp = api_client.post(f"/careers/{career_id}/purchases", json={"catalog_id": "estate-villa"})
    assert resp.status_code == 409
    assert resp.json()["code"] == "insufficient_funds"


# --- T3 -------------------------------------------------------------------

def test_advance_next_day_moves_the_date_one_day(api_client, created_career, mock_engine):
    career_id = created_career["career_id"]
    resp = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})
    assert resp.status_code == 200
    body = resp.json()

    assert body["days_advanced"] == 1
    assert body["career_state"]["current_date"] == _plus_days(SEASON_START, 1)


def test_advance_stops_on_match_day_when_seeking_next_event(api_client, created_career, mock_engine):
    career_id = created_career["career_id"]
    resp = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"})
    assert resp.status_code == 200
    body = resp.json()

    assert body["days_advanced"] == 7  # the preparation week, day by day
    assert body["stop_reason"] == "match"
    assert body["career_state"]["current_date"] == LEAGUE_ROUND_1
    assert body["simulated"]["fixtures"] > 0  # every non-user fixture that day

    # The user's own fixture is untouched — still scheduled, no score.
    user_team = created_career["player"]["team"]["team_id"]
    fixtures = api_client.get(f"/careers/{career_id}/fixtures", params={"team_id": user_team, "limit": 1}).json()
    assert fixtures["fixtures"][0]["status"] == "scheduled"


def test_advance_recovers_condition_every_day(api_client, created_career, mock_engine):
    """§6.3 - every advanced day pays NATURAL_CONDITION_RECOVERY_PER_DAY,
    bounded above by the attribute ceiling (INV-10)."""
    career_id = created_career["career_id"]
    conn = sqlite3.connect(config.DB_PATH)
    conn.execute("UPDATE career_state SET condition = 20 WHERE career_id = ?", (career_id,))
    conn.commit()
    conn.close()

    body = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"}).json()
    assert body["career_state"]["condition"] == 20 + config.NATURAL_CONDITION_RECOVERY_PER_DAY


def test_get_day_reports_what_the_next_day_is_worth(api_client, created_career):
    """§6.6 - T1 previews the same number process_day() will apply, so the
    hub can say "+5 bugün" without guessing at the rule."""
    body = api_client.get(f"/careers/{created_career['career_id']}/day").json()
    assert body["condition_recovery"] == {
        "base": config.NATURAL_CONDITION_RECOVERY_PER_DAY,
        "bonus": 0,
        "total": config.NATURAL_CONDITION_RECOVERY_PER_DAY,
        "capped": False,
        "sources": [],
    }


def test_owning_an_item_raises_both_the_preview_and_the_actual_gain(
    api_client, created_career, mock_engine
):
    """§6.6 end to end: buy the treadmill, and the SAME bigger number shows
    up in T1's preview and in the condition the next advanced day pays."""
    career_id = created_career["career_id"]
    grant_money(career_id, 100_000)
    assert api_client.post(
        f"/careers/{career_id}/purchases", json={"catalog_id": "home-treadmill"}
    ).status_code == 200

    preview = api_client.get(f"/careers/{career_id}/day").json()["condition_recovery"]
    assert preview["bonus"] == 2
    assert preview["total"] == config.NATURAL_CONDITION_RECOVERY_PER_DAY + 2
    assert [s["item_id"] for s in preview["sources"]] == ["home-treadmill"]

    conn = sqlite3.connect(config.DB_PATH)
    conn.execute("UPDATE career_state SET condition = 20 WHERE career_id = ?", (career_id,))
    conn.commit()
    conn.close()

    body = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"}).json()
    assert body["career_state"]["condition"] == 20 + preview["total"]


def test_the_item_bonus_still_stops_at_the_attribute_ceiling(
    api_client, created_career, mock_engine
):
    """INV-10 - the bonus changes the delta, never the clamp. A career
    starts at condition 100 with a ceiling of 100, so owning the whole
    recovery shelf must still leave it at 100, not 103."""
    career_id = created_career["career_id"]
    grant_money(career_id, 20_000_000)
    for catalog_id in ("home-treadmill", "estate-villa"):
        assert api_client.post(
            f"/careers/{career_id}/purchases", json={"catalog_id": catalog_id}
        ).status_code == 200

    body = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"}).json()
    assert body["career_state"]["condition"] == 100


def test_advance_reports_the_condition_it_moved(api_client, created_career, mock_engine):
    """§5.5 T3 - before/after travel together so a caller stepping day by
    day can animate the bar without caching the previous value itself."""
    career_id = created_career["career_id"]
    conn = sqlite3.connect(config.DB_PATH)
    conn.execute("UPDATE career_state SET condition = 40 WHERE career_id = ?", (career_id,))
    conn.commit()
    conn.close()

    body = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"}).json()
    assert body["condition_before"] == 40
    assert body["condition_after"] == 40 + config.NATURAL_CONDITION_RECOVERY_PER_DAY
    assert body["condition_after"] == body["career_state"]["condition"]


def test_advance_returns_the_events_of_the_day_it_stopped_on(
    api_client, created_career, mock_engine
):
    """`stop_reason` names the kind; `stopped_events` carries the ref_id that
    goes with it, so nothing has to re-fetch T1 to learn which fixture."""
    career_id = created_career["career_id"]
    body = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"}).json()

    assert body["stop_reason"] == "match"
    match_events = [e for e in body["stopped_events"] if e["kind"] == "match"]
    assert len(match_events) == 1
    assert match_events[0]["ref_id"].startswith("f_")

    day = api_client.get(f"/careers/{career_id}/day").json()
    assert body["stopped_events"] == day["events"]


def test_a_quiet_next_day_still_reports_its_events(api_client, created_career, mock_engine):
    """A `next_day` step that stopped because it was ASKED to, not because
    anything happened, still reports whatever was true that day —
    `stopped_events` is T1's list, not the stoppers. A fresh career sits on
    two relationships at 0, so it is never literally empty; what makes the
    day quiet is that none of them is stop-worthy (§6.3)."""
    career_id = created_career["career_id"]
    body = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"}).json()

    assert body["stop_reason"] == "none"
    assert {e["kind"] for e in body["stopped_events"]} == {"relationship_low"}
    assert body["stopped_events"] == api_client.get(f"/careers/{career_id}/day").json()["events"]


def test_advance_walks_a_full_week_between_matches(api_client, created_career, mock_engine):
    """The whole point of the day loop: a match, then days the user actually
    plays, then the next match. §6.1 D57 - the match itself has to be played
    (M1 -> M2) before the second advance can move at all.

    The gap after the league opener is four days, not seven: §11.1 puts the
    cup's first round on the Wednesday after the league's first Saturday,
    precisely so a midweek tie sits between league weekends."""
    career_id = created_career["career_id"]
    first = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"}).json()
    assert first["stop_reason"] == "match"

    play_users_match(api_client, career_id)

    second = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"}).json()
    assert second["stop_reason"] == "match"
    assert second["days_advanced"] == 4
    assert second["career_state"]["current_date"] ==         onboarding.FIRST_SEASON.cup_starts_on.isoformat()


def test_advance_refuses_while_the_users_match_is_unplayed(api_client, created_career, mock_engine):
    """§6.1 D57 - the old "missed match" auto-play is gone. Advancing off a
    match day without playing it is refused outright, not silently allowed
    with a penalty."""
    career_id = created_career["career_id"]
    user_team = created_career["player"]["team"]["team_id"]
    advance_to_match_day(api_client, career_id)
    fixture_id = api_client.get(f"/careers/{career_id}/fixtures", params={
        "team_id": user_team, "limit": 1,
    }).json()["fixtures"][0]["fixture_id"]
    date_before = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["current_date"]

    for to in ("next_day", "next_event"):
        resp = api_client.post(f"/careers/{career_id}/advance", json={"to": to})
        assert resp.status_code == 409
        assert resp.json()["code"] == "match_day_unplayed"
        assert fixture_id in resp.json()["message"]

    still = api_client.get(f"/careers/{career_id}/fixtures", params={"team_id": user_team, "limit": 1}).json()
    assert still["fixtures"][0]["status"] == "scheduled"
    assert api_client.get(f"/careers/{career_id}/day").json()["career_state"]["current_date"] == date_before


def test_advance_resumes_once_the_match_day_fixture_is_played(api_client, created_career, mock_engine):
    """The one way past the gate: play it."""
    career_id = created_career["career_id"]
    advance_to_match_day(api_client, career_id)

    blocked = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})
    assert blocked.status_code == 409

    play_users_match(api_client, career_id)

    resumed = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})
    assert resumed.status_code == 200


def test_advance_does_not_stop_on_a_persistently_low_relationship(api_client, created_career, mock_engine):
    """A low relationship is a state, not an event (§6.3). If it stopped the
    loop, every day would be 'eventful' and the calendar could never reach
    the next match."""
    career_id = created_career["career_id"]
    conn = sqlite3.connect(config.DB_PATH)
    conn.execute(
        "UPDATE relationship SET score = ? WHERE career_id = ?",
        (config.RELATIONSHIP_LOW_THRESHOLD - 1, career_id),
    )
    conn.commit()
    conn.close()

    day = api_client.get(f"/careers/{career_id}/day").json()
    assert any(e["kind"] == "relationship_low" for e in day["events"])  # T1 still reports it

    body = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"}).json()
    assert body["stop_reason"] == "match"
    assert body["days_advanced"] == 7


def test_advance_monday_pays_wage(api_client, created_career, mock_engine):
    career_id = created_career["career_id"]
    # The season opens on a Saturday; wages land on the first Monday after.
    api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})  # -> Sun 08-02
    resp = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})  # -> Mon 08-03
    body = resp.json()

    assert body["career_state"]["current_date"] == _first_monday_from(SEASON_START)
    wage_entries = [e for e in body["ledger_entries"] if e["kind"] == "wage"]
    assert len(wage_entries) == 1
    assert wage_entries[0]["amount"] == config.STARTING_WEEKLY_WAGE
    assert body["career_state"]["money"] == config.STARTING_MONEY + config.STARTING_WEEKLY_WAGE


def test_advance_past_the_season_asks_for_a_rollover(api_client, created_career):
    """§11.8 - the season being over is no longer the end of the career.
    `season_finished` retired; the new code names what to do about it."""
    career_id = created_career["career_id"]
    # Fast-forward past the season boundary directly (running the real
    # ~300-day loop would be impractically slow for a unit test).
    past_the_end = _plus_days(onboarding.SEASON_ENDS_ON, 5)
    conn = sqlite3.connect(config.DB_PATH)
    conn.execute(
        "UPDATE career_state SET game_date = ? WHERE career_id = ?",
        (past_the_end, career_id),
    )
    conn.commit()
    conn.close()

    resp = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})
    assert resp.status_code == 409
    assert resp.json()["code"] == "season_rollover_required"


def test_advance_upkeep_shortfall_warns_then_repossesses(api_client, created_career, mock_engine):
    career_id = created_career["career_id"]
    conn = sqlite3.connect(config.DB_PATH)
    conn.row_factory = sqlite3.Row
    # Force a shortfall: drain the balance and saddle the career with an
    # upkeep obligation bigger than the weekly wage can cover.
    conn.execute("UPDATE career_state SET money = 100 WHERE career_id = ?", (career_id,))
    conn.execute(
        "INSERT INTO inventory (career_id, item_id, purchased_at, price_paid, upkeep_weekly) "
        "VALUES (?, 'estate-villa', ?, 12750000, 4500)",
        (career_id, SEASON_START),
    )
    conn.commit()
    conn.close()

    # -> Sun 08-02
    api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})
    # -> Mon 08-03: projected balance (100 + 3500 = 3600) < upkeep (4500) -> warn, don't pay.
    warned = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"}).json()
    assert warned["stop_reason"] == "upkeep_warning"
    assert warned["career_state"]["money"] == 100  # untouched — wage/upkeep both skipped
    assert warned["repossessed"] == []

    # Calling advance again forces the still-unpaid Monday through
    # (resolve_pending_monday) before doing anything else: wage lands,
    # upkeep still can't be covered, so the villa is repossessed.
    resolved = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"}).json()
    assert "estate-villa" in resolved["repossessed"]
    sale_entries = [e for e in resolved["ledger_entries"] if e["kind"] == "sale"]
    assert len(sale_entries) == 1
    assert sale_entries[0]["amount"] == 12750000 // 2


# --- D42: the catalog gate ------------------------------------------------

def test_post_action_gated_item_refused_without_spending_a_minute(api_client, created_career):
    """INV-30, and the reason the check runs before day_budget.spend():
    a threshold you don't meet must not cost you the day."""
    career_id = created_career["career_id"]
    before = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["day_budget"]

    # medya-egitimi wants confidence 6; a fresh career sits at 51.0 (level 5).
    resp = api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": "medya-egitimi"})
    assert resp.status_code == 409
    assert resp.json()["code"] == "requirement_not_met"

    after = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["day_budget"]
    assert after == before
    charisma = next(
        a for a in api_client.get(f"/careers/{career_id}/player").json()["attributes"]
        if a["key"] == "charisma"
    )
    assert charisma["value"] == 74.0  # the effect never landed either


def test_post_action_gated_item_runs_once_the_level_is_reached(api_client, created_career):
    career_id = created_career["career_id"]
    grant_money(career_id, 10000)
    set_attribute(career_id, "confidence", 60.0)   # exactly level 6

    resp = api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": "medya-egitimi"})
    assert resp.status_code == 200
    assert {"key": "charisma", "before": 74.0, "after": 74.8,
            "level_before": 7, "level_after": 7} in resp.json()["attribute_changes"]


def test_post_action_gate_is_checked_before_the_budget(api_client, created_career):
    """Both would refuse this call; the contract's order table (§5.5) says
    the requirement wins, so the message tells the player what to fix."""
    career_id = created_career["career_id"]
    api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": "ev-uyku"})  # 540 of 720
    api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": "ev-oyun"})  # 180 -> 0 left

    resp = api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": "medya-egitimi"})
    assert resp.status_code == 409
    assert resp.json()["code"] == "requirement_not_met"


def test_post_action_social_activity_grows_a_kişi_attribute(api_client, created_career):
    career_id = created_career["career_id"]
    grant_money(career_id, 10000)
    resp = api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": "sos-arkadas"})
    assert resp.status_code == 200
    assert resp.json()["attribute_changes"] == [
        {"key": "charisma", "before": 74.0, "after": 74.3,
         "level_before": 7, "level_after": 7}
    ]


def test_post_action_satisfied_threshold_reads_as_no_gate(api_client, created_career):
    """sos-taraftar requires charisma 7 and a fresh career is exactly there
    — a met threshold must be as invisible as an absent one."""
    career_id = created_career["career_id"]
    resp = api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": "sos-taraftar"})
    assert resp.status_code == 200
    changed = {c["key"] for c in resp.json()["attribute_changes"]}
    assert changed == {"charisma", "confidence"}


def test_post_purchase_has_the_gate_wired_too(api_client, created_career, monkeypatch):
    """No shop item carries `requires` today (D42 is a mechanism, its use is
    a content decision) — so patch one in to prove the wiring is real."""
    from catalog import shop

    career_id = created_career["career_id"]
    grant_money(career_id, 100000)
    item = next(i for i in shop.SHOP_ITEMS if i["catalog_id"] == "personal-boots")
    monkeypatch.setitem(item, "requires", {"charisma": 9})

    resp = api_client.post(f"/careers/{career_id}/purchases", json={"catalog_id": "personal-boots"})
    assert resp.status_code == 409
    assert resp.json()["code"] == "requirement_not_met"
    assert api_client.get(f"/careers/{career_id}/player").json()["career_state"]["money"] == (
        config.STARTING_MONEY + 100000
    )


def test_attribute_change_reports_the_level_it_crossed(api_client, created_career):
    """The point of shipping levels on a change (D43): a client updating its
    local copy sees the gate open without re-deriving anything."""
    career_id = created_career["career_id"]
    grant_money(career_id, 10000)
    set_attribute(career_id, "confidence", 59.6)   # level 5

    resp = api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": "ozguven-koclugu"})
    assert resp.status_code == 200
    change = next(c for c in resp.json()["attribute_changes"] if c["key"] == "confidence")
    assert (change["before"], change["after"]) == (59.6, 60.4)
    assert (change["level_before"], change["level_after"]) == (5, 6)
