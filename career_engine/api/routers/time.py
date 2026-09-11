"""§5.5 - T1-T4."""
import datetime as _dt
import json
import sqlite3
from typing import Optional, Tuple

from fastapi import APIRouter, Depends

from api import config, errors, serializers
from api.deps import get_db
from api.schemas.time import ActionRequest, AdvanceRequest, PurchaseRequest
from catalog.lifestyle import LIFESTYLE_ITEMS
from catalog.shop import SHOP_ITEMS
from catalog.training import TRAINING_ITEMS
from domain import attributes, condition, day_budget, daytime, fame, requirements, social
from domain import relationships as relationships_domain
from domain import wallet

router = APIRouter(prefix="/careers/{career_id}", tags=["time"])


def _find_action_item(catalog_id: str) -> Tuple[Optional[dict], Optional[str]]:
    for item in TRAINING_ITEMS:
        if item["catalog_id"] == catalog_id:
            return item, "training"
    for item in LIFESTYLE_ITEMS:
        if item["catalog_id"] == catalog_id:
            return item, "lifestyle"
    return None, None


def _find_shop_item(catalog_id: str) -> Optional[dict]:
    return next((i for i in SHOP_ITEMS if i["catalog_id"] == catalog_id), None)


def _current_date(conn: sqlite3.Connection, career_id: str) -> str:
    # game_date, not current_date — SQLite's CURRENT_DATE keyword.
    return conn.execute(
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"]


@router.get("/day")
def get_day(career_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    career_state = serializers.fetch_career_state(conn, career_id)
    seed = conn.execute(
        "SELECT seed FROM career WHERE career_id = ?", (career_id,)
    ).fetchone()["seed"]
    events = daytime.list_events(conn, career_id, career_state["current_date"], seed)
    is_match_day = any(e["kind"] == "match" for e in events)
    return {
        "career_state": career_state,
        "is_match_day": is_match_day,
        "events": events,
        # §6.6 - what the NEXT advanced day is worth in condition, base and
        # owned-item bonus split out so FE can show where it came from
        # without fetching the shop catalog (§5.0: additive field).
        "condition_recovery": condition.daily_recovery(conn, career_id),
    }


@router.post("/actions")
def post_action(career_id: str, body: ActionRequest, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    item, source = _find_action_item(body.catalog_id)
    if item is None:
        raise errors.invalid_request(f"unknown catalog_id {body.catalog_id!r}")

    # D42/INV-30: the gate comes before the budget. It reads and never
    # writes, so it is the cheapest possible rejection — an item whose
    # threshold isn't met can't have cost the player a minute of the day.
    requirements.check(conn, career_id, config.USER_PLAYER_ID, item.get("requires"))

    happened_at = f"{_current_date(conn, career_id)}T00:00:00+03:00"

    # INV-4: check + deduct budget before anything else; writes nothing if
    # any resource is short. Money's own insufficient_funds check happens
    # naturally inside wallet.apply() below, before this transaction commits.
    day_budget.spend(conn, career_id, item["costs"])

    attribute_changes = []
    relationship_changes = []
    ledger_entries = []
    reason = f"{source}:{body.catalog_id}"

    for key, value in item["effects"].items():
        if value is None:
            continue  # ⟦AÇIK-9⟧ etc. — placeholder effect, not active yet
        if key.startswith("attribute:"):
            attribute_changes.append(
                attributes.apply_delta(conn, career_id, config.USER_PLAYER_ID, key.split(":", 1)[1], value)
            )
        elif key == "condition":
            condition.apply_delta(conn, career_id, value)
        elif key == "energy":
            day_budget.add(conn, career_id, "energy", value, ceiling=config.DAY_BUDGET_DEFAULTS.get("energy"))
        elif key == "money":
            ledger_entries.append(wallet.apply(conn, career_id, value, source, reason, happened_at))
        elif key.startswith("fame:"):
            fame.apply(conn, career_id, config.USER_PLAYER_ID, value, reason, happened_at, scope=key.split(":", 1)[1])
        elif key.startswith("relationship:"):
            relationship_changes.append(
                relationships_domain.apply_delta(
                    conn, career_id, key.split(":", 1)[1], value, reason, happened_at, touches_contact=True
                )
            )

    conn.execute(
        "INSERT INTO activity_log (career_id, happened_at, kind, catalog_id, applied_costs, "
        "applied_effects, payload) VALUES (?, ?, ?, ?, ?, ?, ?)",
        (
            career_id, happened_at, source, body.catalog_id,
            json.dumps(item["costs"]), json.dumps(item["effects"]),
            json.dumps(body.result, ensure_ascii=False) if body.result is not None else None,
        ),
    )
    conn.commit()

    return {
        "career_state": serializers.fetch_career_state(conn, career_id),
        "applied_costs": item["costs"],
        "applied_effects": item["effects"],
        "attribute_changes": attribute_changes,
        "relationship_changes": relationship_changes,
        "ledger_entries": ledger_entries,
    }


@router.post("/purchases")
def post_purchase(career_id: str, body: PurchaseRequest, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    item = _find_shop_item(body.catalog_id)
    if item is None:
        raise errors.invalid_request(f"unknown catalog_id {body.catalog_id!r}")

    requirements.check(conn, career_id, config.USER_PLAYER_ID, item.get("requires"))

    owned = conn.execute(
        "SELECT 1 FROM inventory WHERE career_id = ? AND item_id = ?", (career_id, body.catalog_id)
    ).fetchone()
    if owned:
        raise errors.already_owned(body.catalog_id)

    current_date = _current_date(conn, career_id)
    happened_at = f"{current_date}T00:00:00+03:00"

    # §6.2: a purchase spends no day_budget — money is an effect, not a cost.
    entry = wallet.apply(conn, career_id, -item["price"], "purchase", f"purchase:{body.catalog_id}", happened_at)
    conn.execute(
        "INSERT INTO inventory (career_id, item_id, purchased_at, price_paid, upkeep_weekly) "
        "VALUES (?, ?, ?, ?, ?)",
        (career_id, body.catalog_id, current_date, item["price"], item["upkeep_weekly"]),
    )
    conn.commit()

    return {
        "career_state": serializers.fetch_career_state(conn, career_id),
        "item": {
            "catalog_id": body.catalog_id, "purchased_at": current_date,
            "price_paid": item["price"], "upkeep_weekly": item["upkeep_weekly"],
        },
        "ledger_entries": [entry],
    }


@router.post("/advance")
def post_advance(career_id: str, body: AdvanceRequest, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    seed = conn.execute("SELECT seed FROM career WHERE career_id = ?", (career_id,)).fetchone()["seed"]
    current_date = _current_date(conn, career_id)

    season = conn.execute(
        "SELECT ends_on FROM season WHERE career_id = ? ORDER BY ends_on DESC LIMIT 1", (career_id,)
    ).fetchone()
    if season and current_date >= season["ends_on"]:
        raise errors.season_finished()

    # §6.1 D57: the user's own match today must be played, not skipped.
    # Checked before the social-offer gate — a scheduled match is the more
    # fundamental blocker of the two, and matches are pre-scheduled well in
    # advance while an offer is a same-day roll, so a same-day collision of
    # both is rare and match wins the message when it happens.
    unplayed_fixture_id = daytime.user_match_today(conn, career_id, current_date, seed)
    if unplayed_fixture_id:
        raise errors.match_day_unplayed(unplayed_fixture_id)

    # §6.3 D53: an open offer blocks time outright rather than being stopped
    # on again each day. Refusing at the door is a clearer failure than a
    # loop that advances zero days and reports "none" — and it makes the
    # mandatory answer recoverable if the app dies with the modal on screen.
    pending_offers = social.list_open(conn, career_id)
    if pending_offers:
        raise errors.social_offer_pending(pending_offers[0]["offer_id"])

    days_advanced = 0
    fixtures_total = 0
    competitions_total = set()
    ledger_entries, news_created, repossessed = [], [], []
    stop_reason = "none"
    stopped_events = []
    condition_before = conn.execute(
        "SELECT condition FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["condition"]

    # A Monday left unpaid by a previous upkeep_warning stop gets forced
    # through now, before advancing any further (D29).
    pending = daytime.resolve_pending_monday(conn, career_id, current_date)
    if pending:
        ledger_entries += pending["ledger_entries"]
        repossessed += pending["repossessed"]

    # The day the career currently sits on was never "advanced into" (it's
    # either day 1, fresh from onboarding, or wherever the last call left
    # off) — its own non-user fixtures/cup draw haven't run yet.
    today_catchup = daytime.resolve_pending_today(conn, career_id, current_date, seed)
    fixtures_total += today_catchup["fixtures_simulated"]
    competitions_total |= today_catchup["competitions_touched"]
    news_created += today_catchup["news_created"]

    for _ in range(config.MAX_ADVANCE_DAYS):
        next_date = (_dt.date.fromisoformat(current_date) + _dt.timedelta(days=1)).isoformat()

        day_result = daytime.process_day(conn, career_id, next_date, seed)
        current_date = next_date
        conn.execute("UPDATE career_state SET game_date = ? WHERE career_id = ?", (current_date, career_id))
        day_budget.refill(conn, career_id)

        days_advanced += 1
        ledger_entries += day_result["ledger_entries"]
        news_created += day_result["news_created"]
        repossessed += day_result["repossessed"]
        fixtures_total += day_result["fixtures_simulated"]
        competitions_total |= day_result["competitions_touched"]

        stoppers = daytime.stop_worthy(day_result["events"], next_date)
        if stoppers:
            stop_reason = stoppers[0]["kind"]
            stopped_events = day_result["events"]
            break
        if body.to == "next_day":
            stopped_events = day_result["events"]
            break
    else:
        stop_reason = "none"  # MAX_ADVANCE_DAYS safety cap hit

    conn.commit()

    career_state = serializers.fetch_career_state(conn, career_id)
    return {
        "career_state": career_state,
        "days_advanced": days_advanced,
        "stopped_on": current_date,
        "stop_reason": stop_reason,
        # §5.5 T3 - the full event list for the day the loop stopped on, not
        # just the winning kind. `stop_reason` alone is a label; the caller
        # that has to open something (a fixture, an offer) needs the ref_id
        # that comes with it, and fetching T1 again to get it would be a
        # second round trip for data this call already had in hand.
        "stopped_events": stopped_events,
        # §6.6 - what the run cost or paid in condition. FE animates the bar
        # per call without keeping its own copy of the previous value.
        "condition_before": condition_before,
        "condition_after": career_state["condition"],
        "simulated": {"fixtures": fixtures_total, "competitions": len(competitions_total)},
        "ledger_entries": ledger_entries,
        "news_created": news_created,
        "repossessed": repossessed,
    }
