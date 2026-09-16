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

from api.config import ATTRIBUTE_KEYS, TACTIC_KEYS

_ATTRIBUTE_KEY = re.compile(r"^attribute:(\w+)$")
_TACTIC_KEY = re.compile(r"^tactic:(\w+)$")
_FAME_KEY = re.compile(r"^fame:(\w+)$")
_RELATIONSHIP_KEY = re.compile(r"^relationship:(\w+)$")
_SIMPLE_EFFECT_KEYS = {"condition", "energy", "money"}

# D41 - the only cost dimensions any catalog item may spend from
# day_budget. ⟦AÇIK-5⟧ owns the actual resource list; this is deliberately
# already wider than what §6.2's example uses (time, energy) in case a
# third dimension is added later without a code change here.
KNOWN_COST_KEYS = {"time", "energy"}

# §6.3/§6.6/§12.12 - the keys the DAY LOOP applies once per advanced day, as
# opposed to `effects`, which a single action applies once. Deliberately
# NARROWER than _is_known_effect_key's space: a `money` key sitting in a shop
# item doing nothing every day is exactly the dead row INV-28 exists to
# reject. `energy`/`fame:overall` joined `condition` in the same commit that
# taught domain/daytime.py to apply them (catalog/shop.py's
# daily_energy_bonus/daily_fame_bonus) - widen this set only alongside that.
KNOWN_DAILY_EFFECT_KEYS = {"condition", "energy", "fame:overall"}

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
    m = _TACTIC_KEY.match(key)
    if m:
        return m.group(1) in TACTIC_KEYS
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


def validate_daily_effects(daily: dict, where: str) -> None:
    """INV-28's sibling for the passive, per-day effect map an owned item may
    carry. Negative values are rejected on purpose: a daily condition DRAIN
    fights INV-10's clamp in a way no UI can explain (the bar would sink
    toward zero with nothing the player did), so if that mechanic is ever
    wanted it should arrive as its own deliberate widening, not by someone
    typing a minus sign."""
    for key, value in (daily or {}).items():
        if key not in KNOWN_DAILY_EFFECT_KEYS:
            raise ValueError(f"{where} has unknown daily effect key {key!r}")
        # bool is an int subclass; True would silently read as +1 a day.
        if not isinstance(value, (int, float)) or isinstance(value, bool):
            raise ValueError(f"{where} daily effect {key!r} is not a number: {value!r}")
        if value < 0:
            raise ValueError(f"{where} daily effect {key!r} is negative: {value!r}")


def validate_catalog(items: list, source: str) -> None:
    for item in items:
        for key in item.get("costs", {}):
            if key not in KNOWN_COST_KEYS:
                raise ValueError(f"{source}:{item['catalog_id']!r} has unknown cost key {key!r}")
        for key in item.get("effects", {}):
            if not _is_known_effect_key(key):
                raise ValueError(f"{source}:{item['catalog_id']!r} has unknown effect key {key!r}")
        validate_daily_effects(item.get("daily_effects"), f"{source}:{item['catalog_id']!r}")
        validate_requires(item.get("requires"), f"{source}:{item['catalog_id']!r}")
