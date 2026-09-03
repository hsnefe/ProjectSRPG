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
from domain import condition, engine_client, formulas, news, scheduling, wallet
from worlddata.competitions import ULUSAL_KUPA


def _current_season(conn: sqlite3.Connection, career_id: str) -> str:
    return conn.execute(
        "SELECT season_id FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["season_id"]


def _user_team_id(conn: sqlite3.Connection, career_id: str) -> str:
    return conn.execute(
        "SELECT team_id FROM player WHERE career_id = ? AND is_user = 1", (career_id,)
    ).fetchone()["team_id"]


def _latest_contract(conn: sqlite3.Connection, career_id: str) -> Optional[sqlite3.Row]:
    return conn.execute(
        "SELECT * FROM player_contract WHERE career_id = ? AND player_id = ? "
        "ORDER BY signed_at DESC LIMIT 1",
        (career_id, config.USER_PLAYER_ID),
    ).fetchone()


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


def _is_cup_round_complete(conn: sqlite3.Connection, career_id: str, round_no: int) -> bool:
    row = conn.execute(
        "SELECT COUNT(*) AS total, SUM(CASE WHEN status = 'played' THEN 1 ELSE 0 END) AS played "
        "FROM fixture WHERE career_id = ? AND competition_id = ? AND round_no = ?",
        (career_id, ULUSAL_KUPA, round_no),
    ).fetchone()
    return row["total"] > 0 and row["total"] == row["played"]


def _next_drawable_cup_round(conn: sqlite3.Connection, career_id: str, on_date: str) -> Optional[sqlite3.Row]:
    """The next undrawn cup round, if today is its scheduled day (or
    later — see module docstring: a round can't draw until the previous
    one is fully played, which may lag its nominal date if the user's own
    tie hasn't been resolved yet) AND the previous round is complete."""
    row = conn.execute(
        "SELECT round_no, scheduled_on FROM competition_round "
        "WHERE career_id = ? AND competition_id = ? AND drawn = 0 "
        "ORDER BY round_no ASC LIMIT 1",
        (career_id, ULUSAL_KUPA),
    ).fetchone()
    if row is None or row["scheduled_on"] > on_date:
        return None
    if not _is_cup_round_complete(conn, career_id, row["round_no"] - 1):
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
STOP_EVENT_KINDS = {"match", "cup_draw", "upkeep_warning", "season_end"}


def stop_worthy(events: List[dict]) -> List[dict]:
    """The subset of list_events() output that T3 may stop on."""
    out = []
    for event in events:
        if event["kind"] in STOP_EVENT_KINDS:
            out.append(event)
        elif event["kind"] == "contract_expiring" and event["days_left"] == config.CONTRACT_EXPIRING_DAYS:
            out.append(event)
    return out


def list_events(conn: sqlite3.Connection, career_id: str, on_date: str) -> List[dict]:
    """Every event condition true for on_date, read-only."""
    events = []
    user_team_id = _user_team_id(conn, career_id)

    match_row = conn.execute(
        "SELECT fixture_id FROM fixture WHERE career_id = ? AND status = 'scheduled' "
        "AND kickoff_at LIKE ? AND (home_team_id = ? OR away_team_id = ?)",
        (career_id, f"{on_date}%", user_team_id, user_team_id),
    ).fetchone()
    if match_row:
        events.append({"kind": "match", "ref_id": match_row["fixture_id"]})

    cup_round = _next_drawable_cup_round(conn, career_id, on_date)
    if cup_round:
        events.append({"kind": "cup_draw", "ref_id": ULUSAL_KUPA, "round_no": cup_round["round_no"]})

    contract = _latest_contract(conn, career_id)
    if contract:
        days_left = (_dt.date.fromisoformat(contract["expires_at"]) - _dt.date.fromisoformat(on_date)).days
        if 0 <= days_left <= config.CONTRACT_EXPIRING_DAYS:
            events.append({"kind": "contract_expiring", "ref_id": None, "days_left": days_left})

    if _dt.date.fromisoformat(on_date).weekday() == config.WAGE_WEEKDAY:
        shortfall = _projected_upkeep_shortfall(conn, career_id)
        if shortfall > 0:
            events.append({"kind": "upkeep_warning", "ref_id": None, "shortfall": shortfall})

    low_rows = conn.execute(
        "SELECT relationship_id FROM relationship WHERE career_id = ? AND score < ?",
        (career_id, config.RELATIONSHIP_LOW_THRESHOLD),
    ).fetchall()
    for r in low_rows:
        events.append({"kind": "relationship_low", "ref_id": r["relationship_id"]})

    season = conn.execute(
        "SELECT ends_on FROM season WHERE career_id = ? ORDER BY ends_on DESC LIMIT 1", (career_id,)
    ).fetchone()
    if season and on_date >= season["ends_on"]:
        events.append({"kind": "season_end", "ref_id": None})

    return events


def _item_title(item_id: str) -> str:
    """The shop catalog's display name for an owned item, for the news
    layer's `{item}` slot. A repossession headline that reads
    'estate-villa satıldı' would be the generator showing its plumbing."""
    from catalog.shop import SHOP_ITEMS

    item = next((i for i in SHOP_ITEMS if i["catalog_id"] == item_id), None)
    return item["title"] if item else item_id


def match_facts(
    conn: sqlite3.Connection, career_id: str, fixture_id: str, *, goals: int = 0, assists: int = 0,
) -> dict:
    """The `**facts` a match trigger hands the news layer, read back from
    the fixture row after it has been marked 'played'.

    Lives here rather than in domain/news.py because it is fixture
    knowledge, not press knowledge — news.py deliberately knows nothing
    about competitions or sides. Both match triggers use it so a missed
    match and a played one describe the same scoreline the same way
    (M2 in domain/matches.py, the catch-up path below).
    """
    from api import serializers

    row = conn.execute(
        "SELECT * FROM fixture WHERE career_id = ? AND fixture_id = ?", (career_id, fixture_id)
    ).fetchone()
    user_team_id = _user_team_id(conn, career_id)
    home_ref = serializers.fetch_team_ref(conn, career_id, row["home_team_id"])
    away_ref = serializers.fetch_team_ref(conn, career_id, row["away_team_id"])

    user_is_home = row["home_team_id"] == user_team_id
    own = row["home_score"] if user_is_home else row["away_score"]
    other = row["away_score"] if user_is_home else row["home_score"]
    opponent = away_ref if user_is_home else home_ref

    competition = serializers.fetch_competition_ref(conn, career_id, row["competition_id"])
    is_cup = conn.execute(
        "SELECT 1 FROM competition WHERE career_id = ? AND competition_id = ? AND kind != 'league'",
        (career_id, row["competition_id"]),
    ).fetchone() is not None

    return {
        "fixture_id": fixture_id,
        # `score` is the bare result, `scoreline` names the clubs. Both are
        # offered because a tabloid headline wants the short one and a
        # report headline wants the long one.
        "score": f"{row['home_score']}-{row['away_score']}",
        "scoreline": f"{home_ref['name']} {row['home_score']}-{row['away_score']} {away_ref['name']}",
        "opponent_name": opponent["name"],
        "opponent_short": opponent["short_name"],
        "competition_name": competition["name"] if competition else row["competition_id"],
        "is_cup": is_cup,
        "result": "win" if own > other else "loss" if own < other else "draw",
        "goal_diff": own - other,
        "goals": goals,
        "assists": assists,
    }


def _pay_wage(conn: sqlite3.Connection, career_id: str, on_date: str) -> Optional[dict]:
    contract = _latest_contract(conn, career_id)
    if not contract or contract["weekly_wage"] <= 0:
        return None
    return wallet.apply(
        conn, career_id, contract["weekly_wage"], "wage", f"wage:{on_date}", f"{on_date}T00:00:00+03:00"
    )


def _pay_upkeep(conn: sqlite3.Connection, career_id: str, on_date: str, seed: int) -> tuple:
    """D27/D29: pays SUM(inventory.upkeep_weekly); if the balance (already
    including this Monday's wage) can't cover it, sells the highest-upkeep
    item at 50% refund and retries — repeatedly, per D29 step 3 — until
    covered or nothing is left to sell.

    Returns (ledger_entries, repossessed_item_ids, news_ids). The press is
    told ONCE, after the loop, even when D29 had to sell three things: the
    `money_trouble` trigger is capped at one story (MAX_STORIES_PER_TRIGGER)
    because a fire sale is one event, not three, and three articles at the
    same minute is precisely the collision the publishing slots exist to
    prevent."""
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

    news_created = []
    if repossessed:
        news_created = news.generate(
            conn, career_id, trigger="money_trouble", on_date=on_date, seed=seed,
            # The first item sold is the one the headline names: D29 sells
            # highest-upkeep first, so it is also the biggest loss.
            item_id=repossessed[0],
            item_title=_item_title(repossessed[0]),
            repossessed_count=len(repossessed),
        )

    return entries, repossessed, news_created


def _team_engine_fields(row: sqlite3.Row) -> dict:
    rating = formulas.compute_team_rating(dict(row))
    return {"name": row["name"], "mentality": row["mentality"], **rating}


def _fixture_rng(seed: int, *parts) -> random.Random:
    return random.Random(f"{seed}:" + ":".join(str(p) for p in parts))


def _simulate_day_fixtures(
    conn: sqlite3.Connection, career_id: str, on_date: str, seed: int, include_user: bool = False,
) -> dict:
    """§6.7 D40: every scheduled fixture kicking off on_date, in every
    competition. The user's own is normally excluded (it stays 'scheduled'
    and is played interactively via M1-M3); `include_user` is for the one
    case where it isn't — the user advancing off their own match day
    without playing it (§6.1's missed match, see resolve_pending_today)."""
    user_team_id = _user_team_id(conn, career_id)
    if include_user:
        rows = conn.execute(
            "SELECT * FROM fixture WHERE career_id = ? AND status = 'scheduled' AND kickoff_at LIKE ?",
            (career_id, f"{on_date}%"),
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT * FROM fixture WHERE career_id = ? AND status = 'scheduled' AND kickoff_at LIKE ? "
            "AND home_team_id != ? AND away_team_id != ?",
            (career_id, f"{on_date}%", user_team_id, user_team_id),
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
    prev_rows = conn.execute(
        "SELECT * FROM fixture WHERE career_id = ? AND competition_id = ? AND round_no = ?",
        (career_id, ULUSAL_KUPA, round_no - 1),
    ).fetchall()
    winners = [_decide_winner(seed, r) for r in prev_rows]

    season_id = _current_season(conn, career_id)
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


def resolve_pending_monday(
    conn: sqlite3.Connection, career_id: str, on_date: str, seed: int
) -> Optional[dict]:
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
    upkeep_entries, repossessed, news_created = _pay_upkeep(conn, career_id, on_date, seed)
    ledger_entries += upkeep_entries
    return {
        "ledger_entries": ledger_entries,
        "repossessed": repossessed,
        "news_created": news_created,
    }


def resolve_pending_today(conn: sqlite3.Connection, career_id: str, on_date: str, seed: int) -> dict:
    """Closes out the day the career is currently sitting on, which T3 is
    about to leave. Two things land here:

    1. A freshly-created career already sits ON its season-opening date
       without ever having 'advanced into' it (onboarding doesn't call
       match_engine — career creation shouldn't depend on a live engine
       connection), so that date's fixtures never got background-simulated.
    2. §6.1's missed match: if the user's own fixture is still 'scheduled'
       today, they chose to advance instead of playing it. The match is
       played in the background like any other — the result counts for the
       table, but no appearance, bonus or goal is credited (they weren't
       there). The alternative, refusing to advance, would soft-lock the
       career whenever match_engine can't be reached.

    Idempotent: _simulate_day_fixtures only touches still-'scheduled' rows,
    so calling this again for an already-resolved date is a no-op."""
    user_team_id = _user_team_id(conn, career_id)
    missed = conn.execute(
        "SELECT fixture_id FROM fixture WHERE career_id = ? AND status = 'scheduled' "
        "AND kickoff_at LIKE ? AND (home_team_id = ? OR away_team_id = ?)",
        (career_id, f"{on_date}%", user_team_id, user_team_id),
    ).fetchall()

    sim = _simulate_day_fixtures(conn, career_id, on_date, seed, include_user=bool(missed))

    # §6.1's missed match, told by the press. No goals/assists are passed
    # because none were credited — the player wasn't there (D13).
    news_created = []
    for row in missed:
        news_created += news.generate(
            conn, career_id, trigger="match_missed", on_date=on_date, seed=seed,
            **match_facts(conn, career_id, row["fixture_id"]),
        )

    cup_round = _next_drawable_cup_round(conn, career_id, on_date)
    if cup_round:
        _draw_cup_round(conn, career_id, cup_round["round_no"], on_date, seed)
    return {
        "fixtures_simulated": sim["count"],
        "competitions_touched": sim["competitions"],
        "missed_matches": [row["fixture_id"] for row in missed],
        "news_created": news_created,
    }


def process_day(conn: sqlite3.Connection, career_id: str, on_date: str, seed: int) -> dict:
    """Applies one day's wage/upkeep (if due), background-simulates every
    non-user fixture, draws the next cup round if ready. Does NOT move
    career_state.game_date — the caller (T3) does that once, after this
    returns, alongside day_budget refill."""
    events = list_events(conn, career_id, on_date)
    is_monday = _dt.date.fromisoformat(on_date).weekday() == config.WAGE_WEEKDAY
    warned_today = any(e["kind"] == "upkeep_warning" for e in events)

    ledger_entries, news_created, repossessed = [], [], []

    if is_monday:
        if warned_today:
            shortfall = next(e["shortfall"] for e in events if e["kind"] == "upkeep_warning")
            news_created += news.generate(
                conn, career_id, trigger="upkeep_warning", on_date=on_date, seed=seed,
                shortfall=shortfall,
            )
        else:
            wage_entry = _pay_wage(conn, career_id, on_date)
            if wage_entry:
                ledger_entries.append(wage_entry)
            upkeep_entries, sold, sale_news = _pay_upkeep(conn, career_id, on_date, seed)
            ledger_entries += upkeep_entries
            repossessed += sold
            news_created += sale_news

    # §6.3: every advanced day gets natural condition recovery, not just
    # ones with a lifestyle activity applied via T2.
    condition.apply_delta(conn, career_id, config.NATURAL_CONDITION_RECOVERY_PER_DAY)

    sim = _simulate_day_fixtures(conn, career_id, on_date, seed)

    cup_round = _next_drawable_cup_round(conn, career_id, on_date)
    if cup_round:
        _draw_cup_round(conn, career_id, cup_round["round_no"], on_date, seed)

    # The ambient news of the world, last: the transfer arc and the analysis
    # archetypes read form and the table, so they must see the day's other
    # results rather than yesterday's. Cheap on a quiet day — day_tick rolls
    # its "is anyone even writing" chance before touching the database.
    news_created += news.generate(
        conn, career_id, trigger="day_tick", on_date=on_date, seed=seed,
    )

    return {
        "events": events,
        "ledger_entries": ledger_entries,
        "news_created": news_created,
        "repossessed": repossessed,
        "fixtures_simulated": sim["count"],
        "competitions_touched": sim["competitions"],
    }
