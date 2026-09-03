"""§3.5/§5.7 — the single write path for the `news` table, and the
generator that decides what gets written.

Two public entry points, mirroring the wallet/relationships/fame shape the
rest of this service uses:

    publish(...)   -> writes exactly one `news` row. INV-38: nothing else
                      in the codebase may INSERT INTO news. A test greps
                      the source tree for that, the same way test_wallet.py
                      replays the ledger against the balance.

    generate(...)  -> looks at one trigger, builds a read-only snapshot of
                      the career (NewsContext), asks every eligible story
                      archetype whether it applies, picks a deterministic
                      few, fills them in and publishes them.

Everything creative lives in `content/` (archetypes and outlets). This
module owns only the machinery: context assembly, eligibility, weighted
deterministic selection, cooldown, rumour arcs, and effect application.
The split is the same one catalog/ vs domain/ already draws — data files
get big, logic files stay readable (§6 red line 9).

Determinism (INV-7's spirit, extended to content): every random decision
comes from `random.Random(f"{seed}:news:{on_date}:{trigger}:{n}")`, the
same string-seeded pattern daytime._fixture_rng uses. Same seed + same date
+ same career state produces byte-identical headlines and bodies. Nothing
here ever touches the module-level `random`.

Effects (INV-24/INV-15): a story may move fame or a relationship, and it
does so ONLY through fame.apply() and relationships.apply_delta(). This
module writes `news`, `news_story_log` and `news_arc` directly and nothing
else — it has no privileged path to any other table.
"""
import datetime as _dt
import json
import random
import sqlite3
from dataclasses import dataclass, field
from typing import List, Optional

from api import config
from api.ids import new_news_id
from content import TRIGGERS
from content.news_outlets import OUTLETS_BY_ID, pick_outlet
from content.news_stories import STORIES
from domain import attributes as attributes_domain
from domain import fame as fame_domain
from domain import relationships as relationships_domain
from worlddata.teams import TIER1_TEAMS

# How many stories a single trigger may print. A day that produces three
# separate articles about the same player reads as a bug, not as a busy
# news day, so the ceiling is low everywhere and exactly 1 where a caller's
# response shape promises a single item.
#
# match_played is pinned at 1 on purpose: M2's response carries
# `news_created` and the match report is what FE opens from it. The
# analysis/milestone angles on the same match are NOT suppressed — they
# surface on the next day_tick instead, which is also how a real paper
# works (result at night, column the morning after).
MAX_STORIES_PER_TRIGGER = {
    "match_played": 1,
    "match_missed": 1,
    "interview": 1,
    "dialogue": 1,
    "lifestyle": 1,
    "training": 1,
    "purchase": 1,
    "day_tick": 2,
    "money_trouble": 1,
    "upkeep_warning": 1,
}

# Triggers whose news is *optional*: the event happened, but it is not
# automatically newsworthy. The value is the chance the press bothers at
# all, rolled before any DB work is done — which is also why day_tick is
# cheap on a quiet day (no context assembled, no standings computed).
#
# Anything not listed here always publishes if a story applies: a match
# result, a repossession and a budget warning are events the player took an
# action to reach, so silence would read as a dropped response.
TRIGGER_CHANCE = {
    "day_tick": 0.45,
    "dialogue": 0.35,
    "lifestyle": 0.30,
    "training": 0.12,   # nobody writes about a normal training session
    "purchase": 0.55,
}

# Publishing hour per trigger, so a day's items sort into a sensible order
# in N1 (which orders by published_at DESC and nothing else). The morning
# paper leads, the evening interview follows, the match report closes the
# day. Successive items from the same trigger are spaced 40 minutes apart.
_TRIGGER_HOUR = {
    "day_tick": (7, 0),
    "upkeep_warning": (9, 0),
    "money_trouble": (9, 30),
    "training": (12, 10),
    "interview": (18, 30),
    "dialogue": (19, 15),
    "purchase": (20, 5),
    "lifestyle": (21, 20),
    "match_missed": (22, 40),
    "match_played": (22, 45),
}

_MINUTES_BETWEEN_ITEMS = 40
_SLOT_SECONDS = _MINUTES_BETWEEN_ITEMS * 60

# The last second a story can be stamped with. A news row belongs to the day
# it reports on, so an item that would spill past midnight stays on this day
# (see _published_at) instead of turning a Monday repossession into Tuesday
# news.
_DAY_LAST_SECOND = 23 * 3600 + 59 * 60 + 59


# --- the single write path -------------------------------------------------

def publish(
    conn: sqlite3.Connection,
    career_id: str,
    *,
    category: str,
    title: str,
    body: str,
    source: str,
    published_at: str,
    fixture_id: Optional[str] = None,
    story_id: Optional[str] = None,
) -> str:
    """Writes one `news` row and returns its news_id (INV-38).

    `story_id` is optional because not every article comes from the
    archetype catalog — a hand-written one-off (or a test) is still a legal
    news item. When it IS given, the publication is also recorded in
    news_story_log, which is what cooldown reads back. The two tables are
    written in the same transaction and the caller commits, exactly like
    wallet.apply()/relationships.apply_delta().
    """
    news_id = new_news_id()
    conn.execute(
        "INSERT INTO news (career_id, news_id, published_at, category, title, source, body, fixture_id) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        (career_id, news_id, published_at, category, title, source, body, fixture_id),
    )
    if story_id is not None:
        conn.execute(
            "INSERT OR REPLACE INTO news_story_log (career_id, story_id, published_at, news_id) "
            "VALUES (?, ?, ?, ?)",
            (career_id, story_id, published_at, news_id),
        )
    return news_id


# --- the read-only snapshot archetypes see ---------------------------------

@dataclass(frozen=True)
class NewsContext:
    """Everything a story archetype is allowed to know, assembled once per
    generate() call. Frozen and DB-free on purpose: an `applies` lambda
    that could run its own query would make eligibility untestable and turn
    every day tick into an unbounded number of round trips.

    The dicts are plain data, not sqlite3.Row, so a body lambda can use
    .get() and dict literals without thinking about the driver.
    """
    career_id: str
    on_date: str
    trigger: str
    player: dict            # first_name, last_name, full_name, age, position, role
    team: dict              # team_id, name, short_name
    attributes: dict        # {'charisma': {'value': .., 'level': ..}, ...}
    condition: int
    fame: float
    money: int
    relationships: dict     # {'media': 34, 'partner': 61, ...}
    relationship_peaks: dict  # aynı anahtarlar, "en yüksek gördüğü değer"
    contract: Optional[dict]
    form: dict
    season_stats: dict
    standings: Optional[dict]
    inventory: List[str]
    recent_activities: List[dict]
    published_recently: dict
    arc: Optional[dict]
    facts: dict = field(default_factory=dict)

    # --- convenience readers used heavily by content/news_stories.py -------

    def rel(self, relationship_id: str) -> int:
        """0 for a relationship this career somehow lacks, rather than a
        KeyError — an archetype must never be able to crash a day tick."""
        return self.relationships.get(relationship_id, 0)

    def peak(self, relationship_id: str) -> int:
        """The highest this relationship has EVER been. `partner` and
        `family` both start at 0 (§4), so `rel(x) == 0` on its own cannot
        tell "it ended" from "it never began" — an archetype that wants to
        write about a loss has to check that there was something to lose.
        """
        return self.relationship_peaks.get(relationship_id, 0)

    def attr(self, key: str) -> float:
        return self.attributes.get(key, {}).get("value", 0.0)

    def level(self, key: str) -> int:
        return self.attributes.get(key, {}).get("level", 0)

    def owns(self, item_id: str) -> bool:
        return item_id in self.inventory

    def owns_any(self, prefix: str) -> bool:
        return any(i.startswith(prefix) for i in self.inventory)

    def did(self, catalog_id: str) -> bool:
        """Did the player do this catalog item in the last 7 days? Reads
        recent_activities, which is already limited to that window."""
        return any(a["catalog_id"] == catalog_id for a in self.recent_activities)

    def did_any(self, prefix: str) -> bool:
        return any(a["catalog_id"].startswith(prefix) for a in self.recent_activities)

    def fact(self, key, default=None):
        return self.facts.get(key, default)

    @property
    def goals(self) -> int:
        return self.season_stats["goals"]

    @property
    def appearances(self) -> int:
        return self.season_stats["appearances"]

    @property
    def rank(self) -> Optional[int]:
        return self.standings["rank"] if self.standings else None

    @property
    def contract_days_left(self) -> Optional[int]:
        return self.contract["days_left"] if self.contract else None


def _fetch_attributes(conn, career_id) -> dict:
    rows = conn.execute(
        "SELECT attribute_key, value FROM player_attribute WHERE career_id = ? AND player_id = ?",
        (career_id, config.USER_PLAYER_ID),
    ).fetchall()
    return {
        r["attribute_key"]: {"value": r["value"], "level": attributes_domain.level(r["value"])}
        for r in rows
    }


def _fetch_form(conn, career_id, team_id, on_date) -> dict:
    """The user's team's last five completed fixtures, newest first, folded
    into a W/D/L summary plus the current unbroken streak.

    Team form rather than personal form: per-match goal records don't exist
    (player_season_stat is an aggregate, D13), so "last five" can only mean
    the team's results. That is also the number a newspaper would print.
    """
    rows = conn.execute(
        "SELECT home_team_id, away_team_id, home_score, away_score, competition_id "
        "FROM fixture WHERE career_id = ? AND status = 'played' "
        "AND (home_team_id = ? OR away_team_id = ?) AND kickoff_at <= ? "
        "ORDER BY kickoff_at DESC LIMIT 5",
        (career_id, team_id, team_id, f"{on_date}T23:59:59"),
    ).fetchall()

    results = []
    for r in rows:
        own = r["home_score"] if r["home_team_id"] == team_id else r["away_score"]
        other = r["away_score"] if r["home_team_id"] == team_id else r["home_score"]
        results.append("W" if own > other else "L" if own < other else "D")

    streak_kind = results[0] if results else None
    streak_len = 0
    for res in results:
        if res != streak_kind:
            break
        streak_len += 1

    return {
        "w": results.count("W"),
        "d": results.count("D"),
        "l": results.count("L"),
        "played": len(results),
        "last_result": results[0] if results else None,
        "streak_kind": streak_kind,
        "streak_len": streak_len,
        "results": results,
    }


def _fetch_season_stats(conn, career_id, season_id) -> dict:
    row = conn.execute(
        "SELECT COALESCE(SUM(appearances), 0) AS appearances, COALESCE(SUM(goals), 0) AS goals, "
        "COALESCE(SUM(assists), 0) AS assists, COALESCE(SUM(minutes), 0) AS minutes "
        "FROM player_season_stat WHERE career_id = ? AND player_id = ? AND season_id = ?",
        (career_id, config.USER_PLAYER_ID, season_id),
    ).fetchone()
    return {
        "appearances": row["appearances"], "goals": row["goals"],
        "assists": row["assists"], "minutes": row["minutes"],
    }


def _fetch_standings(conn, career_id, season_id, team_id) -> Optional[dict]:
    from api import serializers

    league_id = serializers.fetch_user_league_competition_id(conn, career_id, season_id)
    if league_id is None:
        return None
    rows = serializers.fetch_full_standings(conn, career_id, season_id, league_id)
    own = next((r for r in rows if r["team_id"] == team_id), None)
    if own is None:
        return None
    comp = serializers.fetch_competition_ref(conn, career_id, league_id)
    return {
        "rank": own["rank"],
        "teams": len(rows),
        "points": own["points"],
        "played": own["played"],
        "competition": comp["name"] if comp else league_id,
        "competition_id": league_id,
    }


def _fetch_contract(conn, career_id, on_date) -> Optional[dict]:
    row = conn.execute(
        "SELECT * FROM player_contract WHERE career_id = ? AND player_id = ? "
        "ORDER BY signed_at DESC LIMIT 1",
        (career_id, config.USER_PLAYER_ID),
    ).fetchone()
    if row is None:
        return None
    days_left = (_dt.date.fromisoformat(row["expires_at"]) - _dt.date.fromisoformat(on_date)).days
    return {
        "weekly_wage": row["weekly_wage"],
        "expires_at": row["expires_at"],
        "days_left": days_left,
        "release_clause": row["release_clause"],
        "goal_bonus": row["goal_bonus"],
        "appearance_bonus": row["appearance_bonus"],
    }


def _fetch_recent_activities(conn, career_id, on_date, days=7) -> List[dict]:
    since = (_dt.date.fromisoformat(on_date) - _dt.timedelta(days=days)).isoformat()
    rows = conn.execute(
        "SELECT kind, catalog_id, happened_at FROM activity_log "
        "WHERE career_id = ? AND happened_at >= ? ORDER BY happened_at DESC",
        (career_id, since),
    ).fetchall()
    return [dict(r) for r in rows]


def _fetch_published_recently(conn, career_id) -> dict:
    rows = conn.execute(
        "SELECT story_id, MAX(published_at) AS last_at FROM news_story_log "
        "WHERE career_id = ? GROUP BY story_id",
        (career_id,),
    ).fetchall()
    return {r["story_id"]: r["last_at"] for r in rows}


def build_context(
    conn: sqlite3.Connection, career_id: str, *, trigger: str, on_date: str, facts: dict,
) -> Optional[NewsContext]:
    """One query burst, one frozen snapshot. Returns None when the career
    has no user player — a state only the domain-level test fixtures reach,
    but publish-time crashes are the worst possible failure mode for a
    cosmetic subsystem, so it is handled rather than asserted."""
    player_row = conn.execute(
        "SELECT name, first_name, last_name, position, role, birth_date, team_id, target_team_id "
        "FROM player WHERE career_id = ? AND is_user = 1",
        (career_id,),
    ).fetchone()
    if player_row is None:
        return None

    state = conn.execute(
        "SELECT game_date, season_id, money, condition FROM career_state WHERE career_id = ?",
        (career_id,),
    ).fetchone()
    if state is None:
        return None

    team_row = conn.execute(
        "SELECT team_id, name, short_name FROM team WHERE career_id = ? AND team_id = ?",
        (career_id, player_row["team_id"]),
    ).fetchone()
    team = dict(team_row) if team_row else {
        "team_id": player_row["team_id"], "name": player_row["team_id"], "short_name": "???",
    }

    birth = _dt.date.fromisoformat(player_row["birth_date"])
    today = _dt.date.fromisoformat(on_date)
    age = today.year - birth.year - ((today.month, today.day) < (birth.month, birth.day))

    rel_rows = conn.execute(
        "SELECT relationship_id, score, person_name, contact_name FROM relationship WHERE career_id = ?",
        (career_id,),
    ).fetchall()
    people = {r["relationship_id"]: r["person_name"] for r in rel_rows}

    inventory = [
        r["item_id"] for r in conn.execute(
            "SELECT item_id FROM inventory WHERE career_id = ?", (career_id,)
        ).fetchall()
    ]

    return NewsContext(
        career_id=career_id,
        on_date=on_date,
        trigger=trigger,
        player={
            "first_name": player_row["first_name"] or player_row["name"].split(" ")[0],
            "last_name": player_row["last_name"] or player_row["name"].split(" ")[-1],
            "full_name": player_row["name"],
            "age": age,
            "position": player_row["position"],
            "role": player_row["role"],
            "target_team_id": player_row["target_team_id"],
            "people": people,
        },
        team=team,
        attributes=_fetch_attributes(conn, career_id),
        condition=state["condition"],
        fame=fame_domain.get_value(conn, career_id, config.USER_PLAYER_ID),
        money=state["money"],
        relationships={r["relationship_id"]: r["score"] for r in rel_rows},
        relationship_peaks=relationships_domain.peak_scores(conn, career_id),
        contract=_fetch_contract(conn, career_id, on_date),
        form=_fetch_form(conn, career_id, team["team_id"], on_date),
        season_stats=_fetch_season_stats(conn, career_id, state["season_id"]),
        standings=_fetch_standings(conn, career_id, state["season_id"], team["team_id"]),
        inventory=inventory,
        recent_activities=_fetch_recent_activities(conn, career_id, on_date),
        published_recently=_fetch_published_recently(conn, career_id),
        arc=read_arc(conn, career_id, transfer_arc_id(conn, career_id)),
        facts=dict(facts),
    )


# --- rumour arcs -----------------------------------------------------------

# A transfer rumour is not a coin flip per day; it is a temperature that
# rises while the player is doing well and cools when nothing happens.
# `heat` is that temperature and `stage` is the part of the story the press
# has already printed. Splitting them is what makes the arc feel causal:
# the reader sees "ilgi var" before "teklif yapıldı", never the reverse,
# even though heat itself can wobble day to day.
ARC_STAGE_THRESHOLDS = ((80, 4), (60, 3), (40, 2), (20, 1))

ARC_HEAT_MIN = 0.0
ARC_HEAT_MAX = 100.0

# Every quiet day bleeds a little interest away. Without this the arc is a
# ratchet: one good month would keep the player "linked with a move" for
# the rest of the career.
ARC_DAILY_COOLING = 1.4


def stage_for_heat(heat: float) -> int:
    for threshold, stage in ARC_STAGE_THRESHOLDS:
        if heat >= threshold:
            return stage
    return 0


def transfer_heat_delta(ctx: NewsContext) -> float:
    """How much hotter (or cooler) the rumour gets today.

    Inputs are §2.1's list: form, fame, league position, contract runway
    and — standing in for a market value that does not exist yet
    (⟦AÇIK-8⟧) — the weekly wage as a crude "what tier is this player on"
    scale. Deliberately a pure function of the context so a test can drive
    it directly instead of walking a season.
    """
    delta = -ARC_DAILY_COOLING

    # Scoring is the loudest signal a scout has.
    if ctx.appearances:
        delta += 6.0 * (ctx.goals / ctx.appearances)
        delta += 2.5 * (ctx.season_stats["assists"] / ctx.appearances)

    # Fame is unbounded (⟦AÇIK-9⟧), so it is deliberately capped here rather
    # than trusted: this layer must not let one runaway number own the arc.
    delta += min(4.0, ctx.fame * 0.06)

    form = ctx.form
    delta += 0.7 * form["w"] - 0.5 * form["l"]

    if ctx.rank is not None and ctx.standings["teams"]:
        # Top of the table is a shop window; the bottom is not.
        share = ctx.rank / ctx.standings["teams"]
        if share <= 0.2:
            delta += 2.0
        elif share <= 0.4:
            delta += 1.0
        elif share >= 0.85:
            delta -= 1.0

    days_left = ctx.contract_days_left
    if days_left is not None:
        if days_left <= 90:
            delta += 2.2      # a nearly-free player is the cheapest story
        elif days_left <= 180:
            delta += 1.2

    if ctx.contract:
        # ⟦AÇIK-8⟧ stand-in: wage relative to the starting tier-2 scale.
        delta += min(2.0, ctx.contract["weekly_wage"] / max(1, config.STARTING_WEEKLY_WAGE) - 1.0)

    return delta


def transfer_arc_id(conn: sqlite3.Connection, career_id: str) -> str:
    """Which club is linked with the player. Fixed for the whole career and
    derived from the career's own seed, so the rumour does not change its
    mind about who the suitor is between two days of the same story.

    35% of the time it is the club the player themselves named as their
    target at creation (§5.1 C1's `target_team_id`) — that is the version of
    this story the player most wants to read — and otherwise a top-tier club
    picked by seed.
    """
    row = conn.execute("SELECT seed FROM career WHERE career_id = ?", (career_id,)).fetchone()
    seed = row["seed"] if row else 0
    rng = random.Random(f"{seed}:news:suitor")

    target = conn.execute(
        "SELECT target_team_id, team_id FROM player WHERE career_id = ? AND is_user = 1",
        (career_id,),
    ).fetchone()
    own_team_id = target["team_id"] if target else None
    target_team_id = target["target_team_id"] if target else None

    candidates = [t["team_id"] for t in TIER1_TEAMS if t["team_id"] != own_team_id]
    if target_team_id and target_team_id != own_team_id and rng.random() < 0.35:
        suitor = target_team_id
    else:
        suitor = rng.choice(candidates) if candidates else (target_team_id or "t_gal")
    return f"transfer:{suitor}"


def read_arc(conn: sqlite3.Connection, career_id: str, arc_id: str) -> Optional[dict]:
    row = conn.execute(
        "SELECT * FROM news_arc WHERE career_id = ? AND arc_id = ?", (career_id, arc_id)
    ).fetchone()
    if row is None:
        return None
    payload = json.loads(row["payload"]) if row["payload"] else {}
    return {
        "arc_id": row["arc_id"],
        "stage": row["stage"],
        "heat": row["heat"],
        "opened_on": row["opened_on"],
        "updated_on": row["updated_on"],
        "suitor_team_id": row["arc_id"].split(":", 1)[1],
        **payload,
    }


def touch_arc(conn: sqlite3.Connection, ctx: NewsContext) -> dict:
    """Advances the transfer rumour by one day and returns its new state.
    The only writer of news_arc.

    stage is monotone within an arc (`max(previous, derived)`): the press
    cannot un-print "teklif yapıldı" just because the player had a quiet
    week. Heat still falls, which is what eventually makes the club-denial
    story eligible — the arc ends by going cold in public, not by silently
    resetting.
    """
    arc_id = transfer_arc_id(conn, ctx.career_id)
    previous = read_arc(conn, ctx.career_id, arc_id)
    prev_heat = previous["heat"] if previous else 0.0
    prev_stage = previous["stage"] if previous else 0

    heat = max(ARC_HEAT_MIN, min(ARC_HEAT_MAX, prev_heat + transfer_heat_delta(ctx)))
    stage = max(prev_stage, stage_for_heat(heat))

    suitor_team_id = arc_id.split(":", 1)[1]
    suitor = conn.execute(
        "SELECT name, short_name FROM team WHERE career_id = ? AND team_id = ?",
        (ctx.career_id, suitor_team_id),
    ).fetchone()
    payload = json.dumps(
        {
            "suitor_name": suitor["name"] if suitor else suitor_team_id,
            "suitor_short": suitor["short_name"] if suitor else "???",
        },
        ensure_ascii=False,
    )

    conn.execute(
        "INSERT INTO news_arc (career_id, arc_id, stage, heat, opened_on, updated_on, payload) "
        "VALUES (?, ?, ?, ?, ?, ?, ?) "
        "ON CONFLICT (career_id, arc_id) DO UPDATE SET "
        "stage = excluded.stage, heat = excluded.heat, updated_on = excluded.updated_on, "
        "payload = excluded.payload",
        (ctx.career_id, arc_id, stage, heat, previous["opened_on"] if previous else ctx.on_date,
         ctx.on_date, payload),
    )
    return read_arc(conn, ctx.career_id, arc_id)


# --- slots -----------------------------------------------------------------

def _fmt_money(amount) -> str:
    """₺1.250.000 — Turkish thousands separator, no decimals. Money in a
    headline is a display string, never a raw int, so an archetype author
    cannot accidentally print '1250000'."""
    try:
        return "₺" + f"{int(amount):,}".replace(",", ".")
    except (TypeError, ValueError):
        return "₺0"


def build_slots(ctx: NewsContext, outlet: dict) -> dict:
    """The flat str->str map every headline is filled from. Its key set must
    equal content.SLOT_KEYS — a test asserts that, which is what makes the
    import-time headline check in content/__init__.py meaningful.

    Deliberately a plain dict and not a defaultdict: an archetype that
    references a slot nobody fills must raise KeyError loudly at
    format_map, not quietly print an empty headline.
    """
    people = ctx.player["people"]
    arc = ctx.arc or {}
    facts = ctx.facts
    contract = ctx.contract or {}

    return {
        "player": ctx.player["full_name"],
        "first_name": ctx.player["first_name"],
        "last_name": ctx.player["last_name"],
        "position": ctx.player["position"] or "futbolcu",
        "role": ctx.player["role"] or "oyuncu",
        "age": str(ctx.player["age"]),

        "team": ctx.team["name"],
        "team_short": ctx.team["short_name"],
        "coach": people.get("coach", "teknik direktör"),
        "captain": people.get("team", "kaptan"),
        "league": (ctx.standings or {}).get("competition", "lig"),
        "rank": str(ctx.rank) if ctx.rank else "—",

        "partner": people.get("partner", "sevgilisi"),
        "mother": people.get("family", "ailesi"),
        "reporter": outlet["reporter"],
        "outlet": outlet["name"],

        "rival": arc.get("suitor_name", "bir Süper Lig kulübü"),
        "rival_short": arc.get("suitor_short", "???"),
        "clause": _fmt_money(contract.get("release_clause", 0)),
        "wage": _fmt_money(contract.get("weekly_wage", 0)),

        "opponent": facts.get("opponent_name", "rakip"),
        "opponent_short": facts.get("opponent_short", "???"),
        "score": facts.get("score", "-"),
        "scoreline": facts.get("scoreline", "-"),
        "competition": facts.get("competition_name", (ctx.standings or {}).get("competition", "lig")),

        "goals": str(ctx.goals),
        "assists": str(ctx.season_stats["assists"]),
        "appearances": str(ctx.appearances),
        "money": _fmt_money(ctx.money),

        "item": facts.get("item_title", facts.get("item_id", "bir kalem")),
    }


# --- selection -------------------------------------------------------------

def _on_cooldown(story: dict, ctx: NewsContext) -> bool:
    last_at = ctx.published_recently.get(story["story_id"])
    if last_at is None:
        return False
    if story["cooldown_days"] <= 0:
        return False
    last_day = _dt.date.fromisoformat(last_at[:10])
    return (_dt.date.fromisoformat(ctx.on_date) - last_day).days < story["cooldown_days"]


def eligible_stories(ctx: NewsContext) -> List[dict]:
    """Every archetype that would run today, in catalog order. Public
    because it is exactly what a content-authoring test wants to inspect
    ("does this state produce anything at all?") without publishing."""
    out = []
    for story in STORIES:
        if ctx.trigger not in story["triggers"]:
            continue
        if _on_cooldown(story, ctx):
            continue
        try:
            if not story["applies"](ctx):
                continue
        except Exception:  # noqa: BLE001 — see below
            # An archetype's predicate must never take down a day tick.
            # This is the one place the module swallows an exception: the
            # alternative is a career that cannot be advanced because a
            # content typo raised on a state nobody tested. The import-time
            # validation in content/__init__.py catches the structural
            # mistakes; this catches the semantic ones, quietly.
            continue
        out.append(story)
    return out


def _weighted_sample(rng: random.Random, stories: List[dict], k: int) -> List[dict]:
    """k distinct stories, weighted, without replacement. rng.choices()
    samples WITH replacement and would happily print the same archetype
    twice in one day tick, which is the single most obvious way a
    generator gives itself away."""
    pool = list(stories)
    picked = []
    while pool and len(picked) < k:
        weights = [s["weight"] for s in pool]
        chosen = rng.choices(pool, weights=weights, k=1)[0]
        picked.append(chosen)
        pool.remove(chosen)
    return picked


def _published_at(on_date: str, trigger: str, index: int) -> str:
    """The nth slot of a trigger's publishing window, as an ISO timestamp.

    Injective in `index` for every trigger — that is the whole point. N1
    orders by published_at and paginates with a strictly-exclusive
    `published_at < ?` cursor, so two rows sharing a timestamp are not just
    unordered: a page boundary landing between them drops one from the feed
    permanently. The ORDER BY carries a news_id tiebreak for the ordering
    half of that; this function owns the other half.
    """
    hour, minute = _TRIGGER_HOUR.get(trigger, (9, 0))
    base = hour * 3600 + minute * 60
    fits = (_DAY_LAST_SECOND - base) // _SLOT_SECONDS
    if index <= fits:
        total = base + index * _SLOT_SECONDS
    else:
        # The 40-minute grid ran out of day. The tail packs backwards from
        # 23:59:59, one second per item — still injective in `index`, which
        # is the only property the cursor actually needs. Reaching it takes
        # dozens of stories from one trigger on one date; the ordering
        # nicety the grid buys is not worth a date rollover to preserve.
        total = _DAY_LAST_SECOND - (index - fits - 1)
    return f"{on_date}T{total // 3600:02d}:{total // 60 % 60:02d}:{total % 60:02d}+03:00"


def _free_slot_index(on_date: str, trigger: str, taken: set) -> int:
    """The first publishing slot of `trigger` on `on_date` that nothing has
    used yet.

    Without this, the uniqueness `_published_at` promises would hold only
    within ONE generate() call. Nothing stops a day from carrying two
    lifestyle actions or two dialogues — day_budget tracks a pool, not a
    count — and each of those is a separate generate() call that would
    otherwise stamp index 0 twice.

    `taken` is the set of timestamps already used today, passed in so the
    read happens once per call rather than once per story. Deterministic:
    it is a pure function of the date's existing rows, which are themselves
    part of "the same state" INV-7's determinism clause talks about.
    """
    index = 0
    while _published_at(on_date, trigger, index) in taken:
        index += 1
    return index


def _timestamps_used_today(conn, career_id: str, on_date: str) -> set:
    rows = conn.execute(
        "SELECT published_at FROM news WHERE career_id = ? AND published_at LIKE ?",
        (career_id, f"{on_date}T%"),
    ).fetchall()
    return {r["published_at"] for r in rows}


def _apply_effects(conn, ctx: NewsContext, story: dict, published_at: str) -> None:
    """A story's fame/relationship consequences, through the documented
    single write paths only (INV-24, INV-15). `reason` names the archetype
    so fame_event/relationship_event stay readable audit trails: a player
    asking "why did my media score drop" gets 'news:magazin-gece-hayati'
    rather than an anonymous number."""
    reason = f"news:{story['story_id']}"
    for key, value in story.get("effects", {}).items():
        if value is None:
            continue  # ⟦AÇIK-9⟧-style placeholder, same convention as catalog items
        if key.startswith("fame:"):
            fame_domain.apply(
                conn, ctx.career_id, config.USER_PLAYER_ID, float(value),
                reason, published_at, scope=key.split(":", 1)[1],
            )
        elif key.startswith("relationship:"):
            relationship_id = key.split(":", 1)[1]
            if relationship_id in ctx.relationships:
                relationships_domain.apply_delta(
                    conn, ctx.career_id, relationship_id, int(value), reason, published_at,
                    # A newspaper article is not contact. Bumping
                    # last_contact_at here would let the press paper over
                    # the staleness signal the player is supposed to manage.
                    touches_contact=False,
                )


def generate(
    conn: sqlite3.Connection,
    career_id: str,
    *,
    trigger: str,
    on_date: str,
    seed: int,
    **facts,
) -> List[str]:
    """Runs one trigger and returns the news_ids it published (possibly
    empty). Does not commit — the caller owns the transaction, like every
    other domain write path.

    Order of operations matters and is deliberate:
      1. the "is anyone even writing today" roll, BEFORE any query, so a
         quiet day costs one PRNG call instead of a dozen SELECTs;
      2. context assembly (one burst of reads);
      3. arc bookkeeping on day_tick, so the archetypes see today's heat;
      4. eligibility, weighted pick, fill, publish, effects.
    """
    if trigger not in TRIGGERS:
        raise ValueError(f"unknown news trigger {trigger!r}")

    rng = random.Random(f"{seed}:news:{on_date}:{trigger}:0")

    chance = TRIGGER_CHANCE.get(trigger)
    if chance is not None and rng.random() >= chance:
        return []

    ctx = build_context(conn, career_id, trigger=trigger, on_date=on_date, facts=facts)
    if ctx is None:
        return []

    if trigger == "day_tick":
        # The arc ticks every advanced day whether or not anything is
        # printed — heat is a property of the world, not of the newspaper.
        # It is read back into the context because the transfer archetypes
        # gate on today's stage, not yesterday's.
        arc = touch_arc(conn, ctx)
        ctx = _with_arc(ctx, arc)

    candidates = eligible_stories(ctx)
    if not candidates:
        return []

    limit = MAX_STORIES_PER_TRIGGER.get(trigger, 1)
    if trigger == "day_tick" and limit > 1:
        # Two stories in one morning is the exception, not the rule.
        limit = 2 if rng.random() < 0.25 else 1

    # One read for the whole call; each publish below adds its own stamp so
    # a second story in the same call cannot land on the first one's slot.
    taken = _timestamps_used_today(conn, career_id, on_date)

    published = []
    for story in _weighted_sample(rng, candidates, limit):
        story_rng = random.Random(f"{seed}:news:{on_date}:{trigger}:{story['story_id']}")
        outlet = pick_outlet(story_rng, story["outlets"], ctx.rel("media"))
        slots = build_slots(ctx, outlet)

        title = story_rng.choice(story["headlines"]).format_map(slots)
        paragraphs = list(story["body"](ctx, slots, story_rng))
        paragraphs.append(story_rng.choice(outlet["sign_off"]))

        published_at = _published_at(
            on_date, trigger, _free_slot_index(on_date, trigger, taken)
        )
        taken.add(published_at)
        news_id = publish(
            conn, career_id,
            category=story["category"],
            title=title,
            body="\n\n".join(p for p in paragraphs if p),
            source=outlet["name"],
            published_at=published_at,
            fixture_id=facts.get("fixture_id"),
            story_id=story["story_id"],
        )
        _apply_effects(conn, ctx, story, published_at)
        published.append(news_id)

    return published


def _with_arc(ctx: NewsContext, arc: Optional[dict]) -> NewsContext:
    """NewsContext is frozen, so 'refreshing' one field means rebuilding
    it. Cheap (no queries) and keeps the immutability guarantee that lets
    archetypes be trusted with the object."""
    return NewsContext(
        career_id=ctx.career_id, on_date=ctx.on_date, trigger=ctx.trigger,
        player=ctx.player, team=ctx.team, attributes=ctx.attributes,
        condition=ctx.condition, fame=ctx.fame, money=ctx.money,
        relationships=ctx.relationships, relationship_peaks=ctx.relationship_peaks,
        contract=ctx.contract, form=ctx.form,
        season_stats=ctx.season_stats, standings=ctx.standings,
        inventory=ctx.inventory, recent_activities=ctx.recent_activities,
        published_recently=ctx.published_recently, arc=arc, facts=ctx.facts,
    )


# Guards the outlet table against an archetype naming an outlet that was
# renamed out from under it — the same import-time discipline INV-28 uses.
assert set(OUTLETS_BY_ID), "no outlets configured"
