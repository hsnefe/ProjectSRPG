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
from catalog import grant_item_id
from catalog.shop import SHOP_ITEMS
from catalog.training import TRAINING_ITEMS
from domain import activity_events, attributes, condition, day_budget, daytime, fame, inventory, requirements, social
from domain import effects as effects_domain
from domain import context, deferred, social_activity, triggers
from domain import relationships as relationships_domain
from domain import season as season_mod
from domain import sponsorship
from domain import tactics
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


def _seed(conn: sqlite3.Connection, career_id: str) -> int:
    return conn.execute(
        "SELECT seed FROM career WHERE career_id = ?", (career_id,)
    ).fetchone()["seed"]


# §14.5 - the loop that used to live here moved to domain/effects.py, because the
# day loop now applies effects too (an ignored event, a due consequence) and cannot
# import a router. Kept under its old name: T2, T6 and the housing router call it.
_apply_effects = effects_domain.apply


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
        #
        # §14.4 D88 - asked about the night the advance would actually process
        # (tomorrow), so the roommate-noise roll in the preview is the one the day
        # loop will throw.
        "condition_recovery": condition.daily_recovery(
            conn, career_id,
            (_dt.date.fromisoformat(career_state["current_date"]) + _dt.timedelta(days=1)).isoformat(),
            seed,
        ),
    }


@router.post("/actions")
def post_action(career_id: str, body: ActionRequest, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    response = run_action(conn, career_id, body, performed=False)
    conn.commit()
    return response


def run_action(
    conn: sqlite3.Connection, career_id: str, body: ActionRequest, performed: bool
) -> dict:
    """The body of T2. Never commits - the caller does, once (INV-3). With
    `performed` (a planned lifestyle activity reaching its day) the "it was
    done" dialogue always opens instead of the random event roll."""
    item, source = _find_action_item(body.catalog_id)
    if item is None:
        raise errors.invalid_request(f"unknown catalog_id {body.catalog_id!r}")

    # D42/INV-30: the gate comes before the budget. It reads and never
    # writes, so it is the cheapest possible rejection — an item whose
    # threshold isn't met can't have cost the player a minute of the day.
    requirements.check(conn, career_id, config.USER_PLAYER_ID, item.get("requires"))

    # §14.3 D84 - who it is done with. Like the gate above it reads and never
    # writes, and it comes before the budget for the same reason.
    partner = social_activity.resolve_partner(conn, career_id, item, body.relationship_id)
    effects = social_activity.effects_for(item, partner)
    # §14.7 - a worn stream kit / camera crew / jacket makes this activity teach more.
    effects = context.boost_effects(conn, career_id, item, effects)

    happened_at = f"{_current_date(conn, career_id)}T00:00:00+03:00"

    # INV-4: check + deduct budget before anything else; writes nothing if
    # any resource is short. Money's own insufficient_funds check happens
    # naturally inside wallet.apply() below, before this transaction commits.
    day_budget.spend(conn, career_id, item["costs"])

    reason = f"{source}:{body.catalog_id}"
    # §13.2 - an action CAN end a relationship: a `relationship:` effect that
    # drops a partner to 0 closes it at the single write path. Without this
    # the card would simply be gone from the next R1 with nothing in the
    # response to explain it.
    states_before = relationships_domain.state_snapshot(conn, career_id)
    applied = _apply_effects(conn, career_id, effects, source, reason, happened_at)

    # §14.3 D85 - a risky activity rolls AFTER its normal effects, and what it
    # loses comes on top of them: the evening still happened, it just cost more.
    fail_effects = None
    risk = social_activity.roll_risk(
        conn, career_id, item, _current_date(conn, career_id), _seed(conn, career_id)
    )
    if risk is not None and risk["failed"]:
        lost = social_activity.fail_effects_for(conn, career_id, item)
        social_activity.merge_applied(
            applied, _apply_effects(conn, career_id, lost, source, f"{reason}:fail", happened_at)
        )
        fail_effects = lost

    # §14.7 - a media activity may make the papers. The failure headline only
    # exists on an activity that can fail; a success headline is optional.
    news_id = None
    story = (item.get("news") or {}).get("fail" if risk and risk["failed"] else "ok")
    if story is not None:
        news_id = daytime._create_news(
            conn, career_id, story["category"], story["title"], story["body"],
            _current_date(conn, career_id), source=story.get("source", "Kulüp Bülteni"),
        )
    state_changes = relationships_domain.state_diff(
        states_before, relationships_domain.state_snapshot(conn, career_id)
    )

    # §13.4/D75 - the roll happens AFTER the action has fully applied. The
    # activity is a complete transaction on its own (INV-3); an event is
    # something that happened DURING it, not a condition of it. So a career
    # that already has an open event (INV-62), or one whose roll comes up
    # short, still gets exactly the action it asked for.
    #
    # Training never rolls: only lifestyle rows carry `event_chance`, and
    # nothing is supposed to happen to you during a shooting drill.
    event = None
    if source == "lifestyle":
        if performed:
            event = activity_events.open_performed(
                conn, career_id, body.catalog_id,
                _current_date(conn, career_id), _seed(conn, career_id),
            )
        else:
            event = activity_events.maybe_generate(
                conn, career_id, body.catalog_id, item,
                _current_date(conn, career_id), _seed(conn, career_id),
            )
        # §14.5 D91 - a dressing-room joke that backfired is also a trigger. It
        # only queues; the queue opens it when INV-62 allows, which is right now
        # unless the roll above already opened something.
        triggers.run_activity(
            conn, career_id, body.catalog_id, bool(risk and risk["failed"]),
            _current_date(conn, career_id),
        )
        if event is None:
            event = triggers.promote(conn, career_id, _current_date(conn, career_id))

    conn.execute(
        "INSERT INTO activity_log (career_id, happened_at, kind, catalog_id, applied_costs, "
        "applied_effects, payload) VALUES (?, ?, ?, ?, ?, ?, ?)",
        (
            career_id, happened_at, source, body.catalog_id,
            json.dumps(item["costs"]),
            # The log is flat; what a failed roll added sits under `fail:` keys
            # so an audit can tell the normal effects from the penalty.
            json.dumps({**effects, **{f"fail:{k}": v for k, v in (fail_effects or {}).items()}}),
            json.dumps(body.result, ensure_ascii=False) if body.result is not None else None,
        ),
    )

    return {
        "career_state": serializers.fetch_career_state(conn, career_id),
        "applied_costs": item["costs"],
        "applied_effects": effects,
        **applied,
        # §14.3 - null for a safe activity; FE shows "it went wrong" from it.
        "risk": risk,
        "fail_effects": fail_effects,
        "with": partner,
        "news_id": news_id,
        "relationship_state_changes": state_changes,   # §13.2 - empty list, never null
        # §13.4 - null on the overwhelming majority of actions. FE opens the
        # panel when it is not.
        "event": event,
    }


@router.get("/activity-events")
def list_activity_events(career_id: str, conn: sqlite3.Connection = Depends(get_db)):
    """T5 §13.4 - the open event, if there is one.

    Exists because D76 chose NOT to gate the day loop on an answer: an event
    the player closed the app on would otherwise be unreachable and would sit
    in the table until an advance expired it. Empty list when there is
    nothing open — not an error, the same way R4 answers a quiet day.
    """
    serializers.require_career(conn, career_id)
    return {"events": activity_events.list_open(conn, career_id)}


@router.post("/activity-events/{event_id}/choose/{option_id}")
def choose_activity_event(
    career_id: str, event_id: str, option_id: str, conn: sqlite3.Connection = Depends(get_db)
):
    """T6 §13.4 - apply one option.

    Check order is T2's, one row longer: exists → open → the option belongs
    to it → `requires` → budget → balance. A rejected choice writes nothing
    and leaves the event OPEN (INV-30's shape) — the player picks again
    rather than losing the moment to a 409.
    """
    serializers.require_career(conn, career_id)

    event = activity_events.get(conn, career_id, event_id)
    if event is None:
        raise errors.activity_event_not_found(event_id)
    if event["status"] != activity_events.OPEN:
        raise errors.activity_event_not_open(event_id)

    option = activity_events.option_for(event["template_id"], option_id)
    if option is None:
        # 422, not 404: the event exists and is open, the body names a branch
        # of it that does not. Same reading catalog/dialogue.resolve_outcome
        # gives an unknown leaf.
        raise errors.invalid_request(
            f"event {event_id!r} has no option {option_id!r}"
        )

    # D42 first, and it reads the effective level (§13.3/INV-61) — the suit
    # you bought counts at this door like any other.
    requirements.check(conn, career_id, config.USER_PLAYER_ID, option.get("requires"))
    day_budget.spend(conn, career_id, option.get("costs", {}))

    current_date = _current_date(conn, career_id)
    happened_at = f"{current_date}T12:00:00+03:00"
    reason = f"activity_event:{event['template_id']}:{option_id}"
    states_before = relationships_domain.state_snapshot(conn, career_id)
    applied = _apply_effects(
        conn, career_id, option.get("effects", {}), "lifestyle", reason, happened_at
    )

    # §13.4 → §13.2 - the single bridge between the two. Only from ABSENT:
    # an option that introduces someone cannot re-introduce a partner you
    # already have, which is what lets the template stay in the pool forever.
    target = option.get("starts_relationship")
    if target is not None:
        if relationships_domain.get_state(conn, career_id, target) == config.STATE_ABSENT:
            relationships_domain.set_state(conn, career_id, target, config.STATE_COURTING)

    state_changes = relationships_domain.state_diff(
        states_before, relationships_domain.state_snapshot(conn, career_id)
    )

    # §14.6 D94 - whatever the option leaves for later is written down now, in the
    # same transaction as the answer (INV-3).
    for later in option.get("defer", []):
        deferred.schedule(conn, career_id, current_date, f"{event['template_id']}:{option_id}", later)

    resolved = activity_events.resolve(conn, career_id, event_id, option_id, current_date)
    conn.commit()

    return {
        # D28/INV-18 - T6 mutates, so it carries the whole block.
        "career_state": serializers.fetch_career_state(conn, career_id),
        "event": resolved,
        "applied_costs": option.get("costs", {}),
        "applied_effects": option.get("effects", {}),
        **applied,
        "relationship_state_changes": state_changes,
    }


@router.post("/purchases")
def post_purchase(career_id: str, body: PurchaseRequest, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    item = _find_shop_item(body.catalog_id)
    if item is None:
        raise errors.invalid_request(f"unknown catalog_id {body.catalog_id!r}")

    if item.get("acquire", "shop") != "shop":
        raise errors.item_not_for_sale(body.catalog_id)  # §14.2 D82 - earned, not bought

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
    # §12.13 D65: weekly_return is frozen here, same reasoning as
    # price_paid/upkeep_weekly — a re-priced item in the catalog never
    # changes what an already-purchased row pays out.
    # §14.2 D80: inventory.add() also freezes slot/grade and wears the item
    # when its slot is empty. weekly_return is computed there from the same rule.
    row = inventory.add(conn, career_id, item, current_date, item["price"])
    # §14.7 - some purchases make the papers (the painted supercar).
    story = context.acquire_story(body.catalog_id)
    news_id = None
    if story is not None:
        news_id = daytime._create_news(
            conn, career_id, story.get("category", "Röportaj"), story["title"], story["body"],
            current_date, source=story.get("source", "Sosyal Medya"),
        )
    conn.commit()

    return {
        "career_state": serializers.fetch_career_state(conn, career_id),
        "item": {
            "catalog_id": body.catalog_id, "purchased_at": current_date,
            "price_paid": item["price"], "upkeep_weekly": item["upkeep_weekly"],
            "slot": row["slot"], "grade": row["grade"], "equipped": row["equipped"],
        },
        "ledger_entries": [entry],
        "news_id": news_id,
    }


@router.post("/advance")
def post_advance(career_id: str, body: AdvanceRequest, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    seed = conn.execute("SELECT seed FROM career WHERE career_id = ?", (career_id,)).fetchone()["seed"]
    current_date = _current_date(conn, career_id)

    # §11.8 - the gate asks the PHASE, not the calendar boundary. §11.2's
    # last rule lets a season end early (the table says June, the last match
    # was played in May), and only the phase knows that. Retired:
    # `season_finished`, which was a dead end; this one names what to do
    # about it (S1).
    if season_mod.derive_phase(conn, career_id, current_date) == season_mod.SEASON_END:
        raise errors.season_rollover_required()

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
    # §12.9/D59 - before both gates below, because a conflict's two sides ARE
    # an open offer or a due plan: let those fire first and the player is sent
    # to a screen that shows one evening when the decision is about two.
    conflict = social.conflict_for_today(conn, career_id, current_date)
    if conflict:
        raise errors.social_conflict_pending(conflict["conflict_id"])

    pending_offers = social.list_open(conn, career_id)
    if pending_offers:
        raise errors.social_offer_pending(pending_offers[0]["offer_id"])

    # §12.8/D58 - the same gate for a plan the player already accepted. You
    # said you'd be there; the day it's due is not one you advance past
    # unanswered. `skip` (not `attend`) is the way out, same shape as a
    # sponsorship obligation just below.
    due_plans = social.list_due_plans(conn, career_id, current_date)
    if due_plans:
        raise errors.social_plan_pending(due_plans[0]["plan_id"])

    # §12.7 - the same gate for a booked sponsorship appearance. You said
    # you would be there; the day is not one you skip past. The way out is
    # `skip`, which breaks the deal - the player is charged, never trapped.
    due = sponsorship.pending_obligations(conn, career_id, current_date)
    if due:
        raise errors.sponsorship_obligation_pending(due[0]["obligation_id"])

    days_advanced = 0
    fixtures_total = 0
    competitions_total = set()
    ledger_entries, news_created, repossessed = [], [], []
    residence_moves = []
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
    # A sponsorship offer rolled for the day being closed out belongs to the
    # caller's event list too; the loop below only reports days it advanced
    # INTO, and this one it is leaving.
    catchup_events = today_catchup["events"]

    for _ in range(config.MAX_ADVANCE_DAYS):
        next_date = (_dt.date.fromisoformat(current_date) + _dt.timedelta(days=1)).isoformat()

        # §13.4/D76/INV-63 - the moment is gone. Expired before the day is
        # processed rather than after: an event born on the day being left
        # behind must not be able to survive into the next one, where its
        # text ("yan masadaki biri") would no longer be about anything.
        # Writes nothing but the status — no effects, no costs, no ledger.
        activity_events.expire_open(conn, career_id, current_date)

        day_result = daytime.process_day(conn, career_id, next_date, seed)
        current_date = next_date
        conn.execute("UPDATE career_state SET game_date = ? WHERE career_id = ?", (current_date, career_id))
        day_budget.refill(conn, career_id)
        # §12.12 - AFTER refill, which resets day_budget.remaining to the flat
        # default wholesale; an owned item's energy bonus applied before this
        # would be silently overwritten a line later. No `ceiling` here on
        # purpose (unlike T2's one-shot energy effect, which tops back up
        # TOWARD the default after spending): the whole point of an item like
        # home-espresso is to raise TODAY's energy past the plain default,
        # not just restore it there — capping at the default would make the
        # bonus a no-op the instant it's added, since refill already put
        # `remaining` exactly at that ceiling.
        if day_result["energy_bonus"]:
            day_budget.add(conn, career_id, "energy", day_result["energy_bonus"])

        days_advanced += 1
        ledger_entries += day_result["ledger_entries"]
        news_created += day_result["news_created"]
        repossessed += day_result["repossessed"]
        residence_moves += day_result["residence_moves"]
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
        # §5.5 T3 - the full event list for the day the loop stopped on, plus
        # anything that rolled for the day being left behind (a sponsorship
        # offer can), not just the winning kind. `stop_reason` alone is a label; the caller
        # that has to open something (a fixture, an offer) needs the ref_id
        # that comes with it, and fetching T1 again to get it would be a
        # second round trip for data this call already had in hand.
        "stopped_events": catchup_events + stopped_events,
        # §6.6 - what the run cost or paid in condition. FE animates the bar
        # per call without keeping its own copy of the previous value.
        "condition_before": condition_before,
        "condition_after": career_state["condition"],
        "simulated": {"fixtures": fixtures_total, "competitions": len(competitions_total)},
        "ledger_entries": ledger_entries,
        "news_created": news_created,
        "repossessed": repossessed,
        # §14.4 - forced moves (an eviction, a hotel stay that ran out) in the order
        # they happened; empty on the overwhelming majority of advances.
        "residence_moves": residence_moves,
    }
