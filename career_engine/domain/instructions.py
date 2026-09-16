"""§12.10 - the coach's expectation for how the user should play this match.

`CoachTraits.tactical_fit` (domain/relationships.py) was dead data until this
module: declared in §3.4, returned by R1/R2, written by nothing - the exact
state `trust` was in before §12.1 closed the same gap for coach talk. This
module is the other half of `CoachTraits`: it gives the coach something to
compare `tactical_fit` against, and match.py's `_match_relationship_deltas`
gives it something to move.

Mirrors domain/squad.py's shape almost exactly - lazy and sticky, one column
on `fixture`, decided the first time anything asks - with two differences:

- No jitter. Squad selection is a judgement call with room for surprise;
  a plan the coach announces is not - a plan that changed at random between
  two reads would make a granted `request_instruction` (§12.1) unreadable.
- Not permanently frozen the way INV-44 freezes squad status. A granted M4
  `request_instruction`, or a granted `request_role`/`request_position` that
  changes which role the player holds, overwrites it (INV-54).
"""
import sqlite3
from typing import Optional

from api import config
from worlddata.positions import INSTRUCTIONS, instruction_for_role

ANY = "any"

_LABELS = {
    "attack": "Hücum",
    "defend": "Savunma",
    "tactical": "Taktik",
    ANY: "Farketmez",
}


def _player_role(conn: sqlite3.Connection, career_id: str) -> Optional[str]:
    row = conn.execute(
        "SELECT role FROM player WHERE career_id = ? AND player_id = ?",
        (career_id, config.USER_PLAYER_ID),
    ).fetchone()
    return row["role"] if row is not None else None


def _decide(conn: sqlite3.Connection, career_id: str) -> str:
    """Derived from the player's CURRENT role - no seed, no jitter (see
    module docstring). A career with no role yet (shouldn't happen past
    onboarding, but `instruction_for_role` already degrades to "any" for
    an unrecognised role_id, so a `None` role does too)."""
    return instruction_for_role(_player_role(conn, career_id))


def peek(conn: sqlite3.Connection, career_id: str, fixture_id: str) -> str:
    """The instruction WITHOUT freezing it - reads the frozen value if one
    exists, otherwise computes the would-be default without writing it.

    Exists for `coach_talk.talk()`'s `request_instruction` validation gate,
    which runs BEFORE `day_budget.spend()`: `instruction_for` would freeze a
    default on every attempt, including a refused one, which would silently
    break INV-4 (a refused request must not have cost the day — and freezing
    the instruction here would be a real, if easy to miss, side effect of a
    request that's about to be rejected)."""
    row = conn.execute(
        "SELECT user_match_instruction FROM fixture WHERE career_id = ? AND fixture_id = ?",
        (career_id, fixture_id),
    ).fetchone()
    if row is not None and row["user_match_instruction"] in INSTRUCTIONS:
        return row["user_match_instruction"]
    return _decide(conn, career_id)


def instruction_for(conn: sqlite3.Connection, career_id: str, fixture_id: str) -> str:
    """The user's instruction for this fixture, deciding it once if nobody
    has. Lazy and sticky, exactly like `squad.status_for`.

    Writes but does not commit - every caller is already inside an endpoint
    that owns its transaction (INV-3)."""
    row = conn.execute(
        "SELECT user_match_instruction FROM fixture WHERE career_id = ? AND fixture_id = ?",
        (career_id, fixture_id),
    ).fetchone()
    if row is None:
        return ANY
    if row["user_match_instruction"] in INSTRUCTIONS:
        return row["user_match_instruction"]

    value = _decide(conn, career_id)
    conn.execute(
        "UPDATE fixture SET user_match_instruction = ? WHERE career_id = ? AND fixture_id = ?",
        (value, career_id, fixture_id),
    )
    return value


def set_instruction(conn: sqlite3.Connection, career_id: str, fixture_id: str, value: str) -> None:
    """The one path that overwrites an already-frozen instruction (INV-54):
    a granted M4 `request_instruction`, or a granted `request_role`/
    `request_position` re-deriving it from the new role. Does not commit."""
    assert value in INSTRUCTIONS, f"unknown instruction {value!r}"
    conn.execute(
        "UPDATE fixture SET user_match_instruction = ? WHERE career_id = ? AND fixture_id = ?",
        (value, career_id, fixture_id),
    )


def focus_wire(value: str) -> Optional[str]:
    """`'any'` -> `None` ("farketmez", API_CONTRACT §6.1); every other value
    passes through unchanged. The one place the internal SQL sentinel and
    the wire's null meet."""
    return None if value == ANY else value


def label(value: str) -> str:
    """Turkish label — the same four strings §8.1's `directive_options.focus`
    already uses, so the pre-match card and the in-match "Rol" sheet agree."""
    return _LABELS[value]
