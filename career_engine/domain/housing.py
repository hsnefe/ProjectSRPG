"""§14.4 D87-D90, D95, INV-67, INV-69 - where the career lives and what it costs.

The active residence decides how the nights go (`recovery_parts`, read by
condition.daily_recovery - the one place the day's condition is worth is still
computed once) and adds a passive `charisma` bonus by its grade (`passive_bonus`,
read by attributes.passive_bonus, the same derived-not-stored layer §13.3
introduced for worn items). Neither writes anything.

What does write:

- `acquire` / `activate` / `install_upgrade` are the player's moves. They spend
  through wallet.apply() and never commit (INV-3); the router owns the
  transaction.
- `process_day` runs once per advanced day from daytime.process_day: the hotel's
  nightly fee and expiry, then - on the 1st - rent and the private chef. It
  returns what it took and every forced move, and it does not write news: the
  day loop owns _create_news, and importing it here would be a cycle.
- `on_transfer` runs inside transfer.accept's transaction (D90).

INV-69 is why `_make_active` deletes a leaving lease instead of deactivating it:
there is no such thing as a rented flat you are not living in.
"""
import calendar
import datetime as _dt
import random
import sqlite3
from typing import List, Optional

from api import config, errors
from catalog import housing as catalog
from domain import wallet


# --- reading ----------------------------------------------------------------


def _row(conn: sqlite3.Connection, career_id: str, residence_id: str) -> Optional[sqlite3.Row]:
    return conn.execute(
        "SELECT * FROM residence WHERE career_id = ? AND residence_id = ?",
        (career_id, residence_id),
    ).fetchone()


def active_row(conn: sqlite3.Connection, career_id: str) -> Optional[sqlite3.Row]:
    return conn.execute(
        "SELECT * FROM residence WHERE career_id = ? AND active = 1", (career_id,)
    ).fetchone()


def active_spec(conn: sqlite3.Connection, career_id: str) -> dict:
    """The catalog row of the home the career sleeps in. A career with no active
    row reads as still in the starting dorm - migration 021 backfills every
    existing career, so this is a floor under a missing row, not a normal path."""
    row = active_row(conn, career_id)
    spec = catalog.get(row["residence_id"]) if row is not None else None
    return spec or catalog.get(config.STARTING_RESIDENCE)


def installed_upgrades(conn: sqlite3.Connection, career_id: str, residence_id: str) -> List[dict]:
    rows = conn.execute(
        "SELECT upgrade_id FROM residence_upgrade WHERE career_id = ? AND residence_id = ? "
        "ORDER BY installed_on, upgrade_id",
        (career_id, residence_id),
    ).fetchall()
    # An upgrade dropped from the catalog contributes nothing rather than
    # raising, the same floor inventory's unknown ids get.
    return [catalog.upgrade(r["upgrade_id"]) for r in rows if catalog.upgrade(r["upgrade_id"])]


def _noise_rolls(seed: int, on_date: str, chance: float) -> bool:
    return random.Random(f"{seed}:housing_noise:{on_date}").random() < chance


def recovery_parts(
    conn: sqlite3.Connection, career_id: str, on_date: Optional[str] = None, seed: Optional[int] = None
) -> dict:
    """What the active home contributes to one night (D88).

    `on_date` and `seed` are optional only so a caller that has no day in mind
    (the inventory endpoints) still gets a number: without them the noise roll is
    not thrown and the nominal sleep is reported, with `noise.chance` saying what
    could happen. T1 and the day loop pass both, the same date for the same night,
    so the forecast the player sees is the night they get."""
    row = active_row(conn, career_id)
    spec = active_spec(conn, career_id)
    upgrades = installed_upgrades(conn, career_id, spec["residence_id"]) if row is not None else []

    cancelled = any(u.get("cancels_noise") for u in upgrades)
    chance = 0.0 if cancelled else spec["noise_chance"]
    halved = bool(chance and on_date is not None and seed is not None
                  and _noise_rolls(seed, on_date, chance))
    sleep = round(spec["sleep"] / 2) if halved else spec["sleep"]

    modifiers = [dict(m) for m in spec["modifiers"]]
    for up in upgrades:
        if up.get("sleep"):
            modifiers.append({"key": up["upgrade_id"], "title": up["title"], "amount": up["sleep"]})
        if up.get("morning"):
            modifiers.append({"key": up["upgrade_id"], "title": up["title"], "amount": up["morning"]})
    return {
        "residence": {"residence_id": spec["residence_id"], "title": spec["title"]},
        "sleep": sleep,
        "modifiers": modifiers,
        "noise": {"chance": chance, "halved": halved},
    }


def passive_bonus(conn: sqlite3.Connection, career_id: str, attribute_key: str) -> float:
    """§14.4 - the active home's grade, worth CHARISMA_PER_GRADE each, on
    `charisma` and nothing else. A holiday home is never active (D87), so its
    grade never counts."""
    if attribute_key != "charisma":
        return 0.0
    from catalog.shop import CHARISMA_PER_GRADE  # local, like condition's shop import

    return active_spec(conn, career_id)["grade"] * CHARISMA_PER_GRADE


def view(conn: sqlite3.Connection, career_id: str) -> dict:
    """The housing screen's whole picture: every catalog row with the career's
    state on it, the six upgrades, and which are fitted where."""
    held = {r["residence_id"]: r for r in conn.execute(
        "SELECT * FROM residence WHERE career_id = ?", (career_id,)
    ).fetchall()}
    fitted = {}
    for r in conn.execute(
        "SELECT residence_id, upgrade_id FROM residence_upgrade WHERE career_id = ? "
        "ORDER BY installed_on, upgrade_id", (career_id,),
    ).fetchall():
        fitted.setdefault(r["residence_id"], []).append(r["upgrade_id"])

    residences = []
    for spec in catalog.RESIDENCES:
        row = held.get(spec["residence_id"])
        residences.append({
            **spec,
            "held": row is not None,
            "tenure": row["tenure"] if row is not None else None,
            "active": bool(row["active"]) if row is not None else False,
            "expires_on": row["expires_on"] if row is not None else None,
            "upgrades": fitted.get(spec["residence_id"], []),
        })
    active = active_row(conn, career_id)
    return {
        "active_residence_id": active["residence_id"] if active else config.STARTING_RESIDENCE,
        "residences": residences,
        "upgrades": catalog.UPGRADES,
    }


# --- moving -----------------------------------------------------------------


def _insert(conn, career_id, residence_id, tenure, on_date, *, price_paid=0,
            monthly_rent=0, daily_fee=0, expires_on=None) -> None:
    conn.execute(
        "INSERT INTO residence (career_id, residence_id, tenure, acquired_on, price_paid, "
        "monthly_rent, daily_fee, expires_on, active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)",
        (career_id, residence_id, tenure, on_date, price_paid, monthly_rent, daily_fee, expires_on),
    )


def _leave_active(conn: sqlite3.Connection, career_id: str) -> Optional[str]:
    """Stops living wherever the career lives. A lease or a hotel stay ends with
    it (INV-69); a start home or an owned one just goes quiet. Returns the id
    left, for the move report."""
    current = active_row(conn, career_id)
    if current is None:
        return None
    if current["tenure"] in ("rented", "hotel"):
        conn.execute(
            "DELETE FROM residence WHERE career_id = ? AND residence_id = ?",
            (career_id, current["residence_id"]),
        )
    else:
        conn.execute(
            "UPDATE residence SET active = 0 WHERE career_id = ? AND residence_id = ?",
            (career_id, current["residence_id"]),
        )
    return current["residence_id"]


def _make_active(conn: sqlite3.Connection, career_id: str, residence_id: str) -> Optional[str]:
    """Moves in. Always leaves the old home first: the partial unique index
    (INV-67) would refuse the reverse order."""
    current = active_row(conn, career_id)
    if current is not None and current["residence_id"] == residence_id:
        return None
    left = _leave_active(conn, career_id)
    conn.execute(
        "UPDATE residence SET active = 1 WHERE career_id = ? AND residence_id = ?",
        (career_id, residence_id),
    )
    return left


def _spec_or_422(residence_id: str) -> dict:
    spec = catalog.get(residence_id)
    if spec is None:
        raise errors.invalid_request(f"unknown residence_id {residence_id!r}")
    return spec


def _prorated_rent(rent_monthly: int, on_date: str) -> int:
    """D89 - a lease signed mid-month pays for the days left in it, today included."""
    year, month, day = (int(p) for p in on_date.split("-"))
    days_in_month = calendar.monthrange(year, month)[1]
    remaining = days_in_month - day + 1
    return max(1, -(-rent_monthly * remaining // days_in_month))


def acquire(conn: sqlite3.Connection, career_id: str, residence_id: str, on_date: str) -> dict:
    """Takes a home: a start home is free, a lease is paid pro rata, a purchase
    is paid in full. A start home or a lease moves the player in; a purchase does
    not (D87: buying and moving are two decisions, and a holiday home cannot be
    moved into at all). Returns {"moved": bool, "ledger_entries": [...]}."""
    spec = _spec_or_422(residence_id)
    kind = spec["kind"]
    if kind == "hotel":
        raise errors.residence_not_available(residence_id, "is arranged by the club after a transfer")
    if _row(conn, career_id, residence_id) is not None:
        raise errors.residence_already_held(residence_id)

    happened_at = f"{on_date}T00:00:00+03:00"
    entries = []
    if kind == "start":
        _insert(conn, career_id, residence_id, "start", on_date)
    elif kind == "rent":
        due = _prorated_rent(spec["rent_monthly"], on_date)
        entries.append(wallet.apply(conn, career_id, -due, "rent", f"rent:{residence_id}:move_in", happened_at))
        _insert(conn, career_id, residence_id, "rented", on_date,
                price_paid=due, monthly_rent=spec["rent_monthly"])
    else:  # buy | holiday
        entries.append(wallet.apply(
            conn, career_id, -spec["price"], "purchase", f"residence:{residence_id}", happened_at
        ))
        _insert(conn, career_id, residence_id, "owned", on_date, price_paid=spec["price"])

    moved = kind in ("start", "rent")
    if moved:
        _make_active(conn, career_id, residence_id)
    return {"moved": moved, "ledger_entries": entries}


def activate(conn: sqlite3.Connection, career_id: str, residence_id: str, on_date: str) -> dict:
    """Moves into a home the career already holds. Idempotent: asking for the
    home you live in changes nothing. A start home is always reachable, even one
    the career has not stood in yet, because the family home is where an eviction
    sends you and the player must be able to choose it first."""
    spec = _spec_or_422(residence_id)
    if spec["kind"] not in catalog.HABITABLE_KINDS:
        raise errors.residence_not_available(residence_id, "is a holiday home: visited, not lived in")
    if _row(conn, career_id, residence_id) is None:
        if spec["kind"] != "start":
            raise errors.residence_not_held(residence_id)
        _insert(conn, career_id, residence_id, "start", on_date)
    left = _make_active(conn, career_id, residence_id)
    return {"moved": left is not None, "left": left}


def install_upgrade(
    conn: sqlite3.Connection, career_id: str, residence_id: str, upgrade_id: str, on_date: str
) -> dict:
    """D95 - only a home the player owns outright and can live in takes one."""
    spec = _spec_or_422(residence_id)
    up = catalog.upgrade(upgrade_id)
    if up is None:
        raise errors.invalid_request(f"unknown upgrade_id {upgrade_id!r}")
    row = _row(conn, career_id, residence_id)
    if row is None:
        raise errors.residence_not_held(residence_id)
    if row["tenure"] != "owned" or spec["kind"] != "buy":
        raise errors.residence_not_available(
            residence_id, "is not a home you own; upgrades are fitted to owned homes only"
        )
    if conn.execute(
        "SELECT 1 FROM residence_upgrade WHERE career_id = ? AND residence_id = ? AND upgrade_id = ?",
        (career_id, residence_id, upgrade_id),
    ).fetchone():
        raise errors.upgrade_already_installed(upgrade_id)

    entry = wallet.apply(
        conn, career_id, -up["price"], "purchase", f"upgrade:{residence_id}:{upgrade_id}",
        f"{on_date}T00:00:00+03:00",
    )
    conn.execute(
        "INSERT INTO residence_upgrade (career_id, residence_id, upgrade_id, installed_on, "
        "price_paid, monthly_fee) VALUES (?, ?, ?, ?, ?, ?)",
        (career_id, residence_id, upgrade_id, on_date, up["price"], up.get("monthly_fee", 0)),
    )
    return {"ledger_entries": [entry]}


REST_PHASES = ("winter_break", "summer_transfer_window")


def require_rest(conn: sqlite3.Connection, career_id: str, residence_id: str, phase: str) -> dict:
    """D90 - the `rest` block of a held holiday home, if today may be spent there.
    The router spends the day and applies the effects: they go through T2's
    effect applier, which lives with the routers."""
    spec = _spec_or_422(residence_id)
    if spec["kind"] != "holiday":
        raise errors.residence_not_available(residence_id, "is not a holiday home")
    if _row(conn, career_id, residence_id) is None:
        raise errors.residence_not_held(residence_id)
    if phase not in REST_PHASES:
        raise errors.rest_out_of_season(phase)
    return spec["rest"]


# --- the two automatic moves ------------------------------------------------


def _fall_back(conn: sqlite3.Connection, career_id: str, reason: str, on_date: str) -> dict:
    """Ends the active lease and sends the career to the family home, which is
    free and always there (D89/D90)."""
    left = _leave_active(conn, career_id)
    if _row(conn, career_id, config.FALLBACK_RESIDENCE) is None:
        _insert(conn, career_id, config.FALLBACK_RESIDENCE, "start", on_date)
    conn.execute(
        "UPDATE residence SET active = 1 WHERE career_id = ? AND residence_id = ?",
        (career_id, config.FALLBACK_RESIDENCE),
    )
    return {"from": left, "to": config.FALLBACK_RESIDENCE, "reason": reason}


def on_transfer(conn: sqlite3.Connection, career_id: str, on_date: str) -> Optional[dict]:
    """D90 - a new club, a new city: leases end, the club books a hotel room for
    HOTEL_STAY_DAYS, unless the player already lives in a home they own."""
    current = active_row(conn, career_id)
    if current is not None and current["tenure"] == "owned":
        return None
    spec = catalog.get("res-hotel")
    left = _leave_active(conn, career_id)
    expires_on = (_dt.date.fromisoformat(on_date) + _dt.timedelta(days=config.HOTEL_STAY_DAYS)).isoformat()
    _insert(conn, career_id, spec["residence_id"], "hotel", on_date,
            daily_fee=spec["daily_fee"], expires_on=expires_on)
    conn.execute(
        "UPDATE residence SET active = 1 WHERE career_id = ? AND residence_id = ?",
        (career_id, spec["residence_id"]),
    )
    return {"from": left, "to": spec["residence_id"], "reason": "transfer", "expires_on": expires_on}


def process_day(conn: sqlite3.Connection, career_id: str, on_date: str) -> dict:
    """One advanced day's housing money. Returns
    {"ledger_entries", "moves", "lost_upgrades"}; the caller turns the last two
    into headlines and stop events."""
    happened_at = f"{on_date}T00:00:00+03:00"
    entries, moves, lost = [], [], []

    current = active_row(conn, career_id)
    if current is not None and current["tenure"] == "hotel":
        if on_date >= current["expires_on"]:
            moves.append(_fall_back(conn, career_id, "hotel_expired", on_date))
        elif wallet.get_balance(conn, career_id) >= current["daily_fee"]:
            entries.append(wallet.apply(
                conn, career_id, -current["daily_fee"], "rent", f"hotel:{on_date}", happened_at
            ))
        else:
            moves.append(_fall_back(conn, career_id, "hotel_fee", on_date))

    if int(on_date[8:10]) != config.RENT_DAY_OF_MONTH:
        return {"ledger_entries": entries, "moves": moves, "lost_upgrades": lost}

    current = active_row(conn, career_id)
    if current is not None and current["tenure"] == "rented":
        if wallet.get_balance(conn, career_id) >= current["monthly_rent"]:
            entries.append(wallet.apply(
                conn, career_id, -current["monthly_rent"], "rent",
                f"rent:{current['residence_id']}:{on_date}", happened_at,
            ))
        else:
            # D89 - the lease ends; there is nothing to sell back (D29's 50%
            # refund is for things the player owns).
            moves.append(_fall_back(conn, career_id, "rent", on_date))

    # The chef is on the payroll wherever the house stands, active or not: paying
    # only while you live there would let a player dodge the fee by sleeping
    # elsewhere on the 1st.
    for row in conn.execute(
        "SELECT residence_id, upgrade_id, monthly_fee FROM residence_upgrade "
        "WHERE career_id = ? AND monthly_fee > 0 ORDER BY residence_id, upgrade_id",
        (career_id,),
    ).fetchall():
        if wallet.get_balance(conn, career_id) >= row["monthly_fee"]:
            entries.append(wallet.apply(
                conn, career_id, -row["monthly_fee"], "rent",
                f"upgrade:{row['residence_id']}:{row['upgrade_id']}:{on_date}", happened_at,
            ))
        else:
            conn.execute(
                "DELETE FROM residence_upgrade WHERE career_id = ? AND residence_id = ? AND upgrade_id = ?",
                (career_id, row["residence_id"], row["upgrade_id"]),
            )
            lost.append({"residence_id": row["residence_id"], "upgrade_id": row["upgrade_id"]})
    return {"ledger_entries": entries, "moves": moves, "lost_upgrades": lost}


def start(conn: sqlite3.Connection, career_id: str, on_date: str) -> None:
    """Career creation: everyone opens in the academy dorm."""
    _insert(conn, career_id, config.STARTING_RESIDENCE, "start", on_date)
    conn.execute(
        "UPDATE residence SET active = 1 WHERE career_id = ? AND residence_id = ?",
        (career_id, config.STARTING_RESIDENCE),
    )
