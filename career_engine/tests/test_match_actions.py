"""catalog/match_actions.py - mirrors match_engine's v1.4 catalog (11
actions, 4 of them graded4 with an asist tier). Regression coverage for the
bug where a stale catalog silently dropped counter_attack/penalty_win goals
and 422'd on any "asist" outcome (§5.6 M2)."""
from catalog.match_actions import (
    ACTION_SCHEMAS,
    GOAL_OUTCOMES,
    OUTCOME_SETS,
    is_assist,
    is_goal,
)


def test_graded4_actions_accept_asist_outcome():
    for key in ("finish_power", "finish_finesse", "long_shot", "counter_attack"):
        assert ACTION_SCHEMAS[key] == "graded4"
        assert "asist" in OUTCOME_SETS[ACTION_SCHEMAS[key]]


def test_is_goal_credits_counter_attack_and_penalty_win():
    """The two cases the old MINIGAME_ACTION_KEYS-based lookup silently
    dropped: counter_attack wasn't in that set at all, and penalty_win's
    best outcome ('success') was never mapped to a goal."""
    assert is_goal("counter_attack", "great") is True
    assert is_goal("penalty_win", "success") is True


def test_is_goal_true_for_every_documented_goal_outcome():
    for action_key, outcome_key in GOAL_OUTCOMES.items():
        assert is_goal(action_key, outcome_key) is True


def test_is_goal_false_for_asist_and_non_goal_actions():
    assert is_goal("finish_power", "asist") is False
    assert is_goal("tackle_hard", "great") is False
    assert is_goal("high_press", "great") is False
    assert is_goal("keeper_sweep", "great") is False
    assert is_goal("tactical_sub", "success") is False
    assert is_goal("time_waste", "success") is False


def test_is_goal_false_for_unknown_action():
    assert is_goal("bicycle_kick", "great") is False


def test_is_assist_only_for_graded4_asist():
    for key in ("finish_power", "finish_finesse", "long_shot", "counter_attack"):
        assert is_assist(key, "asist") is True
        assert is_assist(key, "great") is False

    # graded (3-tier) and binary actions have no "asist" outcome key to begin
    # with - the schema guard matters here, not just the string comparison.
    assert is_assist("tackle_hard", "great") is False
    assert is_assist("set_piece", "success") is False
