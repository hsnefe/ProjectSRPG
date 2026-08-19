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
"""
from api import config, errors

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
DIALOGUE_OUTCOMES = {
    "coach_01": {
        "r0": {"relationship_delta": 3, "attribute_effects": {}},
        "r1": {"relationship_delta": -2, "attribute_effects": {}},
        "r2": {"relationship_delta": 0, "attribute_effects": {}},
    },
    "team_01": {
        "r0": {"relationship_delta": 2, "attribute_effects": {}},
        "r1": {"relationship_delta": 0, "attribute_effects": {}},
    },
    "media_01": {
        "r0": {"relationship_delta": 3, "attribute_effects": {"charisma": 0.2}},
        "r1": {"relationship_delta": -3, "attribute_effects": {}},
        "r2": {"relationship_delta": 1, "attribute_effects": {}},
    },
    "partner_01": {
        "r0": {"relationship_delta": 1, "attribute_effects": {}},
        "r1": {"relationship_delta": 3, "attribute_effects": {}},
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


assert set(DIALOGUE_OUTCOMES.keys()) == set(DIALOGUE_RELATIONSHIP.keys())
for _dialogue_id, _leaves in DIALOGUE_OUTCOMES.items():
    for _leaf_id, _outcome in _leaves.items():
        for _key in _outcome["attribute_effects"]:
            assert _key in config.ATTRIBUTE_KEYS, f"{_dialogue_id}:{_leaf_id} unknown attribute {_key!r}"
