"""§12.2 - whether the user is in the first eleven, on the bench, or out.

Until this module the answer was always "first eleven": §3.2 said so in
words, and `apply_result` wrote `appearances=1, starts=1, minutes=95` with no
branch. That made every other number in the game one-directional - the coach
relationship could fall to zero and Saturday looked identical.

D4 is *not* undone here. There is still exactly one player row per career and
no squad for any of the 32 teams; what changes is that the user's own place
in the side stops being assumed. It is one column on `fixture`.

The decision is deliberately **lazy and sticky**: computed the first time
anything asks, then stored. Two callers need to agree about the same match
(T1's event list and T3's advance gate, the pair `user_match_today` exists to
keep honest), and a decision that re-rolled per call would let the answer
change between the gate and the screen.
"""
import random
import sqlite3
from typing import Optional

from domain import relationships

FIRST_ELEVEN = "first_eleven"
BENCH = "bench"
OUT = "out"
STATUSES = (FIRST_ELEVEN, BENCH, OUT)

# What the coach weighs. Condition leads because being fit is the part the
# player controls most directly day to day; trust comes next because §12.1
# made it the thing you spend arguing with him; the bare relationship counts
# least - liking you is not a reason to pick you.
CONDITION_WEIGHT = 0.45
TRUST_WEIGHT = 0.35
SCORE_WEIGHT = 0.20

# Seeded wobble, so an identical week does not always produce an identical
# team sheet while staying reproducible (INV-7).
JITTER = 10.0

FIRST_ELEVEN_THRESHOLD = 55.0
BENCH_THRESHOLD = 30.0


def selection_score(condition: float, trust: float, coach_score: float, jitter: float) -> float:
    """Pure, so the thresholds can be tested without a database.

    A fresh career sits at condition 100, trust 50, coach 70 -> 76.5, which
    is comfortably a start. That is on purpose: the opening of a career
    should look the way it always did, and losing your place should be
    something that happens to you rather than a coin flip on day one."""
    return (
        CONDITION_WEIGHT * condition
        + TRUST_WEIGHT * trust
        + SCORE_WEIGHT * coach_score
        + jitter
    )


def classify(score: float) -> str:
    if score >= FIRST_ELEVEN_THRESHOLD:
        return FIRST_ELEVEN
    if score >= BENCH_THRESHOLD:
        return BENCH
    return OUT


def _decide(conn: sqlite3.Connection, career_id: str, fixture_id: str, seed: int) -> str:
    condition = conn.execute(
        "SELECT condition FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["condition"]
    coach_score = relationships.get_score(conn, career_id, "coach")
    trust = relationships.get_traits(conn, career_id, "coach")["trust"]

    rng = random.Random(f"{seed}:squad:{fixture_id}")
    jitter = rng.uniform(-JITTER, JITTER)
    return classify(selection_score(condition, trust, coach_score, jitter))


def status_for(
    conn: sqlite3.Connection, career_id: str, fixture_id: str, seed: int
) -> str:
    """The user's status for this fixture, deciding it once if nobody has.

    Writes but does not commit - every caller is already inside an endpoint
    that owns its transaction (INV-3). A read-only endpoint that calls this
    (M1, T1) therefore persists the decision as a side effect of the commit
    it was going to make anyway.
    """
    row = conn.execute(
        "SELECT user_squad_status FROM fixture WHERE career_id = ? AND fixture_id = ?",
        (career_id, fixture_id),
    ).fetchone()
    if row is None:
        return OUT
    if row["user_squad_status"] in STATUSES:
        return row["user_squad_status"]

    status = _decide(conn, career_id, fixture_id, seed)
    conn.execute(
        "UPDATE fixture SET user_squad_status = ? WHERE career_id = ? AND fixture_id = ?",
        (status, career_id, fixture_id),
    )
    return status


def plays(status: str) -> bool:
    """Bench counts as playing: a substitute travels, sits, and may come on,
    so the match is still the user's to play (and to report via M2). Only
    `out` means the fixture belongs to the background simulation."""
    return status in (FIRST_ELEVEN, BENCH)


def default_minutes(status: str) -> int:
    """What FE reports when it has nothing more specific. A starter plays the
    full 95 the way M2 always assumed; a substitute's minutes depend on when
    the coach turned to him, which only the match screen knows."""
    return 95 if status == FIRST_ELEVEN else 0


def user_fixture_today(
    conn: sqlite3.Connection, career_id: str, on_date: str, seed: int,
    fixture_id: Optional[str],
) -> Optional[str]:
    """`fixture_id` in, playable fixture_id out - or None when the user is
    out of the squad for it. Kept here rather than in daytime so the "is the
    user out?" rule lives next to the rule that decided it."""
    if fixture_id is None:
        return None
    return fixture_id if plays(status_for(conn, career_id, fixture_id, seed)) else None
