"""§5.6/§5.2 - the two derived-value functions M1 and P1 lean on.

Both are deliberately small seams: whatever CONTRACT.md's open decisions
land on (AÇIK-8), the callers (routers, later commits) never change —
only the body of these functions does.
"""
from typing import Optional


def compute_team_rating(club_ratings: dict) -> dict:
    """§5.6 M1 - turns a team's stored (attack, midfield, defense,
    goalkeeper) into what actually goes in engine_payload.teams.{side}.

    D37: there is no bond. The user's attributes never enter this
    function and never move a single one of these four numbers (INV-26) -
    the only channel planned for player skill to reach the match is a
    future minigame-difficulty hook, and that's explicitly out of scope
    for v1 too. So this is identity by contract, not by omission.
    """
    return {
        "attack": club_ratings["attack"],
        "midfield": club_ratings["midfield"],
        "defense": club_ratings["defense"],
        "goalkeeper": club_ratings["goalkeeper"],
    }


def compute_market_value(
    attributes: dict,
    age: int,
    contract_days_remaining: int,
    fame: float,
) -> Optional[int]:
    """§5.2 P1 market_value.current - ⟦AÇIK-8⟧, not yet decided.

    Inputs are already the ones CONTRACT.md names as likely (11 attributes,
    age, contract length, fame) so the call site won't need to change
    shape once a formula is chosen. D32 already rules out one direction:
    age must not be a subtractive term - "yaş bir azaltıcı değildir" - so
    whatever lands here, a decline can only come from poor form, not age
    alone.

    Returns None until AÇIK-8 is settled; callers fall back to the most
    recent player_value_history snapshot rather than inventing a number.
    """
    return None
