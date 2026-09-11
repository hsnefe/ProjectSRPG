"""§12.7 - sponsorship deals: money that arrives, and days that leave.

Two halves, and the tension between them is the mechanic. A signed deal pays
every Monday alongside the wage, without the player doing anything. Some
deals also put dates in the calendar that the player must show up for; those
pay more. The biggest cheque in the file costs an afternoon every three
weeks.

An obligation blocks `advance` the way an unanswered social offer does
(D53's reading): if you promised to be somewhere, that day is not one you
skip. Missing one breaks the deal outright - the income stops and the media
relationship takes it, because a no-show is a story.

Unlike transfers there is **no phase gate**. The request was explicit that a
sponsorship can be signed at any point in the season, and nothing in the
fiction argues otherwise: a brand does not wait for a transfer window.
"""
import datetime as _dt
import random
import sqlite3
from typing import List, Optional

from api import config, errors
from api.ids import new_obligation_id, new_sponsorship_deal_id
from content.sponsorships import SPONSORSHIPS, public_view, template
from domain import (
    condition as condition_mod,
    day_budget,
    relationships,
    requirements,
    season as season_mod,
    wallet,
)

OFFERED = "offered"
ACTIVE = "active"
DECLINED = "declined"
ENDED = "ended"
BROKEN = "broken"

PENDING = "pending"
DONE = "done"
MISSED = "missed"

# The chance any one advanced day brings a sponsorship approach. Lower than
# the social offers' 0.12: a brand calling should feel like an event of the
# season rather than of the week.
DAILY_CHANCE = 0.04

# What missing an obligation costs with the press. The money stopping is the
# real punishment; this is the story about it.
MISSED_MEDIA_DELTA = -6


def _game_date(conn: sqlite3.Connection, career_id: str) -> str:
    return conn.execute(
        "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["game_date"]


def _row_to_deal(conn: sqlite3.Connection, career_id: str, row: sqlite3.Row) -> dict:
    spec = template(row["template_id"]) or {}
    return {
        "deal_id": row["deal_id"],
        **(public_view(spec) if spec else {}),
        # The stored figure, not the template's: a deal runs on the number it
        # was signed at, the way inventory freezes `price_paid`.
        "weekly_income": row["weekly_income"],
        "status": row["status"],
        "signed_on": row["signed_on"],
        "expires_on": row["expires_on"],
        "obligations": [
            {
                "obligation_id": o["obligation_id"],
                "due_on": o["due_on"],
                "status": o["status"],
            }
            for o in conn.execute(
                "SELECT * FROM sponsorship_obligation WHERE career_id = ? AND deal_id = ? "
                "ORDER BY due_on",
                (career_id, row["deal_id"]),
            ).fetchall()
        ],
    }


def list_offers(conn: sqlite3.Connection, career_id: str) -> List[dict]:
    rows = conn.execute(
        "SELECT * FROM sponsorship_deal WHERE career_id = ? AND status = ? "
        "ORDER BY offered_on DESC",
        (career_id, OFFERED),
    ).fetchall()
    return [_row_to_deal(conn, career_id, r) for r in rows]


def list_active(conn: sqlite3.Connection, career_id: str) -> List[dict]:
    rows = conn.execute(
        "SELECT * FROM sponsorship_deal WHERE career_id = ? AND status = ? "
        "ORDER BY signed_on",
        (career_id, ACTIVE),
    ).fetchall()
    return [_row_to_deal(conn, career_id, r) for r in rows]


def pending_obligations(
    conn: sqlite3.Connection, career_id: str, on_date: str
) -> List[sqlite3.Row]:
    """Everything due today or overdue. Overdue is possible only in the
    moment between a day rolling over and the player answering, because the
    advance gate below stops time until they have."""
    return conn.execute(
        "SELECT o.*, d.template_id FROM sponsorship_obligation o "
        "JOIN sponsorship_deal d ON d.career_id = o.career_id AND d.deal_id = o.deal_id "
        "WHERE o.career_id = ? AND o.status = ? AND o.due_on <= ? "
        "ORDER BY o.due_on",
        (career_id, PENDING, on_date),
    ).fetchall()


def _has_history(conn: sqlite3.Connection, career_id: str, template_id: str, on_date: str,
                 cooldown_days: int) -> bool:
    """Was this brand here recently? Counts every status - a deal that was
    turned down does not come back the following week either."""
    since = (
        _dt.date.fromisoformat(on_date) - _dt.timedelta(days=cooldown_days)
    ).isoformat()
    return conn.execute(
        "SELECT 1 FROM sponsorship_deal WHERE career_id = ? AND template_id = ? "
        "AND offered_on >= ? LIMIT 1",
        (career_id, template_id, since),
    ).fetchone() is not None


def _eligible(
    conn: sqlite3.Connection, career_id: str, on_date: str
) -> List[dict]:
    active_ids = {
        r["template_id"] for r in conn.execute(
            "SELECT template_id FROM sponsorship_deal WHERE career_id = ? AND status = ?",
            (career_id, ACTIVE),
        ).fetchall()
    }
    out = []
    for spec in SPONSORSHIPS:
        if spec["template_id"] in active_ids:
            continue
        if _has_history(conn, career_id, spec["template_id"], on_date, spec["cooldown_days"]):
            continue
        try:
            requirements.check(conn, career_id, config.USER_PLAYER_ID, spec.get("requires"))
        except errors.ApiError:
            # The gate is checked here as well as at signing so a brand the
            # player cannot represent never calls. Being offered something
            # you are not allowed to take is noise.
            continue
        out.append(spec)
    return out


def maybe_generate(
    conn: sqlite3.Connection, career_id: str, on_date: str, seed: int
) -> Optional[dict]:
    """One roll per advanced day. At most one offer stands at a time, for the
    same reason INV-39 caps the social ones: a stack of decisions is not a
    decision."""
    if list_offers(conn, career_id):
        return None

    rng = random.Random(f"{seed}:sponsorship:{on_date}")
    if rng.random() >= DAILY_CHANCE:
        return None

    candidates = _eligible(conn, career_id, on_date)
    if not candidates:
        return None

    total = sum(c["weight"] for c in candidates)
    pick = rng.uniform(0, total)
    running = 0.0
    chosen = candidates[-1]
    for candidate in candidates:
        running += candidate["weight"]
        if pick <= running:
            chosen = candidate
            break

    deal_id = new_sponsorship_deal_id()
    conn.execute(
        "INSERT INTO sponsorship_deal (career_id, deal_id, template_id, status, "
        "offered_on, signed_on, expires_on, weekly_income) "
        "VALUES (?, ?, ?, ?, ?, NULL, NULL, ?)",
        (career_id, deal_id, chosen["template_id"], OFFERED, on_date,
         chosen["weekly_income"]),
    )
    row = conn.execute(
        "SELECT * FROM sponsorship_deal WHERE career_id = ? AND deal_id = ?",
        (career_id, deal_id),
    ).fetchone()
    return _row_to_deal(conn, career_id, row)


def accept(conn: sqlite3.Connection, career_id: str, deal_id: str, on_date: str) -> dict:
    """Signs the deal and writes every obligation it carries into the
    calendar up front.

    Scheduling them all now rather than one at a time is deliberate: the
    player can see what they agreed to, and an obligation cannot quietly
    fail to be created by a day loop that never ran.
    """
    row = conn.execute(
        "SELECT * FROM sponsorship_deal WHERE career_id = ? AND deal_id = ?",
        (career_id, deal_id),
    ).fetchone()
    if row is None:
        raise errors.sponsorship_not_found(deal_id)
    if row["status"] != OFFERED:
        raise errors.sponsorship_not_open(deal_id)

    spec = template(row["template_id"])
    requirements.check(conn, career_id, config.USER_PLAYER_ID, spec.get("requires"))

    expires_on = _expiry_for(conn, career_id, on_date, spec["seasons"])
    conn.execute(
        "UPDATE sponsorship_deal SET status = ?, signed_on = ?, expires_on = ? "
        "WHERE career_id = ? AND deal_id = ?",
        (ACTIVE, on_date, expires_on, career_id, deal_id),
    )

    obligation = spec.get("obligation")
    if obligation:
        due = _dt.date.fromisoformat(on_date)
        end = _dt.date.fromisoformat(expires_on)
        while True:
            due += _dt.timedelta(days=obligation["every_days"])
            if due > end:
                break
            conn.execute(
                "INSERT INTO sponsorship_obligation (career_id, obligation_id, deal_id, "
                "due_on, status) VALUES (?, ?, ?, ?, ?)",
                (career_id, new_obligation_id(), deal_id, due.isoformat(), PENDING),
            )

    row = conn.execute(
        "SELECT * FROM sponsorship_deal WHERE career_id = ? AND deal_id = ?",
        (career_id, deal_id),
    ).fetchone()
    return _row_to_deal(conn, career_id, row)


def _expiry_for(conn, career_id, on_date, seasons: int) -> str:
    """Like a playing contract, a deal ends on a season boundary (D50's
    reading) — an endorsement that stops on an arbitrary Tuesday would make
    the calendar harder to read for no gain."""
    row = season_mod.current_season_row(conn, career_id, on_date)
    if row is None:
        row = conn.execute(
            "SELECT * FROM season WHERE career_id = ? AND starts_on > ? "
            "ORDER BY starts_on ASC LIMIT 1",
            (career_id, on_date),
        ).fetchone()
    if row is None:
        signed = _dt.date.fromisoformat(on_date)
        return signed.replace(year=signed.year + seasons).isoformat()

    opening_year = _dt.date.fromisoformat(row["starts_on"]).year
    return season_mod.calendar_for(opening_year + seasons - 1).ends_on.isoformat()


def decline(conn: sqlite3.Connection, career_id: str, deal_id: str, on_date: str) -> None:
    """Costs nothing and cannot fail — INV-40's reading again."""
    row = conn.execute(
        "SELECT status FROM sponsorship_deal WHERE career_id = ? AND deal_id = ?",
        (career_id, deal_id),
    ).fetchone()
    if row is None:
        raise errors.sponsorship_not_found(deal_id)
    if row["status"] != OFFERED:
        raise errors.sponsorship_not_open(deal_id)
    conn.execute(
        "UPDATE sponsorship_deal SET status = ? WHERE career_id = ? AND deal_id = ?",
        (DECLINED, career_id, deal_id),
    )


def attend(conn: sqlite3.Connection, career_id: str, obligation_id: str, on_date: str) -> dict:
    """Turn up. Spends the day's budget and some condition — the cost of the
    money that has been arriving every Monday."""
    row = conn.execute(
        "SELECT o.*, d.template_id FROM sponsorship_obligation o "
        "JOIN sponsorship_deal d ON d.career_id = o.career_id AND d.deal_id = o.deal_id "
        "WHERE o.career_id = ? AND o.obligation_id = ?",
        (career_id, obligation_id),
    ).fetchone()
    if row is None:
        raise errors.sponsorship_not_found(obligation_id)
    if row["status"] != PENDING:
        raise errors.sponsorship_not_open(obligation_id)

    spec = template(row["template_id"])
    obligation = spec["obligation"]

    # Before the first write, so a 409 leaves nothing behind (INV-4).
    day_budget.spend(conn, career_id, obligation["costs"])

    condition_after = None
    if obligation.get("condition"):
        condition_after = condition_mod.apply_delta(
            conn, career_id, obligation["condition"]
        )

    conn.execute(
        "UPDATE sponsorship_obligation SET status = ? WHERE career_id = ? AND obligation_id = ?",
        (DONE, career_id, obligation_id),
    )
    return {"obligation_id": obligation_id, "condition_after": condition_after}


def skip(conn: sqlite3.Connection, career_id: str, obligation_id: str, on_date: str) -> dict:
    """Do not turn up. The deal breaks: the income stops and the press has a
    story. This is the escape hatch that keeps the advance gate from being a
    lock — the player is never trapped, only charged."""
    row = conn.execute(
        "SELECT * FROM sponsorship_obligation WHERE career_id = ? AND obligation_id = ?",
        (career_id, obligation_id),
    ).fetchone()
    if row is None:
        raise errors.sponsorship_not_found(obligation_id)
    if row["status"] != PENDING:
        raise errors.sponsorship_not_open(obligation_id)

    conn.execute(
        "UPDATE sponsorship_obligation SET status = ? WHERE career_id = ? AND obligation_id = ?",
        (MISSED, career_id, obligation_id),
    )
    conn.execute(
        "UPDATE sponsorship_deal SET status = ? WHERE career_id = ? AND deal_id = ?",
        (BROKEN, career_id, row["deal_id"]),
    )
    # Whatever else that deal had booked is void with it.
    conn.execute(
        "UPDATE sponsorship_obligation SET status = ? "
        "WHERE career_id = ? AND deal_id = ? AND status = ?",
        (MISSED, career_id, row["deal_id"], PENDING),
    )

    change = relationships.apply_delta(
        conn, career_id, "media", MISSED_MEDIA_DELTA,
        f"sponsorship_missed:{row['deal_id']}", f"{on_date}T12:00:00+03:00",
    )
    return {"obligation_id": obligation_id, "relationship_changes": [change]}


def pay_weekly(conn: sqlite3.Connection, career_id: str, on_date: str) -> List[dict]:
    """Every active deal's weekly cheque, on the same Monday the wage lands.
    Deals that have run out are closed here rather than by a separate sweep —
    this is the one place that looks at them every week anyway."""
    conn.execute(
        "UPDATE sponsorship_deal SET status = ? WHERE career_id = ? AND status = ? "
        "AND expires_on IS NOT NULL AND expires_on < ?",
        (ENDED, career_id, ACTIVE, on_date),
    )

    entries = []
    for row in conn.execute(
        "SELECT * FROM sponsorship_deal WHERE career_id = ? AND status = ?",
        (career_id, ACTIVE),
    ).fetchall():
        entries.append(wallet.apply(
            conn, career_id, row["weekly_income"], "sponsorship",
            f"sponsorship:{row['deal_id']}:{on_date}",
            f"{on_date}T00:00:00+03:00",
        ))
    return entries
