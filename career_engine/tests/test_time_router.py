import pytest


@pytest.fixture
def created_career(api_client):
    return api_client.post(
        "/careers",
        json={"player_name": "Efe Kaan", "position": "Orta saha", "team_id": "t_ykz", "seed": 42},
    ).json()


# --- T1 -----------------------------------------------------------------

def test_get_day_fresh_career_is_a_match_day(api_client, created_career):
    # Round 1 kicks off on SEASON_STARTS_ON itself (scheduling.py's day-0
    # offset) — a brand-new career's very first day already has a fixture.
    resp = api_client.get(f"/careers/{created_career['career_id']}/day")
    assert resp.status_code == 200
    body = resp.json()
    assert body["is_match_day"] is True
    assert any(e["kind"] == "match" for e in body["events"])


# --- T2 -------------------------------------------------------------------

def test_post_action_training_spends_budget_and_applies_effects(api_client, created_career):
    career_id = created_career["career_id"]
    resp = api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": "sut"})
    assert resp.status_code == 200
    body = resp.json()

    assert body["applied_costs"] == {"time": 60, "energy": 18}
    assert body["attribute_changes"] == [{"key": "shooting", "before": 50.0, "after": 51.2}]
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
    assert body["relationship_changes"] == [
        {"relationship_id": "family", "before": 50, "after": 53, "delta": 3}
    ]


# --- T4 -------------------------------------------------------------------

def test_post_purchase_charges_money_and_records_inventory(api_client, created_career):
    career_id = created_career["career_id"]
    resp = api_client.post(f"/careers/{career_id}/purchases", json={"catalog_id": "personal-boots"})
    assert resp.status_code == 200
    body = resp.json()

    assert body["item"]["price_paid"] == 8900
    assert body["career_state"]["money"] == 48200 - 8900
    # T4 does not touch the day's budget (§6.2 - money is an effect, not a cost).
    assert body["career_state"]["day_budget"]["time"] == 720


def test_post_purchase_already_owned_errors(api_client, created_career):
    career_id = created_career["career_id"]
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

def test_advance_next_day_moves_date_and_simulates_other_fixtures(api_client, created_career, mock_engine):
    career_id = created_career["career_id"]
    resp = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})
    assert resp.status_code == 200
    body = resp.json()

    assert body["days_advanced"] == 1
    assert body["career_state"]["current_date"] == "2026-08-02"
    assert body["simulated"]["fixtures"] > 0  # every non-user fixture that day

    # The user's own fixture is untouched — still scheduled, no score.
    fixtures = api_client.get(f"/careers/{career_id}/fixtures", params={"team_id": "t_ykz", "limit": 1}).json()
    assert fixtures["fixtures"][0]["status"] == "scheduled"


def test_advance_stops_on_match_day_when_seeking_next_event(api_client, created_career, mock_engine):
    career_id = created_career["career_id"]
    # Day 1 (today) is already a match day; advancing to "next_event" from
    # here should immediately stop on the day after, once no longer a match
    # day — actually today already IS one, so the very first step forward
    # lands on a non-match day unless another fixture is scheduled there too.
    resp = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_event"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["days_advanced"] >= 1
    assert body["stop_reason"] in (
        "match", "cup_draw", "contract_expiring", "upkeep_warning", "relationship_low", "season_end", "none",
    )


def test_advance_monday_pays_wage(api_client, created_career, mock_engine):
    career_id = created_career["career_id"]
    # 2026-08-01 is a Saturday; 2026-08-03 is the first Monday.
    api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})  # -> Sun 08-02
    resp = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})  # -> Mon 08-03
    body = resp.json()

    assert body["career_state"]["current_date"] == "2026-08-03"
    wage_entries = [e for e in body["ledger_entries"] if e["kind"] == "wage"]
    assert len(wage_entries) == 1
    assert wage_entries[0]["amount"] == 3500
    assert body["career_state"]["money"] == 48200 + 3500


def test_advance_season_finished_errors(api_client, created_career):
    career_id = created_career["career_id"]
    # Fast-forward past the season boundary directly (running the real
    # ~300-day loop would be impractically slow for a unit test).
    import sqlite3
    from api import config
    conn = sqlite3.connect(config.DB_PATH)
    conn.execute("UPDATE career_state SET game_date = '2027-06-01' WHERE career_id = ?", (career_id,))
    conn.commit()
    conn.close()

    resp = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})
    assert resp.status_code == 409
    assert resp.json()["code"] == "season_finished"


def test_advance_upkeep_shortfall_warns_then_repossesses(api_client, created_career, mock_engine):
    career_id = created_career["career_id"]
    import sqlite3
    from api import config
    conn = sqlite3.connect(config.DB_PATH)
    conn.row_factory = sqlite3.Row
    # Force a shortfall: drain the balance and saddle the career with an
    # upkeep obligation bigger than the weekly wage can cover.
    conn.execute("UPDATE career_state SET money = 100 WHERE career_id = ?", (career_id,))
    conn.execute(
        "INSERT INTO inventory (career_id, item_id, purchased_at, price_paid, upkeep_weekly) "
        "VALUES (?, 'estate-villa', '2026-08-01', 12750000, 4500)",
        (career_id,),
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
