"""§5.5 T1/T3, §6.3, §6.5, §6.7 - event detection and one day's worth of
processing. Both T1 (read-only "what's happening today") and T3 (the
advance loop) call list_events() so they never disagree about what counts
as eventful.

⚠️ Season rollover is intentionally NOT implemented here. When the advance
loop reaches season.ends_on it stops with stop_reason="season_end" and
does nothing further — no promotion/relegation, no new season, no fixture
regeneration. CONTRACT.md says terfi/düşme is "o çağrının içinde
hesaplanır" but doesn't specify the next-season generation algorithm
(same seed or new one? when do contracts/ages update?), so building that
out is left as a clearly-flagged follow-up rather than guessed at here.
"""
import datetime as _dt
import random
import sqlite3
from typing import List, Optional, Set

from api import config
from api.ids import new_news_id
from domain import (
    condition, contracts, engine_client, formulas, scheduling,
    season as season_mod, social, sponsorship, squad, transfer, wallet,
)
from worlddata.competitions import ULUSAL_KUPA


def _current_season(conn: sqlite3.Connection, career_id: str) -> str:
    return conn.execute(
        "SELECT season_id FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["season_id"]


def _user_team_id(conn: sqlite3.Connection, career_id: str) -> str:
    return conn.execute(
        "SELECT team_id FROM player WHERE career_id = ? AND is_user = 1", (career_id,)
    ).fetchone()["team_id"]


def _latest_contract(
    conn: sqlite3.Connection, career_id: str, on_date: str = None
) -> Optional[sqlite3.Row]:
    """The contract IN FORCE, not merely the newest.

    This used to order by `signed_at` and ignore `expires_at` entirely, so an
    expired deal stayed "the" contract and `_pay_wage` went on paying from it
    forever. Nothing could reach that state before §11.7, because no contract
    ever ran out; now being out of contract is a state the game has.

    `on_date` is optional only so the handful of callers that predate it keep
    working against today.
    """
    if on_date is None:
        on_date = conn.execute(
            "SELECT game_date FROM career_state WHERE career_id = ?", (career_id,)
        ).fetchone()["game_date"]
    return contracts.active_contract(conn, career_id, on_date)


def _sum_upkeep(conn: sqlite3.Connection, career_id: str) -> int:
    return conn.execute(
        "SELECT COALESCE(SUM(upkeep_weekly), 0) AS u FROM inventory WHERE career_id = ?",
        (career_id,),
    ).fetchone()["u"]


def _projected_upkeep_shortfall(conn: sqlite3.Connection, career_id: str) -> int:
    contract = _latest_contract(conn, career_id)
    wage = contract["weekly_wage"] if contract else 0
    balance = wallet.get_balance(conn, career_id)
    upkeep = _sum_upkeep(conn, career_id)
    return max(0, upkeep - (balance + wage))


def _is_cup_round_complete(
    conn: sqlite3.Connection, career_id: str, season_id: str, round_no: int
) -> bool:
    """Season-scoped. Without the season filter, season two's round 1 would
    match season one's round 1 as well — the cup restarts its numbering
    every year, so `round_no` alone stops identifying a round the moment a
    second season exists."""
    row = conn.execute(
        "SELECT COUNT(*) AS total, SUM(CASE WHEN status = 'played' THEN 1 ELSE 0 END) AS played "
        "FROM fixture WHERE career_id = ? AND season_id = ? AND competition_id = ? "
        "AND round_no = ?",
        (career_id, season_id, ULUSAL_KUPA, round_no),
    ).fetchone()
    return row["total"] > 0 and row["total"] == row["played"]


def _next_drawable_cup_round(conn: sqlite3.Connection, career_id: str, on_date: str) -> Optional[sqlite3.Row]:
    """The next undrawn cup round, if today is its scheduled day (or
    later — see module docstring: a round can't draw until the previous
    one is fully played, which may lag its nominal date if the user's own
    tie hasn't been resolved yet) AND the previous round is complete."""
    season_id = _current_season(conn, career_id)
    row = conn.execute(
        "SELECT round_no, scheduled_on FROM competition_round "
        "WHERE career_id = ? AND season_id = ? AND competition_id = ? AND drawn = 0 "
        "ORDER BY round_no ASC LIMIT 1",
        (career_id, season_id, ULUSAL_KUPA),
    ).fetchone()
    if row is None or row["scheduled_on"] > on_date:
        return None
    if not _is_cup_round_complete(conn, career_id, season_id, row["round_no"] - 1):
        return None
    return row


# §6.3 - which event kinds actually stop `advance {to: "next_event"}`.
#
# T1 reports every condition true today; T3 stops only on the ones that are
# genuinely *events*. 'relationship_low' and 'contract_expiring' are ongoing
# STATES: once a relationship drops under the threshold it stays there until
# the user does something about it, so treating it as a stop reason freezes
# time — every single day becomes eventful and the calendar can never reach
# the next match. CONTRACT.md §6.3's own wording is already edge-triggered
# ("eşiğin altına düştüğünde", "30 gün kala"), which is what this restores:
# contract_expiring stops exactly on the day the window opens, and a low
# relationship is surfaced by T1 without ever blocking the day loop.
# §11.8 - `season_phase_change` joins the stoppers so `advance` parks itself
# at the winter break and at season end instead of running through them.
# `season_end` stays alongside it: the phase can turn over on a day the
# calendar boundary does not (all fixtures played early), and vice versa.
STOP_EVENT_KINDS = {
    "match", "cup_draw", "upkeep_warning", "season_end", "season_phase_change",
    # §12.7 - a booked appearance and a brand on the phone are both things
    # the day should stop for.
    "sponsorship_offer", "sponsorship_obligation",
}


def stop_worthy(events: List[dict], on_date: str = None) -> List[dict]:
    """The subset of list_events() output that T3 may stop on.

    `social_offer` is edge-triggered like contract_expiring, for the same
    reason spelled out above: an unanswered offer is a STATE that persists
    until the player deals with it, so stopping on it every day would freeze
    the calendar. It stops on the day it arrives; from then on T1 keeps
    reporting it (the player should still see it) and the answer is enforced
    by T3 refusing to start at all (D53), which is a clearer failure than a
    loop that advances zero days and says nothing.
    """
    out = []
    for event in events:
        if event["kind"] in STOP_EVENT_KINDS:
            out.append(event)
        elif event["kind"] == "contract_expiring" and event["days_left"] == config.CONTRACT_EXPIRING_DAYS:
            out.append(event)
        elif event["kind"] == "social_offer" and event["opened_on"] == on_date:
            out.append(event)
    return out


def team_match_today(conn: sqlite3.Connection, career_id: str, on_date: str) -> Optional[str]:
    """The user's TEAM's fixture kicking off on_date, if it's still
    'scheduled'. Says nothing about whether the user is in the squad for it —
    that is squad.status_for's job (§12.2)."""
    user_team_id = _user_team_id(conn, career_id)
    row = conn.execute(
        "SELECT fixture_id FROM fixture WHERE career_id = ? AND status = 'scheduled' "
        "AND kickoff_at LIKE ? AND (home_team_id = ? OR away_team_id = ?)",
        (career_id, f"{on_date}%", user_team_id, user_team_id),
    ).fetchone()
    return row["fixture_id"] if row else None


def user_match_today(
    conn: sqlite3.Connection, career_id: str, on_date: str, seed: Optional[int] = None
) -> Optional[str]:
    """The fixture the USER plays on_date — None when the team has none, or
    when it has one the user is left out of (§12.2). The single query behind
    both list_events()'s 'match' event and T3's match-day gate (§6.1 D57), so
    the two can never disagree about what counts as "today's match".

    `seed` is optional only so read-only callers that have no reason to know
    about it keep working; without it the squad decision cannot be made, so
    an undecided fixture reads as playable. Every caller inside the day loop
    passes it."""
    fixture_id = team_match_today(conn, career_id, on_date)
    if fixture_id is None or seed is None:
        return fixture_id
    return squad.user_fixture_today(conn, career_id, on_date, seed, fixture_id)


def list_events(
    conn: sqlite3.Connection, career_id: str, on_date: str, seed: Optional[int] = None
) -> List[dict]:
    """Every event condition true for on_date.

    No longer strictly read-only: deciding the user's squad status for
    today's fixture writes that decision down (§12.2). The write is
    idempotent and the caller owns the commit, so a GET that never commits
    simply re-decides identically next time — the roll is seeded."""
    events = []

    fixture_id = user_match_today(conn, career_id, on_date, seed)
    if fixture_id:
        events.append({"kind": "match", "ref_id": fixture_id})

    cup_round = _next_drawable_cup_round(conn, career_id, on_date)
    if cup_round:
        events.append({"kind": "cup_draw", "ref_id": ULUSAL_KUPA, "round_no": cup_round["round_no"]})

    contract = contracts.active_contract(conn, career_id, on_date)
    if contract:
        days_left = contracts.days_until_expiry(contract, on_date)
        if 0 <= days_left <= config.CONTRACT_EXPIRING_DAYS:
            events.append({"kind": "contract_expiring", "ref_id": None, "days_left": days_left})
    elif contracts.latest_contract(conn, career_id) is not None:
        # §11.8 - out of contract. `ref_id` is null: there is nothing to
        # point at, which is the whole news.
        events.append({"kind": "contract_expired", "ref_id": None})

    for offer in transfer.list_open(conn, career_id):
        events.append({"kind": "transfer_offer", "ref_id": offer["offer_id"]})

    for deal in sponsorship.list_offers(conn, career_id):
        events.append({"kind": "sponsorship_offer", "ref_id": deal["deal_id"]})

    for row in sponsorship.pending_obligations(conn, career_id, on_date):
        events.append({
            "kind": "sponsorship_obligation",
            "ref_id": row["obligation_id"],
            "due_on": row["due_on"],
        })

    if _dt.date.fromisoformat(on_date).weekday() == config.WAGE_WEEKDAY:
        shortfall = _projected_upkeep_shortfall(conn, career_id)
        if shortfall > 0:
            events.append({"kind": "upkeep_warning", "ref_id": None, "shortfall": shortfall})

    for offer in social.list_open(conn, career_id):
        events.append({
            "kind": "social_offer",
            "ref_id": offer["offer_id"],
            "relationship_id": offer["relationship_id"],
            "opened_on": offer["opened_on"],
        })

    low_rows = conn.execute(
        "SELECT relationship_id FROM relationship WHERE career_id = ? AND score < ?",
        (career_id, config.RELATIONSHIP_LOW_THRESHOLD),
    ).fetchall()
    for r in low_rows:
        events.append({"kind": "relationship_low", "ref_id": r["relationship_id"]})

    # §11.2/§11.8 - the phase is derived, so "it changed" is a comparison
    # against yesterday rather than a stored flag. `ref_id` is the name of
    # the new phase, which is what FE keys its season-end screen on.
    phase = season_mod.derive_phase(conn, career_id, on_date)
    previous = _dt.date.fromisoformat(on_date) - _dt.timedelta(days=1)
    if season_mod.derive_phase(conn, career_id, previous.isoformat()) != phase:
        events.append({"kind": "season_phase_change", "ref_id": phase})

    if phase == season_mod.SEASON_END:
        events.append({"kind": "season_end", "ref_id": None})

    return events


def _create_news(conn: sqlite3.Connection, career_id: str, category: str, title: str, body: str, on_date: str) -> str:
    news_id = new_news_id()
    conn.execute(
        "INSERT INTO news (career_id, news_id, published_at, category, title, source, body, fixture_id) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, NULL)",
        (career_id, news_id, f"{on_date}T09:00:00+03:00", category, title, "Kulüp Bülteni", body),
    )
    return news_id


def _pay_wage(conn: sqlite3.Connection, career_id: str, on_date: str) -> Optional[dict]:
    contract = _latest_contract(conn, career_id)
    if not contract or contract["weekly_wage"] <= 0:
        return None
    return wallet.apply(
        conn, career_id, contract["weekly_wage"], "wage", f"wage:{on_date}", f"{on_date}T00:00:00+03:00"
    )


def _pay_upkeep(conn: sqlite3.Connection, career_id: str, on_date: str) -> tuple:
    """D27/D29: pays SUM(inventory.upkeep_weekly); if the balance (already
    including this Monday's wage) can't cover it, sells the highest-upkeep
    item at 50% refund and retries — repeatedly, per D29 step 3 — until
    covered or nothing is left to sell."""
    happened_at = f"{on_date}T00:00:00+03:00"
    entries, repossessed = [], []

    while True:
        due = _sum_upkeep(conn, career_id)
        if due <= 0:
            break
        balance = wallet.get_balance(conn, career_id)
        if balance >= due:
            entries.append(wallet.apply(conn, career_id, -due, "upkeep", f"upkeep:{on_date}", happened_at))
            break

        item = conn.execute(
            "SELECT item_id, price_paid FROM inventory WHERE career_id = ? "
            "ORDER BY upkeep_weekly DESC LIMIT 1",
            (career_id,),
        ).fetchone()
        if item is None:
            if balance > 0:
                entries.append(
                    wallet.apply(conn, career_id, -balance, "upkeep", f"upkeep:{on_date}:partial", happened_at)
                )
            break

        refund = item["price_paid"] // 2
        conn.execute("DELETE FROM inventory WHERE career_id = ? AND item_id = ?", (career_id, item["item_id"]))
        entries.append(wallet.apply(conn, career_id, refund, "sale", f"sale:{item['item_id']}", happened_at))
        repossessed.append(item["item_id"])
        _create_news(
            conn, career_id, "Analiz", "Bütçe zorlaması",
            f"Düzenli gideri karşılamak için {item['item_id']} elden çıkarıldı.", on_date,
        )

    return entries, repossessed


def _team_engine_fields(row: sqlite3.Row) -> dict:
    rating = formulas.compute_team_rating(dict(row))
    return {"name": row["name"], "mentality": row["mentality"], **rating}


def _fixture_rng(seed: int, *parts) -> random.Random:
    return random.Random(f"{seed}:" + ":".join(str(p) for p in parts))


def _simulate_day_fixtures(conn: sqlite3.Connection, career_id: str, on_date: str, seed: int) -> dict:
    """§6.7 D40: every fixture kicking off on_date that the user is not
    playing, in every competition.

    The user's own team's fixture is excluded only while the user is *in* the
    squad for it (§12.2): then it stays 'scheduled' and is played
    interactively via M1-M3, and (§6.1 D57) time cannot advance past it.
    Left out of the squad, the user watches from the stands and the match is
    simulated here like any other — otherwise it would stay 'scheduled'
    forever and the season could never finish."""
    user_team_id = _user_team_id(conn, career_id)
    skip_fixture_id = user_match_today(conn, career_id, on_date, seed)
    rows = conn.execute(
        "SELECT * FROM fixture WHERE career_id = ? AND status = 'scheduled' AND kickoff_at LIKE ? "
        "AND (home_team_id != ? AND away_team_id != ? OR fixture_id != COALESCE(?, ''))",
        (career_id, f"{on_date}%", user_team_id, user_team_id, skip_fixture_id),
    ).fetchall()
    if not rows:
        return {"count": 0, "competitions": set(), "results": []}

    teams_cache = {}

    def _team(team_id):
        if team_id not in teams_cache:
            teams_cache[team_id] = conn.execute(
                "SELECT * FROM team WHERE career_id = ? AND team_id = ?", (career_id, team_id)
            ).fetchone()
        return teams_cache[team_id]

    matches_payload = []
    fixture_by_ref = {}
    for r in rows:
        matches_payload.append({
            "ref": r["fixture_id"],
            "teams": {
                "home": _team_engine_fields(_team(r["home_team_id"])),
                "away": _team_engine_fields(_team(r["away_team_id"])),
            },
            "seed": _fixture_rng(seed, r["fixture_id"]).randint(0, 2**31 - 1),
        })
        fixture_by_ref[r["fixture_id"]] = r

    results = engine_client.simulate_batch(matches_payload)
    competitions: Set[str] = set()
    played = []  # {"fixture_id", "score"} per result — M2's "other_results" needs this
    for result in results:
        fixture_row = fixture_by_ref[result["ref"]]
        conn.execute(
            "UPDATE fixture SET status = 'played', home_score = ?, away_score = ? "
            "WHERE career_id = ? AND fixture_id = ?",
            (result["score"]["home"], result["score"]["away"], career_id, result["ref"]),
        )
        for side in ("home", "away"):
            s = result["stats"][side]
            conn.execute(
                "INSERT INTO fixture_team_stat (career_id, fixture_id, side, goals, shots, "
                "shots_on_target, corners, dangerous_attacks, total_attacks, yellow_cards, "
                "red_cards, penalties, penalty_goals, fouls, substitutions, possession_ticks) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (career_id, result["ref"], side, s["goals"], s["shots"], s["shots_on_target"],
                 s["corners"], s["dangerous_attacks"], s["total_attacks"], s["yellow_cards"],
                 s["red_cards"], s["penalties"], s["penalty_goals"], s["fouls"],
                 s["substitutions"], s["possession_ticks"]),
            )
        competitions.add(fixture_row["competition_id"])
        played.append({"fixture_id": result["ref"], "score": result["score"]})

    return {"count": len(results), "competitions": competitions, "results": played}


def _decide_winner(seed: int, fixture_row: sqlite3.Row) -> str:
    home, away = fixture_row["home_team_id"], fixture_row["away_team_id"]
    if fixture_row["home_score"] > fixture_row["away_score"]:
        return home
    if fixture_row["away_score"] > fixture_row["home_score"]:
        return away
    # Knockout tie with no penalty-shootout mechanic yet — a deterministic
    # coin flip, reproducible from the career's own seed.
    return _fixture_rng(seed, "tiebreak", fixture_row["fixture_id"]).choice([home, away])


def _draw_cup_round(conn: sqlite3.Connection, career_id: str, round_no: int, on_date: str, seed: int) -> None:
    season_id = _current_season(conn, career_id)
    prev_rows = conn.execute(
        "SELECT * FROM fixture WHERE career_id = ? AND season_id = ? "
        "AND competition_id = ? AND round_no = ?",
        (career_id, season_id, ULUSAL_KUPA, round_no - 1),
    ).fetchall()
    winners = [_decide_winner(seed, r) for r in prev_rows]

    kickoff = f"{on_date}T20:00:00+03:00"
    fixtures = scheduling.draw_cup_round(
        career_id, season_id, ULUSAL_KUPA, round_no, kickoff, winners,
        rng=_fixture_rng(seed, ULUSAL_KUPA, round_no),
    )
    conn.executemany(
        "INSERT INTO fixture (career_id, fixture_id, season_id, competition_id, round_no, leg, "
        "kickoff_at, home_team_id, away_team_id, status, home_score, away_score, match_id) "
        "VALUES (:career_id, :fixture_id, :season_id, :competition_id, :round_no, :leg, "
        ":kickoff_at, :home_team_id, :away_team_id, :status, :home_score, :away_score, :match_id)",
        fixtures,
    )
    conn.execute(
        "UPDATE competition_round SET drawn = 1 "
        "WHERE career_id = ? AND season_id = ? AND competition_id = ? AND round_no = ?",
        (career_id, season_id, ULUSAL_KUPA, round_no),
    )


def resolve_pending_monday(conn: sqlite3.Connection, career_id: str, on_date: str) -> Optional[dict]:
    """§6.5 D29 - if on_date is a Monday whose wage was never paid (the
    advance loop stopped there last time on an upkeep_warning without
    processing it, giving the user a chance to react), force it through
    now: pay wage, then upkeep — evicting items per D29 step 3 if still
    short, rather than warning a second time. Called once at the start of
    T3, before the forward loop, so a stuck Monday can't be skipped
    forever. Returns None if on_date isn't a pending Monday."""
    if _dt.date.fromisoformat(on_date).weekday() != config.WAGE_WEEKDAY:
        return None
    already_paid = conn.execute(
        "SELECT 1 FROM money_ledger WHERE career_id = ? AND kind = 'wage' AND reason = ?",
        (career_id, f"wage:{on_date}"),
    ).fetchone()
    if already_paid:
        return None

    ledger_entries = []
    wage_entry = _pay_wage(conn, career_id, on_date)
    if wage_entry:
        ledger_entries.append(wage_entry)
    # §12.7 - sponsorship money arrives on the same Monday, and BEFORE the
    # upkeep is taken: it is income, and letting a villa be repossessed while
    # a cheque sits uncashed would be wrong in the obvious way.
    ledger_entries += sponsorship.pay_weekly(conn, career_id, on_date)
    upkeep_entries, repossessed = _pay_upkeep(conn, career_id, on_date)
    ledger_entries += upkeep_entries
    return {"ledger_entries": ledger_entries, "repossessed": repossessed}


def resolve_pending_today(conn: sqlite3.Connection, career_id: str, on_date: str, seed: int) -> dict:
    """Closes out the day the career is currently sitting on, which T3 is
    about to leave: a freshly-created career already sits ON its
    season-opening date without ever having 'advanced into' it (onboarding
    doesn't call match_engine — career creation shouldn't depend on a live
    engine connection), so that date's OTHER fixtures never got
    background-simulated, and any cup round due today hasn't been drawn.

    The user's own fixture is never touched here (§6.1 D57): if it's still
    'scheduled' on on_date, the door at the top of T3
    (`api/routers/time.py`'s `match_day_unplayed` gate) has already refused
    to let the caller reach this function at all — there is no "missed
    match" case left to handle.

    Idempotent: _simulate_day_fixtures only touches still-'scheduled' rows,
    so calling this again for an already-resolved date is a no-op."""
    # §12.7 - one sponsorship roll a day, after the social one so the two
    # cannot both open on the same morning and stack two decisions.
    deal = sponsorship.maybe_generate(conn, career_id, on_date, seed)
    if deal:
        events.append({"kind": "sponsorship_offer", "ref_id": deal["deal_id"]})

    sim = _simulate_day_fixtures(conn, career_id, on_date, seed)

    cup_round = _next_drawable_cup_round(conn, career_id, on_date)
    if cup_round:
        _draw_cup_round(conn, career_id, cup_round["round_no"], on_date, seed)
    return {
        "fixtures_simulated": sim["count"],
        "competitions_touched": sim["competitions"],
        "news_created": [],
    }


def process_day(conn: sqlite3.Connection, career_id: str, on_date: str, seed: int) -> dict:
    """Applies one day's wage/upkeep (if due), background-simulates every
    non-user fixture, draws the next cup round if ready. Does NOT move
    career_state.game_date — the caller (T3) does that once, after this
    returns, alongside day_budget refill."""
    events = list_events(conn, career_id, on_date, seed)
    is_monday = _dt.date.fromisoformat(on_date).weekday() == config.WAGE_WEEKDAY
    warned_today = any(e["kind"] == "upkeep_warning" for e in events)

    ledger_entries, news_created, repossessed = [], [], []

    if is_monday:
        # §12.7 - sponsorship money lands on Monday whatever else happens.
        # Outside the warned/else split on purpose: income arriving is not
        # conditional on the upkeep being affordable, and it is exactly what
        # might make it affordable.
        ledger_entries += sponsorship.pay_weekly(conn, career_id, on_date)

        if warned_today:
            shortfall = next(e["shortfall"] for e in events if e["kind"] == "upkeep_warning")
            news_created.append(_create_news(
                conn, career_id, "Analiz", "Bütçe uyarısı",
                f"Önümüzdeki düzenli gider ({shortfall} ₭ açık) karşılanamayabilir.", on_date,
            ))
        else:
            wage_entry = _pay_wage(conn, career_id, on_date)
            if wage_entry:
                ledger_entries.append(wage_entry)
            upkeep_entries, sold = _pay_upkeep(conn, career_id, on_date)
            ledger_entries += upkeep_entries
            repossessed += sold

    # §6.3: every advanced day gets natural condition recovery, not just
    # ones with a lifestyle activity applied via T2. §6.6: the rate is no
    # longer flat — owned items raise it — but the number is computed in
    # exactly one place (condition.daily_recovery) so T1's preview and this
    # application can't disagree.
    recovery = condition.daily_recovery(conn, career_id)
    condition.apply_delta(conn, career_id, recovery["total"])

    # §6.3 D53: the day's chance of a social offer. After the recovery so a
    # template whose accept branch costs condition is priced against the
    # condition the player will actually have, and BEFORE list_events is
    # re-read below — a freshly opened offer has to be in the events the
    # caller stops on, or the day it arrived would pass unremarked.
    offer = social.maybe_generate(conn, career_id, on_date, seed)
    if offer:
        events.append({
            "kind": "social_offer",
            "ref_id": offer["offer_id"],
            "relationship_id": offer["relationship_id"],
            "opened_on": offer["opened_on"],
        })

    sim = _simulate_day_fixtures(conn, career_id, on_date, seed)

    cup_round = _next_drawable_cup_round(conn, career_id, on_date)
    if cup_round:
        _draw_cup_round(conn, career_id, cup_round["round_no"], on_date, seed)

    return {
        "events": events,
        "social_offer": offer,
        "condition_recovery": recovery,
        "ledger_entries": ledger_entries,
        "news_created": news_created,
        "repossessed": repossessed,
        "fixtures_simulated": sim["count"],
        "competitions_touched": sim["competitions"],
    }
