"""§12.1 M4 - the pre-match conversation with the coach.

Two things meet here. The relationship *score* (§3.4) is how much the coach
likes you; `CoachTraits.trust` is how far he'll back your judgement over his
own. They move together but not identically, and the difference is the whole
mechanic: agreeing with his plan buys trust cheaply, and trust is what you
spend when you ask for something. A coach can like you and still not play you
where you want.

Until this module, `trust` was dead data - declared in the contract, returned
by R1/R2, and written by nothing. It is now the input `domain/squad.py` reads
when it decides whether you start, which closes the loop:

    talk -> trust -> selection -> match -> relationship -> talk

Costs come out of the day's budget (§6.2/D41), the same way a dialogue does
since §5.4's R3 stopped being free.
"""
import random
import sqlite3

from api import config, errors
from domain import day_budget, instructions, relationships
from worlddata.positions import (
    POSITIONS, get_role, instruction_for_role, position_group_for_role, roles_for_position,
)

COACH_RELATIONSHIP_ID = "coach"

# Accepting the coach's plan is cheap and buys trust; rejecting it costs both
# numbers but is the only way to keep your own reading of the game. The
# asymmetry is deliberate - agreement should be the easy road, not the free
# one, and a player who nods at everything ends up with a high-trust coach
# and no say in how they're used.
#
# `score` is the relationship (§3.4), `trust` is CoachTraits. Philosophy is
# the bigger commitment of the two topics, so it moves both further than
# style does.
TOPICS = {
    "philosophy_accept": {
        "score": 2, "trust": 6.0, "condition": 0,
        "costs": {"time": 20.0, "energy": 2.0},
    },
    "philosophy_reject": {
        "score": -3, "trust": -8.0, "condition": -2,
        "costs": {"time": 30.0, "energy": 6.0},
    },
    "style_accept": {
        "score": 1, "trust": 4.0, "condition": 0,
        "costs": {"time": 15.0, "energy": 2.0},
    },
    "style_reject": {
        "score": -2, "trust": -6.0, "condition": -1,
        "costs": {"time": 25.0, "energy": 5.0},
    },
    # The three requests resolve against a roll rather than applying a fixed
    # delta - see _resolve_request.
    "request_position": {"costs": {"time": 35.0, "energy": 4.0}, "condition": -1},
    "request_role": {"costs": {"time": 30.0, "energy": 3.0}, "condition": -1},
    # §12.10 - cheapest of the three: it asks for less than the other two
    # (not to be moved, only told to play today's match differently) and its
    # effect expires at full time, unlike a role or position change. That is
    # priced with the day-budget discount rather than a friendlier roll -
    # _success_chance takes no per-topic modifier, so a player who wants
    # better odds has to raise trust or score the same way any other
    # request-topic does.
    "request_instruction": {"costs": {"time": 25.0, "energy": 3.0}, "condition": -1},
}

REQUEST_TOPICS = ("request_position", "request_role", "request_instruction")

# Granted: you spent real capital and he moved his plan for you. Refused: it
# stings but costs less, because being told no is not the same as being owed
# a favour. Neither outcome is free - asking at all is a demand.
GRANTED_TRUST = -5.0
GRANTED_SCORE = 0
REFUSED_TRUST = -2.0
REFUSED_SCORE = -2


def _success_chance(trust: float, score: int) -> float:
    """Trust weighs roughly twice the bare relationship: liking you is not
    the same as believing you read the game better than he does.

    Floored at 0.05 and capped at 0.90 so neither end is a certainty - a
    coach you have alienated can still say yes on a good day, and one who
    adores you can still have a shape he will not break."""
    raw = 0.15 + trust / 250.0 + score / 400.0
    return max(0.05, min(0.90, raw))


def _roll(seed: int, fixture_id: str, topic: str) -> float:
    """Seeded on (career, fixture, topic), so the same request on the same
    match always resolves the same way (INV-7). That also means a refused
    request cannot be re-rolled by retrying - and it does not need to be
    guarded against separately, because the once-per-fixture check below
    already blocks a second attempt."""
    return random.Random(f"{seed}:coach_talk:{fixture_id}:{topic}").random()


def already_talked(conn: sqlite3.Connection, career_id: str, fixture_id: str) -> bool:
    """One conversation per match. Recorded in relationship_event rather
    than a new table: apply_delta already writes a row per talk with a
    reason we control, so the audit trail doubles as the lock and there is
    no second place for the two to disagree."""
    return conn.execute(
        "SELECT 1 FROM relationship_event WHERE career_id = ? AND relationship_id = ? "
        "AND reason LIKE ? LIMIT 1",
        (career_id, COACH_RELATIONSHIP_ID, f"coach_talk:{fixture_id}:%"),
    ).fetchone() is not None


def _validate_target(conn: sqlite3.Connection, career_id: str, fixture_id: str, topic: str, value):
    """A request must name something that exists, and a role must belong to
    the position the player actually holds - asking to be a Regista while
    playing at centre-back is not a conversation the coach can have."""
    if topic not in REQUEST_TOPICS:
        if value is not None:
            raise errors.invalid_request(f"topic {topic!r} takes no value")
        return None

    if not value:
        raise errors.invalid_request(f"topic {topic!r} requires a value")

    if topic == "request_instruction":
        if value not in instructions.INSTRUCTIONS:
            raise errors.invalid_request(f"unknown instruction {value!r}")
        # §12.10 - `peek`, not `instruction_for`: this runs BEFORE
        # day_budget.spend() (INV-4), and instruction_for would freeze a
        # default here as a side effect of a request that might still be
        # refused.
        if value == instructions.peek(conn, career_id, fixture_id):
            raise errors.invalid_request("already playing that way")
        return value

    player = conn.execute(
        "SELECT position, role FROM player WHERE career_id = ? AND player_id = ?",
        (career_id, config.USER_PLAYER_ID),
    ).fetchone()

    if topic == "request_position":
        if value not in POSITIONS:
            raise errors.invalid_request(f"unknown position {value!r}")
        if value == player["position"]:
            raise errors.invalid_request("already playing that position")
        return value

    role = get_role(value)
    if role is None:
        raise errors.invalid_request(f"unknown role_id {value!r}")
    if role["position"] != player["position"]:
        raise errors.invalid_request(
            f"role {value!r} belongs to {role['position']!r}, not {player['position']!r}"
        )
    if value == player["role"]:
        raise errors.invalid_request("already playing that role")
    return value


def _current_role(conn: sqlite3.Connection, career_id: str):
    """The player's role_id right now. `instructions.py` keeps its own copy of
    this read for the same reason - it is one column, and importing a private
    helper across modules to save three lines is the worse trade."""
    row = conn.execute(
        "SELECT role FROM player WHERE career_id = ? AND player_id = ?",
        (career_id, config.USER_PLAYER_ID),
    ).fetchone()
    return row["role"] if row is not None else None


def _apply_request(
    conn: sqlite3.Connection, career_id: str, fixture_id: str, topic: str, value: str,
) -> tuple:
    """Writes the granted change and reports it.

    Returns `(player_fields, instruction)`: `player_fields` is
    `{"position", "role"}` for request_role/request_position, `None` for
    request_instruction; `instruction` is the new frozen §12.10 value.

    A position change can orphan the role - roles belong to exactly one
    position (worlddata/positions.py) - so the role moves with it, to the
    first role of the new position. Silently keeping an impossible pairing
    would break role_belongs_to_position for every later reader; picking for
    the player is the lesser surprise, and the response says so.

    A granted role/position change also re-derives the coach's instruction
    from the new role (§12.10): agreeing to play you as a Mezzala and still
    expecting you to sit deep would be a contradiction the coach himself
    created, not a state the frozen instruction should be allowed to keep.
    """
    if topic == "request_instruction":
        instructions.set_instruction(conn, career_id, fixture_id, value)
        return None, value

    if topic == "request_role":
        conn.execute(
            "UPDATE player SET role = ? WHERE career_id = ? AND player_id = ?",
            (value, career_id, config.USER_PLAYER_ID),
        )
    else:
        default_role = roles_for_position(value)[0]["role_id"]
        conn.execute(
            "UPDATE player SET position = ?, role = ? WHERE career_id = ? AND player_id = ?",
            (value, default_role, career_id, config.USER_PLAYER_ID),
        )

    row = conn.execute(
        "SELECT position, role FROM player WHERE career_id = ? AND player_id = ?",
        (career_id, config.USER_PLAYER_ID),
    ).fetchone()
    new_instruction = instruction_for_role(row["role"])
    instructions.set_instruction(conn, career_id, fixture_id, new_instruction)
    return {"position": row["position"], "role": row["role"]}, new_instruction


def talk(
    conn: sqlite3.Connection,
    career_id: str,
    fixture_id: str,
    topic: str,
    value,
    seed: int,
    happened_at: str,
) -> dict:
    """One pre-match conversation. Does not commit - M4's handler owns the
    transaction (INV-3), so a 409 from the budget leaves nothing behind."""
    spec = TOPICS.get(topic)
    if spec is None:
        raise errors.invalid_request(f"unknown topic {topic!r}")

    target = _validate_target(conn, career_id, fixture_id, topic, value)

    # After validation, before the first write: a rejected request must not
    # have cost the day (INV-4).
    day_budget.spend(conn, career_id, spec["costs"])

    granted = None
    player_after = None
    instruction_after = None

    if topic in REQUEST_TOPICS:
        traits = relationships.get_traits(conn, career_id, COACH_RELATIONSHIP_ID)
        score = relationships.get_score(conn, career_id, COACH_RELATIONSHIP_ID)
        chance = _success_chance(traits["trust"], score)
        granted = _roll(seed, fixture_id, topic) < chance
        score_delta = GRANTED_SCORE if granted else REFUSED_SCORE
        trust_delta = GRANTED_TRUST if granted else REFUSED_TRUST
        if granted:
            player_after, instruction_after = _apply_request(
                conn, career_id, fixture_id, topic, target
            )
    else:
        score_delta = spec["score"]
        trust_delta = spec["trust"]

    reason = f"coach_talk:{fixture_id}:{topic}"
    relationship_change = relationships.apply_delta(
        conn, career_id, COACH_RELATIONSHIP_ID, score_delta, reason, happened_at
    )
    trait_changes = relationships.apply_trait_delta(
        conn, career_id, COACH_RELATIONSHIP_ID, trust=trust_delta
    )

    return {
        "topic": topic,
        "granted": granted,
        "relationship_change": relationship_change,
        "trait_changes": trait_changes,
        "condition_delta": spec.get("condition", 0),
        "player": player_after,
        # §12.10 - the instruction as it stands after this conversation,
        # whether a granted request_instruction changed it directly or a
        # granted request_role/request_position re-derived it from the new
        # role. `None` for every other outcome (a philosophy/style topic, or
        # any refused request). A separate key rather than folded into
        # "player" so a client only interested in the instruction doesn't
        # need to know that a role/position change can carry one too.
        "coach_instruction": (
            {
                "focus": instructions.focus_wire(instruction_after),
                "label": instructions.label(instruction_after),
                # §12.14 - reported even when this conversation did not touch
                # the role, so a client can take the block as a whole rather
                # than deciding per field whether to keep its old value. A
                # granted request_role/request_position is exactly when it
                # DOES change, and that is also when M1's copy is already
                # stale in the client's hands.
                "position_group": position_group_for_role(
                    player_after["role"] if player_after else _current_role(conn, career_id)
                ),
            }
            if instruction_after is not None
            else None
        ),
    }
