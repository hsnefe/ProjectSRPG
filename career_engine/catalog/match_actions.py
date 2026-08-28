"""§5.6 M2 - mirrors match_engine's own Ek B action catalog and §7.3
resolution/outcome mapping (API_CONTRACT.md), so M2's validation checks
interventions against the same vocabulary the engine itself uses.

Reference: API_CONTRACT.md Ek B (11 actions, resolution + schema columns)
and §7.3 (resolution/outcome mapping table).
"""

# action_key -> schema ('graded': great/good/bad, 'graded4': great/asist/good/bad,
# 'binary': success/failure). The 4 minigame-resolved ATTACK actions are
# graded4 (match_engine/dev_actions.py's graded4() - v1.4 split the best
# tier into scoring it yourself vs. squaring it for a teammate who
# finishes). tackle_hard/high_press/keeper_sweep stay plain 3-tier graded;
# set_piece/penalty_win/tactical_sub/time_waste stay binary.
ACTION_SCHEMAS = {
    "finish_power": "graded4",
    "finish_finesse": "graded4",
    "long_shot": "graded4",
    "counter_attack": "graded4",
    "set_piece": "binary",
    "tackle_hard": "graded",
    "high_press": "graded",
    "keeper_sweep": "graded",
    "penalty_win": "binary",
    "tactical_sub": "binary",
    "time_waste": "binary",
}

GRADED_OUTCOMES = {"great", "good", "bad"}
GRADED4_OUTCOMES = {"great", "asist", "good", "bad"}
BINARY_OUTCOMES = {"success", "failure"}

OUTCOME_SETS = {
    "graded": GRADED_OUTCOMES,
    "graded4": GRADED4_OUTCOMES,
    "binary": BINARY_OUTCOMES,
}

# D13/D34 - which (action_key, outcome_key) pair is actually a goal. Kept as
# a direct, resolution-independent lookup rather than derived from "is this
# a minigame action" crossed with "best outcome for its schema" - that
# indirection used to silently drop counter_attack (not in the old
# minigame-action set) and penalty_win (whose best outcome is 'success', a
# binary key the old lookup never mapped to a goal). Cross-checked against
# match_engine/dev_actions.py's real Branch content: only these six actions'
# best branch actually injects a Goal event.
GOAL_OUTCOMES = {
    "finish_power": "great",
    "finish_finesse": "great",
    "long_shot": "great",
    "counter_attack": "great",
    "set_piece": "success",
    "penalty_win": "success",
}


def is_goal(action_key: str, outcome_key: str) -> bool:
    return GOAL_OUTCOMES.get(action_key) == outcome_key


def is_assist(action_key: str, outcome_key: str) -> bool:
    """graded4's second-best branch (dev_actions.py's graded4(asist=...)):
    the player set up a teammate who scored, instead of scoring themself.
    Only the 4 graded4 actions can ever produce this outcome key."""
    return ACTION_SCHEMAS.get(action_key) == "graded4" and outcome_key == "asist"


assert set(GOAL_OUTCOMES) <= set(ACTION_SCHEMAS)
