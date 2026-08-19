"""§5.6 M2 - mirrors match_engine's own Ek B action catalog and §7.3
resolution/outcome mapping (API_CONTRACT.md), so M2's validation checks
interventions against the same vocabulary the engine itself uses.

Reference: API_CONTRACT.md Ek B (11 actions, resolution + schema columns)
and §7.3 (resolution/outcome mapping table).
"""

# action_key -> schema ('graded': great/good/bad, 'binary': success/failure)
ACTION_SCHEMAS = {
    "finish_power": "graded",
    "finish_finesse": "graded",
    "long_shot": "graded",
    "set_piece": "binary",
    "counter_attack": "graded",
    "tackle_hard": "graded",
    "high_press": "graded",
    "keeper_sweep": "graded",
    "penalty_win": "binary",
    "tactical_sub": "binary",
    "time_waste": "binary",
}

GRADED_OUTCOMES = {"great", "good", "bad"}
BINARY_OUTCOMES = {"success", "failure"}

# D13/D34: the 4 minigame-resolution (shot) actions, and which outcome
# counts as a goal for player_season_stat.goals — the best branch, per
# API_CONTRACT.md §7.3's GOL! -> great (graded) / success (binary) mapping.
MINIGAME_ACTION_KEYS = {"finish_power", "finish_finesse", "long_shot", "set_piece"}
BEST_OUTCOME_BY_SCHEMA = {"graded": "great", "binary": "success"}


def is_goal(action_key: str, outcome_key: str) -> bool:
    if action_key not in MINIGAME_ACTION_KEYS:
        return False
    schema = ACTION_SCHEMAS[action_key]
    return outcome_key == BEST_OUTCOME_BY_SCHEMA[schema]


assert MINIGAME_ACTION_KEYS <= set(ACTION_SCHEMAS.keys())
