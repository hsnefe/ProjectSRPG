"""§5.7 N3 / INV-28 - validates every catalog item's costs/effects keys
against the known anchor spaces the moment the catalog module is imported.

INV-28 says an item with an unrecognized key isn't loaded; since this
catalog is a fixed, author-controlled data file (not user-editable at
runtime), the strongest version of "not loaded" is failing import outright
rather than silently dropping rows an endpoint might otherwise serve half-
validated. A live catalog-editing feature, if one is ever built, would
need the softer runtime-skip behavior instead — not needed for v1.
"""
import re

from api.config import ATTRIBUTE_KEYS

_ATTRIBUTE_KEY = re.compile(r"^attribute:(\w+)$")
_FAME_KEY = re.compile(r"^fame:(\w+)$")
_RELATIONSHIP_KEY = re.compile(r"^relationship:(\w+)$")
_SIMPLE_EFFECT_KEYS = {"condition", "energy", "money"}

# D41 - the only cost dimensions any catalog item may spend from
# day_budget. ⟦AÇIK-5⟧ owns the actual resource list; this is deliberately
# already wider than what §6.2's example uses (time, energy) in case a
# third dimension is added later without a code change here.
KNOWN_COST_KEYS = {"time", "energy"}


def _is_known_effect_key(key: str) -> bool:
    if key in _SIMPLE_EFFECT_KEYS:
        return True
    m = _ATTRIBUTE_KEY.match(key)
    if m:
        return m.group(1) in ATTRIBUTE_KEYS
    return bool(_FAME_KEY.match(key) or _RELATIONSHIP_KEY.match(key))


def validate_catalog(items: list, source: str) -> None:
    for item in items:
        for key in item.get("costs", {}):
            if key not in KNOWN_COST_KEYS:
                raise ValueError(f"{source}:{item['catalog_id']!r} has unknown cost key {key!r}")
        for key in item.get("effects", {}):
            if not _is_known_effect_key(key):
                raise ValueError(f"{source}:{item['catalog_id']!r} has unknown effect key {key!r}")
