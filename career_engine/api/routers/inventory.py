"""§14.2 - the owned-item list and the equip switch.

There was no way to read the inventory before: the client kept an in-session
set of ids and P1 only reported what the items were worth. Equip makes the
list a real endpoint, because which of two watches is on the wrist is now state
the server owns (INV-66).

Equip/unequip change what the wardrobe is worth, so like every mutating
endpoint they return the whole CareerState (D28/INV-18) - plus the new
`passive_bonus` per kişi attribute, so a client can rebuild effective values
without re-fetching P1 (the same reason T2 carries it in `attribute_changes`).
"""
import sqlite3

from fastapi import APIRouter, Depends

from api import config, serializers
from api.deps import get_db
from domain import attributes, condition, inventory

router = APIRouter(prefix="/careers/{career_id}/inventory", tags=["inventory"])


def _mutation_body(conn: sqlite3.Connection, career_id: str) -> dict:
    return {
        "career_state": serializers.fetch_career_state(conn, career_id),
        "items": inventory.list_items(conn, career_id),
        "passive_bonus": {
            key: attributes.passive_bonus(conn, career_id, key)
            for key, family in config.ATTRIBUTE_KEYS.items() if family == "kişi"
        },
        "condition_recovery": condition.daily_recovery(conn, career_id),
    }


@router.get("")
def list_inventory(career_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    return {"items": inventory.list_items(conn, career_id)}


@router.post("/{item_id}/equip")
def equip_item(career_id: str, item_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    inventory.equip(conn, career_id, item_id)
    conn.commit()
    return _mutation_body(conn, career_id)


@router.post("/{item_id}/unequip")
def unequip_item(career_id: str, item_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    inventory.unequip(conn, career_id, item_id)
    conn.commit()
    return _mutation_body(conn, career_id)
