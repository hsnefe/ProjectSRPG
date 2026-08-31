"""Content the player DISCOVERS, as opposed to catalog/, which is content the
player BROWSES.

The split is a spoiler rule, not an architectural one. `catalog/` is served
in bulk by N3 because knowing which training items exist is part of choosing
between them. Everything in here is drawn from rather than listed: serving
the pool would give away what hasn't happened yet, so only the single
generated instance is ever sent to FE.

Like catalog/, validation happens at IMPORT (INV-28): a typo in an effect key
fails the process rather than producing a template that silently never fires.
"""
from api.config import RELATIONSHIP_KINDS
from catalog import (
    KNOWN_COST_KEYS,
    _is_known_effect_key,
    validate_requires,
)

_BRANCHES = ("accept", "decline")


def _validate_branch(branch: dict, where: str) -> None:
    if not isinstance(branch, dict):
        raise ValueError(f"{where} is not a mapping")

    delta = branch.get("relationship_delta")
    # bool is an int subclass; True would silently read as +1.
    if not isinstance(delta, int) or isinstance(delta, bool):
        raise ValueError(f"{where} relationship_delta is not an integer: {delta!r}")
    if not -100 <= delta <= 100:
        raise ValueError(f"{where} relationship_delta {delta} is outside -100..100")

    for key in branch.get("effects", {}):
        if not _is_known_effect_key(key):
            raise ValueError(f"{where} has unknown effect key {key!r}")


def validate_social_offers(templates: list) -> None:
    """§5.4 R4-R6 - every field the day loop or an endpoint will read,
    checked once at import.

    Both branches are required even when one of them does nothing: an offer
    with no `decline` would be an offer the player cannot refuse, and INV-40
    (declining never fails) is the escape hatch that keeps a mandatory answer
    from being able to wedge a career.
    """
    for template in templates:
        template_id = template.get("template_id")
        if not template_id:
            raise ValueError(f"social offer with no template_id: {template!r}")
        where = f"social_offer:{template_id!r}"

        if template.get("relationship_id") not in RELATIONSHIP_KINDS:
            raise ValueError(
                f"{where} names unknown relationship {template.get('relationship_id')!r}"
            )

        for field in ("title", "body", "accept_label", "decline_label"):
            if not isinstance(template.get(field), str) or not template[field].strip():
                raise ValueError(f"{where} has no {field}")

        weight = template.get("weight")
        if not isinstance(weight, int) or isinstance(weight, bool) or weight < 1:
            raise ValueError(f"{where} weight is not a positive integer: {weight!r}")

        cooldown = template.get("cooldown_days")
        if not isinstance(cooldown, int) or isinstance(cooldown, bool) or cooldown < 0:
            raise ValueError(f"{where} cooldown_days is not a non-negative integer: {cooldown!r}")

        low, high = template.get("min_score"), template.get("max_score")
        for name, value in (("min_score", low), ("max_score", high)):
            if not isinstance(value, int) or isinstance(value, bool) or not 0 <= value <= 100:
                raise ValueError(f"{where} {name} is not a 0-100 integer: {value!r}")
        if low > high:
            raise ValueError(f"{where} has min_score {low} above max_score {high}")

        for branch in _BRANCHES:
            if branch not in template:
                raise ValueError(f"{where} has no {branch!r} branch")
            _validate_branch(template[branch], f"{where}.{branch}")

        for key in template.get("costs", {}):
            if key not in KNOWN_COST_KEYS:
                raise ValueError(f"{where} has unknown cost key {key!r}")

        validate_requires(template.get("requires"), where)
