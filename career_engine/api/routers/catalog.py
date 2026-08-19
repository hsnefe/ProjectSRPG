"""§5.7 N3 - career-independent, read-only catalog (D16, D41)."""
from fastapi import APIRouter

from api import errors
from catalog.lifestyle import LIFESTYLE_ITEMS
from catalog.shop import SHOP_ITEMS
from catalog.training import TRAINING_ITEMS

router = APIRouter(prefix="/catalog", tags=["catalog"])

_CATALOGS = {"training": TRAINING_ITEMS, "lifestyle": LIFESTYLE_ITEMS, "shop": SHOP_ITEMS}


@router.get("/{kind}")
def get_catalog(kind: str):
    items = _CATALOGS.get(kind)
    if items is None:
        raise errors.invalid_request(f"unknown catalog kind {kind!r}, expected one of {sorted(_CATALOGS)}")
    return {"items": items}
