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

# D43 - `requires` values are attribute LEVELS, not raw values. The bounds
# mirror domain.attributes.level()'s range exactly; a threshold of 11 could
# never be cleared, so it is a typo, not a very hard gate.
MIN_REQUIREMENT_LEVEL = 0
MAX_REQUIREMENT_LEVEL = 10


def _is_known_effect_key(key: str) -> bool:
    if key in _SIMPLE_EFFECT_KEYS:
        return True
    m = _ATTRIBUTE_KEY.match(key)
    if m:
        return m.group(1) in ATTRIBUTE_KEYS
    return bool(_FAME_KEY.match(key) or _RELATIONSHIP_KEY.match(key))


def validate_requires(requires: dict, where: str) -> None:
    """INV-31, INV-28's sibling - a `requires` map's keys are attribute keys
    and its values are integer levels in range. Shared with catalog/dialogue.py,
    whose leaves carry the same map but aren't catalog items."""
    for key, level in (requires or {}).items():
        if key not in ATTRIBUTE_KEYS:
            raise ValueError(f"{where} requires unknown attribute {key!r}")
        # bool is an int subclass; True would silently read as level 1.
        if not isinstance(level, int) or isinstance(level, bool):
            raise ValueError(f"{where} requires {key!r} at a non-integer level {level!r}")
        if not MIN_REQUIREMENT_LEVEL <= level <= MAX_REQUIREMENT_LEVEL:
            raise ValueError(
                f"{where} requires {key!r} at level {level}, outside "
                f"{MIN_REQUIREMENT_LEVEL}-{MAX_REQUIREMENT_LEVEL}"
            )


def validate_catalog(items: list, source: str) -> None:
    for item in items:
        for key in item.get("costs", {}):
            if key not in KNOWN_COST_KEYS:
                raise ValueError(f"{source}:{item['catalog_id']!r} has unknown cost key {key!r}")
        for key in item.get("effects", {}):
            if not _is_known_effect_key(key):
                raise ValueError(f"{source}:{item['catalog_id']!r} has unknown effect key {key!r}")
        validate_requires(item.get("requires"), f"{source}:{item['catalog_id']!r}")
