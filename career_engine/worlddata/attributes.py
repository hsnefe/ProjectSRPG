"""§5.2 P1 - the starting player_attribute values for a brand-new career.

Before career creation took a role, this was one flat dict every career got
regardless of what the player picked. It now has three tiers, because §2 of
the career-creation spec treats them differently:

  * ROLE_SKILL_KEYS (shooting/passing/dribbling/tackling) start at
    BASE_SKILL_VALUE — the "taban değer" — and the chosen role adds
    ROLE_BONUS_PER_SLOT per slot it spends on that key. A role that spends
    both slots on one key (Stoper -> tackling, tackling) therefore starts
    +4 there rather than +2 on two keys. These four are also the only keys
    the Şut/Pas/Müdahale/Dribling exams can move afterwards (catalog/skill_exams.py);
    dribbling has no exam, so a role bonus is the only way it starts above
    base.
  * FIXED_STARTING_ATTRIBUTES - condition, strength, flexibility. §2 says
    Güç and Esneklik start from a fixed value and the exams must not touch
    them, so they are plain constants with no role or exam path in.
  * PERSONALITY_ATTRIBUTES - the five kişi keys. The spec says nothing about
    them, so they keep the values they have always had (ported from FE's
    relationships_radar_screen.dart) rather than being silently reset —
    dialogue and relationship checks already read them.

Every number here is meant to be edited. Nothing downstream hardcodes an
attribute's starting value; starting_attributes() is the only producer.
"""
from api.config import ATTRIBUTE_KEYS, STARTING_CONDITION
from worlddata.positions import get_role

# The four saha skills a position/role can specialise in. Kept in sync with
# worlddata/positions.py's `attributes` slots by the assert at the bottom.
ROLE_SKILL_KEYS = ("shooting", "passing", "dribbling", "tackling")

# "Taban değer" — where a skill sits before the role bonus and any exam.
BASE_SKILL_VALUE = 20.0

# §2: "taban değere +2 puan eklenmeli", per slot the role spends.
ROLE_BONUS_PER_SLOT = 2.0

# §2/§4: condition mirrors career_state.condition's start (it is that value's
# ceiling, INV-10); strength and flexibility are fixed and exam-proof.
FIXED_STARTING_ATTRIBUTES = {
    "condition": float(STARTING_CONDITION),
    "strength": 30.0,
    "flexibility": 30.0,
}

# kişi ailesi — unchanged from the pre-role catalog on purpose.
PERSONALITY_ATTRIBUTES = {
    "charisma": 74.0,
    "politeness": 58.0,
    "confidence": 51.0,
    "intelligence": 63.0,
    "resourcefulness": 29.0,
}


def starting_attributes(role_id: str) -> dict:
    """The full 12-key attribute map a career starts with, before any skill
    exam. Raises KeyError for an unknown role_id — callers validate the role
    against worlddata/positions.py first, so reaching here with a bad id is a
    programming error, not user input."""
    role = get_role(role_id)
    if role is None:
        raise KeyError(f"unknown role_id {role_id!r}")

    values = dict(PERSONALITY_ATTRIBUTES)
    values.update(FIXED_STARTING_ATTRIBUTES)
    for key in ROLE_SKILL_KEYS:
        values[key] = BASE_SKILL_VALUE
    for key in role["attributes"]:
        values[key] += ROLE_BONUS_PER_SLOT
    return values


assert set(ROLE_SKILL_KEYS).isdisjoint(FIXED_STARTING_ATTRIBUTES)
assert set(ROLE_SKILL_KEYS).isdisjoint(PERSONALITY_ATTRIBUTES)
assert (
    set(ROLE_SKILL_KEYS) | set(FIXED_STARTING_ATTRIBUTES) | set(PERSONALITY_ATTRIBUTES)
) == set(ATTRIBUTE_KEYS), "starting attributes must cover exactly ATTRIBUTE_KEYS"

# A role may only specialise in a saha skill — catches a typo'd or non-skill
# attribute_key in worlddata/positions.py at import time (INV-21's spirit).
from worlddata.positions import ROLES as _ROLES  # noqa: E402  (cycle-free: positions imports nothing here)

assert all(
    key in ROLE_SKILL_KEYS for role in _ROLES for key in role["attributes"]
), "a role may only boost one of ROLE_SKILL_KEYS"
