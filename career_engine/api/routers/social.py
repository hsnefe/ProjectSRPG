"""§5.4 R4-R6 - the social offer endpoints. §12.8/D58 adds the social plan
endpoints a `plan_days_ahead` accept schedules.

R4 lists what is waiting; R5/R6 answer it. All three are bodyless, so there
is no schema module: R4 is a GET and the decision is in the path, not a
field — an endpoint that took `{"decision": "accept"}` would need its own
validation to reject a third value the router already knows can't exist.

The response shape of R5/R6 is R3's (`career_state` +
`relationship_changes` + `attribute_changes` + `ledger_entries`) plus the
resolved `offer`, so FE reuses the model it already has for a dialogue
outcome — an offer IS a dialogue, just one the other side started. Accepting
a `plan_days_ahead` template adds a `plan` alongside it (null otherwise);
the plan endpoints below reuse the same response shape.
"""
import datetime as _dt
import sqlite3

from fastapi import APIRouter, Depends

from api import config, errors, serializers
from api.deps import get_db
from domain import attributes, condition, day_budget, fame, requirements, social, wallet
from domain import relationships as relationships_domain

router = APIRouter(prefix="/careers/{career_id}/social", tags=["social"])


def _relationship_ref(conn: sqlite3.Connection, career_id: str, relationship_id: str) -> dict:
    row = conn.execute(
        "SELECT relationship_id, kind, category, score, person_name, contact_name "
        "FROM relationship WHERE career_id = ? AND relationship_id = ?",
        (career_id, relationship_id),
    ).fetchone()
    return dict(row) if row else None


def _public(conn: sqlite3.Connection, career_id: str, offer: dict) -> dict:
    """What FE is allowed to see. `costs` and `requires` travel because they
    are the gate the player is entitled to see BEFORE choosing (D42's whole
    reason for serving thresholds); the accept/decline deltas do not, for
    catalog/dialogue.public_catalog()'s reason — a payoff table on the wire
    is a payoff table the player can read."""
    return {
        **offer,
        "relationship": _relationship_ref(conn, career_id, offer["relationship_id"]),
    }


def _public_plan(conn: sqlite3.Connection, career_id: str, plan: dict) -> dict:
    """Same split as `_public`: `costs` travels (the player is choosing
    whether to spend today's budget on it), the effects behind it don't."""
    return {
        **plan,
        "relationship": _relationship_ref(conn, career_id, plan["relationship_id"]),
    }


@router.get("/offers")
def list_offers(career_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    offers = social.list_open(conn, career_id)
    return {"offers": [_public(conn, career_id, o) for o in offers]}


@router.get("/plans")
def list_plans(career_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    on_date = conn.execute(
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"]
    plans = social.list_due_plans(conn, career_id, on_date)
    return {"plans": [_public_plan(conn, career_id, p) for p in plans]}


def _apply_effects(
    conn: sqlite3.Connection, career_id: str, effects: dict, reason: str, happened_at: str,
) -> tuple:
    """The per-key effect dispatch shared by an instant accept/decline and a
    plan's `attend` — both apply the same `effects` map, just on different
    days. Returns (attribute_changes, ledger_entries)."""
    attribute_changes = []
    ledger_entries = []
    for key, value in effects.items():
        if value is None:
            continue  # placeholder effect, not active yet (⟦AÇIK-9⟧)
        if key.startswith("attribute:"):
            attribute_changes.append(
                attributes.apply_delta(conn, career_id, config.USER_PLAYER_ID, key.split(":", 1)[1], value)
            )
        elif key == "condition":
            condition.apply_delta(conn, career_id, value)
        elif key == "energy":
            day_budget.add(conn, career_id, "energy", value, ceiling=config.DAY_BUDGET_DEFAULTS.get("energy"))
        elif key == "money":
            ledger_entries.append(wallet.apply(conn, career_id, value, "lifestyle", reason, happened_at))
        elif key.startswith("fame:"):
            fame.apply(conn, career_id, config.USER_PLAYER_ID, value, reason, happened_at, scope=key.split(":", 1)[1])
        elif key.startswith("relationship:"):
            relationships_domain.apply_delta(
                conn, career_id, key.split(":", 1)[1], value, reason, happened_at, touches_contact=True
            )
    return attribute_changes, ledger_entries


def _resolve(career_id: str, offer_id: str, decision: str, conn: sqlite3.Connection) -> dict:
    """R5/R6's shared body. The two endpoints differ only in which branch of
    the template they apply and in whether anything is checked first — which
    is exactly the difference INV-40 is about, so it reads better as one
    function with a decision than as two that drift apart."""
    serializers.require_career(conn, career_id)

    offer = social.get(conn, career_id, offer_id)
    if offer is None:
        raise errors.social_offer_not_found(offer_id)
    if offer["status"] != "open":
        raise errors.social_offer_not_open(offer_id)

    template = social.template(offer["template_id"])
    if template is None:
        # The authored row was edited away under a live offer. Declining is
        # still possible (INV-40 must hold even here); accepting has no
        # branch to apply, so it is not an open offer any more.
        if decision == "accept":
            raise errors.social_offer_not_open(offer_id)
        branch = {"relationship_delta": 0, "effects": {}}
        costs = {}
        plan_days_ahead = None
    else:
        branch = template[decision]
        costs = template.get("costs", {}) if decision == "accept" else {}
        plan_days_ahead = template.get("plan_days_ahead") if decision == "accept" else None

    current_date = conn.execute(
        # game_date, not current_date — SQLite's CURRENT_DATE keyword.
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"]
    happened_at = f"{current_date}T12:00:00+03:00"
    reason = f"social:{offer['template_id']}:{decision}"

    # §5.5 T2's check order, verbatim: the gate reads and never writes, so it
    # is the cheapest rejection and must come first (INV-30). DECLINE SKIPS
    # ALL OF IT (INV-40) — the answer is mandatory, so a player who is broke
    # and unqualified must still be able to clear the offer, or a resource
    # shortfall would wedge the career.
    if decision == "accept":
        requirements.check(conn, career_id, config.USER_PLAYER_ID, template.get("requires"))
        # §12.8/D58 - a `plan_days_ahead` template defers `costs` to the day
        # the plan is actually attended (`attend_plan` spends them there);
        # charging the budget twice, once now and once on the day, would be
        # the same mistake as never charging it at all.
        if costs and not plan_days_ahead:
            day_budget.spend(conn, career_id, costs)

    plan = None
    if plan_days_ahead:
        due_on = (_dt.date.fromisoformat(current_date) + _dt.timedelta(days=plan_days_ahead)).isoformat()
        attribute_changes, ledger_entries = [], []
    else:
        attribute_changes, ledger_entries = _apply_effects(
            conn, career_id, branch.get("effects", {}), reason, happened_at
        )

    relationship_change = relationships_domain.apply_delta(
        conn, career_id, offer["relationship_id"], branch["relationship_delta"],
        reason, happened_at,
    )

    resolved = social.resolve(conn, career_id, offer_id, decision, current_date)

    if plan_days_ahead:
        plan = social.create_plan(
            conn, career_id, offer_id, offer["template_id"], offer["relationship_id"], due_on,
        )

    conn.commit()

    return {
        "career_state": serializers.fetch_career_state(conn, career_id),
        "offer": _public(conn, career_id, resolved),
        "plan": _public_plan(conn, career_id, plan) if plan else None,
        "relationship_changes": [relationship_change],
        "attribute_changes": attribute_changes,
        "ledger_entries": ledger_entries,
    }


@router.post("/offers/{offer_id}/accept")
def accept_offer(career_id: str, offer_id: str, conn: sqlite3.Connection = Depends(get_db)):
    return _resolve(career_id, offer_id, "accept", conn)


@router.post("/offers/{offer_id}/decline")
def decline_offer(career_id: str, offer_id: str, conn: sqlite3.Connection = Depends(get_db)):
    return _resolve(career_id, offer_id, "decline", conn)


@router.post("/plans/{plan_id}/attend")
def attend_plan(career_id: str, plan_id: str, conn: sqlite3.Connection = Depends(get_db)):
    """Turn up. Spends the day's budget and applies the effects that were
    withheld at accept time (§12.8/D58)."""
    serializers.require_career(conn, career_id)

    plan = social.get_plan(conn, career_id, plan_id)
    if plan is None:
        raise errors.social_plan_not_found(plan_id)
    if plan["status"] != social.PLAN_PENDING:
        raise errors.social_plan_not_open(plan_id)

    template = social.template(plan["template_id"])
    branch = template["accept"] if template else {"effects": {}}
    costs = template.get("costs", {}) if template else {}

    current_date = conn.execute(
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"]
    happened_at = f"{current_date}T12:00:00+03:00"
    reason = f"social_plan:{plan['template_id']}:attend"

    if costs:
        day_budget.spend(conn, career_id, costs)
    attribute_changes, ledger_entries = _apply_effects(
        conn, career_id, branch.get("effects", {}), reason, happened_at
    )

    social.mark_plan_done(conn, career_id, plan_id)
    resolved = social.get_plan(conn, career_id, plan_id)
    conn.commit()

    return {
        "career_state": serializers.fetch_career_state(conn, career_id),
        "plan": _public_plan(conn, career_id, resolved),
        "relationship_changes": [],
        "attribute_changes": attribute_changes,
        "ledger_entries": ledger_entries,
    }


@router.post("/plans/{plan_id}/skip")
def skip_plan(career_id: str, plan_id: str, conn: sqlite3.Connection = Depends(get_db)):
    """Don't. No cost, no gate (INV-40's reading again) — but the
    relationship takes a bigger hit than declining the offer would have,
    because this time a promise was already made (§12.8/D58)."""
    serializers.require_career(conn, career_id)

    plan = social.get_plan(conn, career_id, plan_id)
    if plan is None:
        raise errors.social_plan_not_found(plan_id)
    if plan["status"] != social.PLAN_PENDING:
        raise errors.social_plan_not_open(plan_id)

    current_date = conn.execute(
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"]
    happened_at = f"{current_date}T12:00:00+03:00"
    reason = f"social_plan:{plan['template_id']}:missed"

    social.mark_plan_missed(conn, career_id, plan_id)
    relationship_change = relationships_domain.apply_delta(
        conn, career_id, plan["relationship_id"], social.MISSED_PLAN_RELATIONSHIP_DELTA,
        reason, happened_at,
    )
    resolved = social.get_plan(conn, career_id, plan_id)
    conn.commit()

    return {
        "career_state": serializers.fetch_career_state(conn, career_id),
        "plan": _public_plan(conn, career_id, resolved),
        "relationship_changes": [relationship_change],
        "attribute_changes": [],
        "ledger_entries": [],
    }
