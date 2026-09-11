"""§5.4 R3 - the server-authoritative outcome table behind FE's dialogue
trees. D23: FE owns the conversation text and branching (dialogue TREES
live in relationships_screen.dart, not here); this table owns only what a
given leaf is WORTH — a client sends dialogue_id + choice_path, never a
delta, so it can't award itself relationship points.

dialogue_id and leaf node ids are ported straight from
relationships_screen.dart's real tree ids (start/r0/r1/r2/r3) so the two
sides describe the same conversation. v1's trees are all single-hop
(start -> one reply), so only choice_path's LAST element is looked up;
a multi-hop tree, when written, would key on the full path instead.

This table currently covers exactly the five trees FE ships today.
Content authors add rows here as new dialogue is written — same pattern
as catalog/training.py etc.

A leaf may also carry `requires` (D42): the kişi levels the player needs
before that reply is available at all. FE learns those from
GET /catalog/dialogue — which serves `requires` and NOTHING else, because
publishing the deltas would both spoil the conversation and undo the
reason this table lives server-side.
"""
from api import config, errors
from catalog import validate_requires

DIALOGUE_RELATIONSHIP = {
    "coach_01": "coach",
    "team_01": "team",
    "media_01": "media",
    "partner_01": "partner",
    "family_01": "family",
}

# leaf node id -> {relationship_delta, attribute_effects}. Node ids and the
# choice they correspond to match relationships_screen.dart's DialogueNode
# ids exactly, e.g. coach_01's 'r0' is "Haklısınız hocam, daha fazla
# paylaşımcı olacağım."
# `requires` (D42) reads as "you need to be this person to say this". The
# v1 thresholds sit just above a fresh career's kişi levels (charisma 7,
# politeness 5, confidence 5, intelligence 6, resourcefulness 2) so the
# locks are visible from day one and open through the kişi training paths.
# INV-32 (asserted below) keeps every tree walkable regardless.
# §6.2/D41 - what a conversation costs from the day. Talking used to be free,
# which made it the one action with no opportunity cost: there was never a
# reason not to call everyone every day, so the relationship scores drifted
# up on their own and the day's budget never entered the decision.
#
# The unit is the day's budget, NOT the calendar. D5 makes a day the tick and
# `game_date` moves only inside T3's advance; pushing the date from R3 would
# mean a conversation could skip a match day. Time passing *within* a day is
# exactly what `day_budget` models (§6.2), so a conversation eats into the day
# the way a training session does.
#
# Per-leaf rather than per-dialogue: hanging up on your family (family_01/r1)
# is a shorter conversation than sitting through an interview. The default
# below covers a leaf that does not name its own.
DIALOGUE_DEFAULT_COSTS = {"time": 45.0, "energy": 4.0}

DIALOGUE_OUTCOMES = {
    "coach_01": {
        # Saying the right thing to a coach who just criticised you is a
        # politeness move, not a confidence one.
        "r0": {"relationship_delta": 3, "attribute_effects": {}, "requires": {"politeness": 6},
               "costs": {"time": 40.0, "energy": 5.0}, "condition": -1},
        "r1": {"relationship_delta": -2, "attribute_effects": {},
               "costs": {"time": 25.0, "energy": 8.0}, "condition": -3},
        # Parking the argument for the right moment — reads the room.
        "r2": {"relationship_delta": 0, "attribute_effects": {}, "requires": {"intelligence": 6},
               "costs": {"time": 20.0, "energy": 2.0}},
    },
    "team_01": {
        "r0": {"relationship_delta": 2, "attribute_effects": {}, "requires": {"confidence": 6}},
        "r1": {"relationship_delta": 0, "attribute_effects": {}},
    },
    "media_01": {
        # Walking into an interview that has transfer questions in it.
        "r0": {"relationship_delta": 3, "attribute_effects": {"charisma": 0.2},
               "requires": {"charisma": 8},
               "costs": {"time": 75.0, "energy": 9.0}, "condition": -2},
        "r1": {"relationship_delta": -3, "attribute_effects": {},
               "costs": {"time": 60.0, "energy": 11.0}, "condition": -3},
        "r2": {"relationship_delta": 1, "attribute_effects": {}},
    },
    "partner_01": {
        "r0": {"relationship_delta": 1, "attribute_effects": {}},
        # Making five minutes appear on a match day.
        "r1": {"relationship_delta": 3, "attribute_effects": {}, "requires": {"resourcefulness": 3},
               "costs": {"time": 90.0, "energy": 3.0}, "condition": 1},
    },
    "family_01": {
        "r0": {"relationship_delta": 4, "attribute_effects": {},
               "costs": {"time": 60.0, "energy": 2.0}, "condition": 2},
        "r1": {"relationship_delta": -2, "attribute_effects": {},
               "costs": {"time": 10.0, "energy": 1.0}},
        "r2": {"relationship_delta": 1, "attribute_effects": {}},
    },
}


def resolve_outcome(dialogue_id: str, choice_path: list) -> dict:
    """Raises invalid_request for an unknown dialogue_id, an empty path, or
    a leaf id this dialogue doesn't have — never guesses."""
    outcomes = DIALOGUE_OUTCOMES.get(dialogue_id)
    if outcomes is None:
        raise errors.invalid_request(f"unknown dialogue_id {dialogue_id!r}")
    if not choice_path:
        raise errors.invalid_request("choice_path must not be empty")
    leaf = choice_path[-1]
    outcome = outcomes.get(leaf)
    if outcome is None:
        raise errors.invalid_request(f"dialogue {dialogue_id!r} has no leaf {leaf!r}")
    return outcome


def costs_for(outcome: dict) -> dict:
    """The leaf's own costs, or the default. Kept here rather than in the
    router so a leaf that forgets to price itself still costs something -
    a free conversation is the bug this replaced."""
    return dict(outcome.get("costs") or DIALOGUE_DEFAULT_COSTS)


def public_catalog() -> list:
    """§5.7 N3 'dialogue' - the FE-facing projection: every leaf's
    `requires`, and deliberately nothing else. Built here rather than in
    the router so the "deltas never leave this module" rule is enforced
    where the deltas live."""
    return [
        {
            "dialogue_id": dialogue_id,
            "relationship_id": DIALOGUE_RELATIONSHIP[dialogue_id],
            "leaves": [
                {"leaf_id": leaf_id, "requires": outcome.get("requires", {})}
                for leaf_id, outcome in leaves.items()
            ],
        }
        for dialogue_id, leaves in DIALOGUE_OUTCOMES.items()
    ]


assert set(DIALOGUE_OUTCOMES.keys()) == set(DIALOGUE_RELATIONSHIP.keys())
for _dialogue_id, _leaves in DIALOGUE_OUTCOMES.items():
    for _leaf_id, _outcome in _leaves.items():
        for _key in _outcome["attribute_effects"]:
            assert _key in config.ATTRIBUTE_KEYS, f"{_dialogue_id}:{_leaf_id} unknown attribute {_key!r}"
        # INV-31, same rule and same message shape as a catalog item's.
        validate_requires(_outcome.get("requires"), f"dialogue:{_dialogue_id}:{_leaf_id}")
    # INV-32: a tree whose every leaf is gated could strand the player in a
    # conversation they can't answer. Checked at import, like INV-28.
    assert any(not _o.get("requires") for _o in _leaves.values()), (
        f"dialogue {_dialogue_id!r} has no ungated leaf (INV-32)"
    )
