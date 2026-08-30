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
DIALOGUE_OUTCOMES = {
    "coach_01": {
        # Saying the right thing to a coach who just criticised you is a
        # politeness move, not a confidence one.
        "r0": {"relationship_delta": 3, "attribute_effects": {}, "requires": {"politeness": 6}},
        "r1": {"relationship_delta": -2, "attribute_effects": {}},
        # Parking the argument for the right moment — reads the room.
        "r2": {"relationship_delta": 0, "attribute_effects": {}, "requires": {"intelligence": 6}},
    },
    "team_01": {
        "r0": {"relationship_delta": 2, "attribute_effects": {}, "requires": {"confidence": 6}},
        "r1": {"relationship_delta": 0, "attribute_effects": {}},
    },
    "media_01": {
        # Walking into an interview that has transfer questions in it.
        "r0": {"relationship_delta": 3, "attribute_effects": {"charisma": 0.2},
               "requires": {"charisma": 8}},
        "r1": {"relationship_delta": -3, "attribute_effects": {}},
        "r2": {"relationship_delta": 1, "attribute_effects": {}},
    },
    "partner_01": {
        "r0": {"relationship_delta": 1, "attribute_effects": {}},
        # Making five minutes appear on a match day.
        "r1": {"relationship_delta": 3, "attribute_effects": {}, "requires": {"resourcefulness": 3}},
    },
    "family_01": {
        "r0": {"relationship_delta": 4, "attribute_effects": {}},
        "r1": {"relationship_delta": -2, "attribute_effects": {}},
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
