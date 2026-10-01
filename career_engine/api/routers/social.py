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
from api.routers.time import run_action
from api.schemas.time import ActionRequest
from catalog import grant_item_id
from domain import attributes, condition, day_budget, fame, inventory, requirements, social, wallet
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
        granted_id = grant_item_id(key)
        if granted_id is not None:
            # §14.2 D82 - same hand-over as T2/T6's copy of this loop.
            inventory.grant(conn, career_id, granted_id, happened_at[:10])
            continue
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
    # INV-53: same rule for an offer that was opened as one side of a pair.
    if offer_id in social.conflict_member_refs(conn, career_id):
        raise errors.social_conflict_member(offer_id)

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
    # INV-53: half of an open conflict is not answerable on its own.
    if plan_id in social.conflict_member_refs(conn, career_id):
        raise errors.social_conflict_member(plan_id)

    template = social.template(plan["template_id"])
    branch = template["accept"] if template else {"effects": {}}
    costs = template.get("costs", {}) if template else {}

    # An invitation to a lifestyle activity: turning up IS doing that activity.
    # Budget, effects, risk and the partner's relationship all come from the
    # lifestyle row (T2's own body), and its "it was done" dialogue opens.
    activity_id = (template or {}).get("catalog_id")
    if activity_id:
        done = run_action(
            conn, career_id,
            ActionRequest(catalog_id=activity_id, relationship_id=plan["relationship_id"]),
            performed=True,
        )
        social.mark_plan_done(conn, career_id, plan_id)
        resolved = social.get_plan(conn, career_id, plan_id)
        conn.commit()
        return {**done, "plan": _public_plan(conn, career_id, resolved)}

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
    # INV-53: half of an open conflict is not answerable on its own.
    if plan_id in social.conflict_member_refs(conn, career_id):
        raise errors.social_conflict_member(plan_id)

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


# --- conflicts (§12.9, D59) ------------------------------------------------

def _public_conflict(conn: sqlite3.Connection, career_id: str, conflict: dict) -> dict:
    """Both halves, each with the person behind it.

    Neither `costs` nor the deltas travel, and for once those are the same
    reason rather than two. The deltas stay behind for `_public`'s reason — a
    payoff table on the wire is a payoff table the player can read, and this
    screen would be the easiest place in the game to read one. `costs` stay
    behind because a conflict spends nothing (D60): printing "2 sa · 20
    enerji" on a card that will charge neither would be a lie the UI told on
    the server's behalf.
    """
    return {
        **conflict,
        "sides": [
            {**side, "relationship": _relationship_ref(conn, career_id, side["relationship_id"])}
            for side in conflict["sides"]
        ],
    }


@router.get("/conflicts")
def list_conflicts(career_id: str, conn: sqlite3.Connection = Depends(get_db)):
    """Open conflicts — at most one, but a list for the same reason /offers
    and /plans are lists: the caller loops either way and a naked object
    would need a null case."""
    serializers.require_career(conn, career_id)
    on_date = conn.execute(
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"]
    # Asking creates the plan-vs-plan conflict if today has one waiting, the
    # same lazy-and-sticky write T1 does; the commit is ours to make.
    social.conflict_for_today(conn, career_id, on_date)
    conflicts = social.list_open_conflicts(conn, career_id)
    conn.commit()
    return {"conflicts": [_public_conflict(conn, career_id, c) for c in conflicts]}


@router.post("/conflicts/{conflict_id}/choose/{ref_id}")
def choose_conflict(
    career_id: str, conflict_id: str, ref_id: str,
    conn: sqlite3.Connection = Depends(get_db),
):
    """Pick the evening. The other one is closed in the same transaction
    (INV-52) and the response carries BOTH relationship changes, which is what
    lets the screen raise one bar while it drops the other.

    **Spends nothing and checks nothing** (D60). The answer is mandatory, so
    INV-40's argument applies with full force: a player out of time, money and
    attributes has to be able to get through this door, and here even the
    escape hatch is a choice that costs.
    """
    serializers.require_career(conn, career_id)

    conflict = social.get_conflict(conn, career_id, conflict_id)
    if conflict is None:
        raise errors.social_conflict_not_found(conflict_id)
    if conflict["status"] != social.CONFLICT_OPEN:
        raise errors.social_conflict_not_open(conflict_id)

    refs = [side["ref_id"] for side in conflict["sides"]]
    if ref_id not in refs:
        raise errors.invalid_request(
            f"{ref_id!r} is not a side of social conflict {conflict_id!r}; "
            f"expected one of {refs}"
        )
    rejected_ref = next(r for r in refs if r != ref_id)
    chosen = next(s for s in conflict["sides"] if s["ref_id"] == ref_id)
    rejected = next(s for s in conflict["sides"] if s["ref_id"] == rejected_ref)

    current_date = conn.execute(
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"]
    happened_at = f"{current_date}T12:00:00+03:00"
    source = conflict["source"]

    chosen_template = social.template(chosen["template_id"]) or {}
    rejected_template = social.template(rejected["template_id"]) or {}

    if source == social.CONFLICT_PLAN:
        # The template's own accept delta was already paid the day the offer
        # was accepted (§12.8), so the chosen side moves by the flat
        # turning-up bonus instead; the rejected one is a broken promise.
        social.mark_plan_done(conn, career_id, ref_id)
        social.mark_plan_missed(conn, career_id, rejected_ref)
        chosen_delta = social.CHOSEN_CONFLICT_RELATIONSHIP_DELTA
        rejected_delta = social.MISSED_PLAN_RELATIONSHIP_DELTA
    else:
        # Nothing was promised: this is an ordinary accept and an ordinary
        # decline that happened to arrive on the same evening, which is why
        # the loser here gets off so much more lightly than above.
        social.resolve(conn, career_id, ref_id, "accept", current_date)
        social.resolve(conn, career_id, rejected_ref, "decline", current_date)
        chosen_delta = chosen_template.get("accept", {}).get("relationship_delta", 0)
        rejected_delta = rejected_template.get("decline", {}).get("relationship_delta", 0)

    attribute_changes, ledger_entries = _apply_effects(
        conn, career_id, chosen_template.get("accept", {}).get("effects", {}),
        f"social_conflict:{source}:chosen", happened_at,
    )

    relationship_changes = [
        relationships_domain.apply_delta(
            conn, career_id, chosen["relationship_id"], chosen_delta,
            f"social_conflict:{source}:chosen", happened_at,
        ),
        relationships_domain.apply_delta(
            conn, career_id, rejected["relationship_id"], rejected_delta,
            f"social_conflict:{source}:rejected", happened_at,
        ),
    ]

    resolved = social.resolve_conflict(conn, career_id, conflict_id, ref_id)
    conn.commit()

    return {
        "career_state": serializers.fetch_career_state(conn, career_id),
        "conflict": _public_conflict(conn, career_id, resolved),
        "relationship_changes": relationship_changes,
        "attribute_changes": attribute_changes,
        "ledger_entries": ledger_entries,
    }
