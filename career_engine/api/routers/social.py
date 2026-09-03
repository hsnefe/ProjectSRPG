"""§5.4 R4-R6 - the social offer endpoints.

R4 lists what is waiting; R5/R6 answer it. All three are bodyless, so there
is no schema module: R4 is a GET and the decision is in the path, not a
field — an endpoint that took `{"decision": "accept"}` would need its own
validation to reject a third value the router already knows can't exist.

The response shape of R5/R6 is R3's (`career_state` +
`relationship_changes` + `attribute_changes` + `ledger_entries`) plus the
resolved `offer`, so FE reuses the model it already has for a dialogue
outcome — an offer IS a dialogue, just one the other side started.
"""
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


@router.get("/offers")
def list_offers(career_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    offers = social.list_open(conn, career_id)
    return {"offers": [_public(conn, career_id, o) for o in offers]}


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
    else:
        branch = template[decision]
        costs = template.get("costs", {}) if decision == "accept" else {}

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
        if costs:
            day_budget.spend(conn, career_id, costs)

    attribute_changes = []
    ledger_entries = []
    for key, value in branch.get("effects", {}).items():
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

    relationship_change = relationships_domain.apply_delta(
        conn, career_id, offer["relationship_id"], branch["relationship_delta"],
        reason, happened_at,
    )

    resolved = social.resolve(conn, career_id, offer_id, decision, current_date)
    conn.commit()

    return {
        "career_state": serializers.fetch_career_state(conn, career_id),
        "offer": _public(conn, career_id, resolved),
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
