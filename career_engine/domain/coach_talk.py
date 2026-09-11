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
from domain import day_budget, relationships
from worlddata.positions import POSITIONS, get_role, roles_for_position

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
    # The two requests resolve against a roll rather than applying a fixed
    # delta - see _resolve_request.
    "request_position": {"costs": {"time": 35.0, "energy": 4.0}, "condition": -1},
    "request_role": {"costs": {"time": 30.0, "energy": 3.0}, "condition": -1},
}

REQUEST_TOPICS = ("request_position", "request_role")

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


def _validate_target(conn: sqlite3.Connection, career_id: str, topic: str, value):
    """A request must name something that exists, and a role must belong to
    the position the player actually holds - asking to be a Regista while
    playing at centre-back is not a conversation the coach can have."""
    if topic not in REQUEST_TOPICS:
        if value is not None:
            raise errors.invalid_request(f"topic {topic!r} takes no value")
        return None

    if not value:
        raise errors.invalid_request(f"topic {topic!r} requires a value")

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


def _apply_request(conn: sqlite3.Connection, career_id: str, topic: str, value: str) -> dict:
    """Writes the granted change and reports what the player looks like
    afterwards.

    A position change can orphan the role - roles belong to exactly one
    position (worlddata/positions.py) - so the role moves with it, to the
    first role of the new position. Silently keeping an impossible pairing
    would break role_belongs_to_position for every later reader; picking for
    the player is the lesser surprise, and the response says so.
    """
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
    return {"position": row["position"], "role": row["role"]}


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

    target = _validate_target(conn, career_id, topic, value)

    # After validation, before the first write: a rejected request must not
    # have cost the day (INV-4).
    day_budget.spend(conn, career_id, spec["costs"])

    granted = None
    player_after = None

    if topic in REQUEST_TOPICS:
        traits = relationships.get_traits(conn, career_id, COACH_RELATIONSHIP_ID)
        score = relationships.get_score(conn, career_id, COACH_RELATIONSHIP_ID)
        chance = _success_chance(traits["trust"], score)
        granted = _roll(seed, fixture_id, topic) < chance
        score_delta = GRANTED_SCORE if granted else REFUSED_SCORE
        trust_delta = GRANTED_TRUST if granted else REFUSED_TRUST
        if granted:
            player_after = _apply_request(conn, career_id, topic, target)
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
    }
