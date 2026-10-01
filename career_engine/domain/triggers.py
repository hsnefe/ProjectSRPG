"""§14.5 D91-D93, INV-70 - what makes a relationship event arrive.

One trigger infrastructure with four inputs, all of them things career_engine can
actually see:

- **the calendar** (`run_calendar`, from daytime.process_day): birthdays, the
  anniversary, six months left on the contract, a derby three days off, a fixed
  gala - plus seeded daily rolls for the "it just happens" events (a loan request,
  a rumour, a reporter).
- **a finished match** (`run_post_match`, from matches.apply_result): a win, a loss,
  a red card, being left on the bench, a losing streak, the old club, your first
  goal. Only the *result* is here; in-match moments are ⟦AÇIK-19⟧ (§14.7).
- **an activity going wrong** (`run_activity`, from T2): the dressing-room joke that
  backfired.
- **a due consequence** (domain/deferred.py), which queues a follow-up.

A trigger never opens anything. It writes a **candidate** to `event_candidate`;
`promote` is the only function that turns one into an `activity_event`, which
makes it the only place INV-62 ("one open at a time") has to be respected and the
only place the queue's order is decided.

**The queue (D92).** Highest `priority` first, oldest first within a priority. A
candidate waits `expires_in_days` (a birthday two days, the contract talk two
weeks) and is then dropped unseen - a birthday that nobody got to is not still a
birthday a month later, INV-63's reasoning moved one step earlier. An event that is
already open blocks promotion outright, and so does having opened another one
within `TRIGGER_EVENT_MIN_GAP_DAYS`: the triggers are numerous and the player has
a season to play, so the queue is what keeps them from arriving as a wall.

**Dedupe (INV-70).** `dedupe_key` is unique per career, so firing the same trigger
twice - a retried advance, a match applied and re-read - queues once. A daily roll
is keyed by season (each such event is at most a once-a-season thing); a date
event by its date; a post-match one by its fixture.

Everything random is `random.Random(f"{seed}:...")` (INV-7): the same career
replayed the same way gets the same birthdays and the same bad weeks.

Like every domain module: nothing here commits.
"""
import datetime as _dt
import random
import sqlite3
from typing import Iterable, List, Optional

from api import config
from api.ids import new_activity_event_id, new_event_candidate_id
from content.relationship_events import RELATIONSHIP_EVENTS, SPECIAL_DAYS
from domain import activity_events, contracts, form, relationships, requirements, sponsorship
from domain import season as season_mod
from domain import transfer

QUEUED = "queued"
OPENED = "opened"
EXPIRED = "expired"

_BY_ID = {e["template_id"]: e for e in RELATIONSHIP_EVENTS}

LOW_CONDITION = 45


# --- the queue ---------------------------------------------------------------


def enqueue(
    conn: sqlite3.Connection, career_id: str, template_id: str, trigger_kind: str,
    on_date: str, dedupe_key: str,
) -> bool:
    """Queues a candidate. False when it was already queued (INV-70) or the same
    template is still waiting - one birthday at a time, not one per trigger."""
    tpl = _BY_ID[template_id]
    if conn.execute(
        "SELECT 1 FROM event_candidate WHERE career_id = ? AND template_id = ? AND status = ?",
        (career_id, template_id, QUEUED),
    ).fetchone():
        return False
    expires_on = (_dt.date.fromisoformat(on_date) + _dt.timedelta(days=tpl["expires_in_days"])).isoformat()
    cursor = conn.execute(
        "INSERT OR IGNORE INTO event_candidate (career_id, candidate_id, template_id, trigger_kind, "
        "priority, dedupe_key, created_on, expires_on, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (career_id, new_event_candidate_id(), template_id, trigger_kind, tpl["priority"],
         dedupe_key, on_date, expires_on, QUEUED),
    )
    return cursor.rowcount == 1


def list_queued(conn: sqlite3.Connection, career_id: str) -> List[dict]:
    rows = conn.execute(
        "SELECT * FROM event_candidate WHERE career_id = ? AND status = ? "
        "ORDER BY priority DESC, created_on, template_id",
        (career_id, QUEUED),
    ).fetchall()
    return [dict(r) for r in rows]


def _still_valid(conn: sqlite3.Connection, career_id: str, tpl: dict) -> bool:
    """A candidate can outlive the state that justified it by a couple of days: a
    partner event is worthless once the partner is gone."""
    if tpl["relationship"] == "partner":
        return relationships.get_state(conn, career_id, "partner") != config.STATE_ABSENT
    return requirements.met(conn, career_id, config.USER_PLAYER_ID, tpl.get("requires"))


def promote(conn: sqlite3.Connection, career_id: str, on_date: str) -> Optional[dict]:
    """Opens the best waiting candidate as an `activity_event`, if nothing stops it.
    Returns the event (T5's shape) or None."""
    conn.execute(
        "UPDATE event_candidate SET status = ? WHERE career_id = ? AND status = ? "
        "AND expires_on IS NOT NULL AND expires_on < ?",
        (EXPIRED, career_id, QUEUED, on_date),
    )
    if conn.execute(
        "SELECT 1 FROM activity_event WHERE career_id = ? AND status = ? LIMIT 1",
        (career_id, activity_events.OPEN),
    ).fetchone():
        return None  # INV-62

    gap_from = (_dt.date.fromisoformat(on_date) - _dt.timedelta(days=config.TRIGGER_EVENT_MIN_GAP_DAYS - 1)).isoformat()
    if conn.execute(
        "SELECT 1 FROM activity_event WHERE career_id = ? AND catalog_id LIKE 'trigger:%' "
        "AND opened_on >= ? LIMIT 1",
        (career_id, gap_from),
    ).fetchone():
        return None

    for row in list_queued(conn, career_id):
        tpl = _BY_ID[row["template_id"]]
        if not _still_valid(conn, career_id, tpl):
            continue
        event_id = new_activity_event_id()
        conn.execute(
            "INSERT INTO activity_event (career_id, event_id, template_id, catalog_id, opened_on, "
            "status, chosen_option, resolved_on) VALUES (?, ?, ?, ?, ?, ?, NULL, NULL)",
            (career_id, event_id, tpl["template_id"], f"trigger:{row['trigger_kind']}",
             on_date, activity_events.OPEN),
        )
        conn.execute(
            "UPDATE event_candidate SET status = ? WHERE career_id = ? AND candidate_id = ?",
            (OPENED, career_id, row["candidate_id"]),
        )
        return activity_events.get(conn, career_id, event_id)
    return None


# --- the calendar ------------------------------------------------------------


def _mmdd(seed: int, key: str) -> str:
    """A stable month-day for something the game has no data for (whose birthday,
    which day the anniversary falls on). Day 1-28 so every year has it."""
    rng = random.Random(f"{seed}:calendar:{key}")
    return f"{rng.randint(1, 12):02d}-{rng.randint(1, 28):02d}"


def rivals(conn: sqlite3.Connection, career_id: str, seed: int) -> List[str]:
    """The user's team's two derby opponents, picked once from its own league by the
    career seed. There is no derby data in the world; this gives two opponents that
    stay the same for as long as the player stays in the division."""
    team_id = _user_team_id(conn, career_id)
    season_id = conn.execute(
        "SELECT season_id FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["season_id"]
    from api import serializers

    league = serializers.fetch_user_league_competition_id(conn, career_id, season_id)
    if league is None:
        return []
    teams = sorted(
        r["team_id"] for r in conn.execute(
            "SELECT team_id FROM competition_entry WHERE career_id = ? AND season_id = ? "
            "AND competition_id = ? AND team_id != ?",
            (career_id, season_id, league, team_id),
        ).fetchall()
    )
    return random.Random(f"{seed}:rivals:{team_id}").sample(teams, min(2, len(teams)))


def _user_team_id(conn: sqlite3.Connection, career_id: str) -> str:
    return conn.execute(
        "SELECT team_id FROM player WHERE career_id = ? AND is_user = 1", (career_id,)
    ).fetchone()["team_id"]


def _need_met(conn: sqlite3.Connection, career_id: str, on_date: str, need: str) -> bool:
    if need == "partner_active":
        return relationships.get_state(conn, career_id, "partner") == config.STATE_ACTIVE
    if need == "sponsor_active":
        return bool(sponsorship.list_active(conn, career_id))
    if need == "offer_open":
        return bool(transfer.list_open(conn, career_id))
    if need == "window_open":
        return season_mod.transfer_window(season_mod.derive_phase(conn, career_id, on_date)) is not None
    if need == "low_condition":
        return conn.execute(
            "SELECT condition FROM career_state WHERE career_id = ?", (career_id,)
        ).fetchone()["condition"] < LOW_CONDITION
    raise ValueError(f"unknown need {need!r}")


def _date_fires(conn: sqlite3.Connection, career_id: str, on_date: str, seed: int, trigger: dict) -> bool:
    on = trigger["on"]
    if on == "birthday":
        return on_date[5:] == _mmdd(seed, f"birthday:{trigger['who']}")
    if on == "anniversary":
        return (
            relationships.get_state(conn, career_id, "partner") == config.STATE_ACTIVE
            and on_date[5:] == _mmdd(seed, "anniversary")
        )
    if on == "contract_left":
        contract = contracts.active_contract(conn, career_id, on_date)
        return contract is not None and contracts.days_until_expiry(contract, on_date) == trigger["days"]
    if on == "special_day":
        return (int(on_date[5:7]), int(on_date[8:10])) == SPECIAL_DAYS[trigger["day"]]
    if on == "derby_week":
        match_day = (_dt.date.fromisoformat(on_date) + _dt.timedelta(days=3)).isoformat()
        team_id = _user_team_id(conn, career_id)
        derby = set(rivals(conn, career_id, seed))
        rows = conn.execute(
            "SELECT home_team_id, away_team_id FROM fixture WHERE career_id = ? AND status = 'scheduled' "
            "AND kickoff_at LIKE ? AND (home_team_id = ? OR away_team_id = ?)",
            (career_id, f"{match_day}%", team_id, team_id),
        ).fetchall()
        return any({r["home_team_id"], r["away_team_id"]} & derby for r in rows)
    raise ValueError(f"unknown date trigger {on!r}")


def run_calendar(conn: sqlite3.Connection, career_id: str, on_date: str, seed: int) -> int:
    """One day's date events and daily rolls. Returns how many were queued."""
    if not config.TRIGGERS_ENABLED:
        return 0
    season_id = conn.execute(
        "SELECT season_id FROM career_state WHERE career_id = ?", (career_id,)
    ).fetchone()["season_id"]
    queued = 0
    for tpl in RELATIONSHIP_EVENTS:
        trigger = tpl["trigger"]
        if trigger["kind"] == "date":
            if _date_fires(conn, career_id, on_date, seed, trigger):
                queued += enqueue(conn, career_id, tpl["template_id"], "date", on_date,
                                  f"{tpl['template_id']}:{on_date}")
        elif trigger["kind"] == "daily":
            # The roll first - it is one float, the needs are queries.
            rng = random.Random(f"{seed}:trigger:{tpl['template_id']}:{on_date}")
            if rng.random() >= trigger["chance"]:
                continue
            if all(_need_met(conn, career_id, on_date, n) for n in trigger["needs"]):
                queued += enqueue(conn, career_id, tpl["template_id"], "daily", on_date,
                                  f"{tpl['template_id']}:{season_id}")
    return queued


# --- a finished match --------------------------------------------------------


def post_match_facts(
    conn: sqlite3.Connection, career_id: str, fixture: sqlite3.Row, body: dict, user_side: str,
    *, goal_count: int, minutes: int, started: bool, on_date: str,
) -> set:
    """The true statements about the match that just ended, from what M2 carries.
    Everything a trigger may ask (content POST_MATCH_FACTS) is decided here."""
    score = body["score"]
    opponent_side = "away" if user_side == "home" else "home"
    scored, conceded = score[user_side], score[opponent_side]
    facts = set()
    if scored > conceded:
        facts.add("win")
    elif scored < conceded:
        facts.add("loss")
        if body["stats"][user_side]["red_cards"] >= 1:
            facts.add("red_card_loss")
    if not started:
        facts.add("bench")
    if started and goal_count == 0 and scored >= 1:
        facts.add("no_goal")
    if started and 0 < minutes < 60:
        facts.add("subbed_early")

    team_id = _user_team_id(conn, career_id)
    if form.losing_streak(conn, career_id):      # §14.7: one definition of "bad form"
        facts.add("losing_streak")

    opponent_id = fixture["away_team_id"] if user_side == "home" else fixture["home_team_id"]
    former = {
        r["team_id"] for r in conn.execute(
            "SELECT DISTINCT team_id FROM player_contract WHERE career_id = ? AND player_id = ?",
            (career_id, config.USER_PLAYER_ID),
        ).fetchall()
    } - {team_id}
    if goal_count > 0 and opponent_id in former:
        facts.add("former_club_goal")

    if (int(on_date[5:7]), int(on_date[8:10])) == SPECIAL_DAYS["holiday"]:
        facts.add("special_day")

    if goal_count > 0:
        career_goals = conn.execute(
            "SELECT COALESCE(SUM(goals), 0) AS g FROM player_season_stat WHERE career_id = ? AND player_id = ?",
            (career_id, config.USER_PLAYER_ID),
        ).fetchone()["g"]
        if career_goals == goal_count:
            facts.add("first_goal")
    return facts


def run_post_match(
    conn: sqlite3.Connection, career_id: str, fixture: sqlite3.Row, facts: Iterable[str],
    on_date: str, seed: int,
) -> int:
    if not config.TRIGGERS_ENABLED:
        return 0
    facts = set(facts)
    queued = 0
    for tpl in RELATIONSHIP_EVENTS:
        trigger = tpl["trigger"]
        if trigger["kind"] != "post_match" or trigger["when"] not in facts:
            continue
        # A fact like "won" is true every other week; `chance` is what makes the
        # terrace moment something that sometimes happens.
        rng = random.Random(f"{seed}:trigger:{tpl['template_id']}:{fixture['fixture_id']}")
        if rng.random() >= trigger.get("chance", 1.0):
            continue
        queued += enqueue(conn, career_id, tpl["template_id"], "post_match", on_date,
                          f"{tpl['template_id']}:{fixture['fixture_id']}")
    return queued


# --- an activity going wrong -------------------------------------------------


def run_activity(conn: sqlite3.Connection, career_id: str, catalog_id: str, failed: bool, on_date: str) -> int:
    if not failed or not config.TRIGGERS_ENABLED:
        return 0
    queued = 0
    for tpl in RELATIONSHIP_EVENTS:
        trigger = tpl["trigger"]
        if trigger["kind"] == "activity" and trigger["catalog_id"] == catalog_id:
            queued += enqueue(conn, career_id, tpl["template_id"], "activity", on_date,
                              f"{tpl['template_id']}:{on_date}")
    return queued
