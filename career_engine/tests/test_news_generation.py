"""§5 of the news-layer spec — the archetype catalog and the generator.

Three kinds of test live here, and the split is deliberate:

  * **Catalog shape** — unique ids, known categories/outlets/effect keys,
    fillable headlines. content/__init__.py already asserts most of this at
    import, so these tests are the readable failure message for a rule the
    import would otherwise fail on with a bare ValueError.
  * **Reachability and rendering** — for every archetype, a context that
    satisfies its `applies` is constructed and its `body` is actually run.
    A story that crashes when selected is a latent 500 on a day tick, and a
    story no state can reach is dead content nobody would ever notice.
  * **Generator invariants** — determinism, cooldown, publishing-slot
    uniqueness, and the source scan behind INV-38.
"""
import datetime as _dt
import random
import re
from dataclasses import replace
from pathlib import Path

import pytest

from api import config
from catalog import _is_known_effect_key
from content import CATEGORIES, MIN_HEADLINE_VARIANTS, SLOT_KEYS, TRIGGERS
from content.news_outlets import OUTLET_IDS, OUTLETS_BY_ID, pick_outlet
from content.news_stories import ARC_STAGE_STORIES, STORIES
from worlddata.relationships import STARTING_SCORES
from domain import news
from tests.conftest import create_career, new_career

_REPO = Path(__file__).resolve().parent.parent


# --- a DB-free NewsContext factory ----------------------------------------
#
# NewsContext is frozen plain data by design (domain/news.py), which is what
# makes this possible: the whole catalog can be exercised without a career,
# a season or a match_engine. Defaults are chosen to satisfy as FEW
# archetypes as possible — a middling player, mid-table, nothing owed and
# nothing rumoured — so a scenario below has to opt IN to every condition it
# means to test, and a story that starts applying by accident shows up as a
# scenario matching two stories instead of one.

_DEFAULT_PEOPLE = {
    "coach": "Mert Aydın", "team": "Kerem Su", "media": "Ayça Kılıç",
    "fans": "Tribün", "partner": "Deniz", "family": "Ailesi",
}


def make_ctx(**over) -> news.NewsContext:
    base = dict(
        career_id="car_test0000",
        on_date="2026-09-14",
        trigger="day_tick",
        player={
            "first_name": "Efe", "last_name": "Kaan", "full_name": "Efe Kaan",
            "age": 26, "position": "Orta saha", "role": "merkez_orta_saha",
            "target_team_id": "t_gal", "people": dict(_DEFAULT_PEOPLE),
        },
        team={"team_id": "t_ykz", "name": "Yıldız Kartal", "short_name": "YKZ"},
        attributes={k: {"value": 50.0, "level": 5} for k in config.ATTRIBUTE_KEYS},
        condition=72,
        fame=3.0,
        money=100_000,
        relationships={
            "coach": 50, "team": 50, "media": 50, "fans": 50, "partner": 40, "family": 40,
        },
        # Peak == current by default: nothing has fallen from anywhere, so
        # no "it used to be better" archetype fires unless a scenario says so.
        relationship_peaks={
            "coach": 50, "team": 50, "media": 50, "fans": 50, "partner": 40, "family": 40,
        },
        contract={
            "weekly_wage": 48_200, "expires_at": "2027-05-30", "days_left": 300,
            "release_clause": 0, "goal_bonus": 0, "appearance_bonus": 0,
        },
        form={
            "w": 2, "d": 1, "l": 2, "played": 5, "last_result": "W",
            "streak_kind": "W", "streak_len": 1, "results": ["W", "L", "D", "W", "L"],
        },
        season_stats={"appearances": 4, "goals": 1, "assists": 1, "minutes": 380},
        standings={
            "rank": 9, "teams": 18, "points": 12, "played": 8,
            "competition": "1. Lig", "competition_id": "c_lig2",
        },
        inventory=[],
        recent_activities=[],
        published_recently={},
        arc=None,
        facts={},
    )
    # Nested dicts merge one level deep so a scenario can say
    # {"relationships": {"coach": 85}} without restating the other five.
    for key, value in over.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            base[key] = {**base[key], **value}
        else:
            base[key] = value
    return news.NewsContext(**base)


def _arc(stage, heat):
    return {
        "arc_id": "transfer:t_gal", "stage": stage, "heat": heat,
        "opened_on": "2026-08-01", "updated_on": "2026-09-14",
        "suitor_team_id": "t_gal", "suitor_name": "Galatasaray", "suitor_short": "GS",
    }


def _match(**facts):
    """Match facts with the shape daytime.match_facts() produces, so the
    rendering test and the real call site agree about the key names."""
    base = {
        "fixture_id": "f_test", "score": "1-1",
        "scoreline": "Yıldız Kartal 1-1 Doğu AS", "opponent_name": "Doğu AS",
        "opponent_short": "DGU", "competition_name": "1. Lig", "is_cup": False,
        "result": "draw", "goal_diff": 0, "goals": 0, "assists": 0,
    }
    return {**base, **facts}


# Every state the catalog can be reached from. A story that matches none of
# these is unreachable content; the test below fails and names it.
SCENARIOS = [
    {},
    {"arc": _arc(1, 25.0)},
    {"arc": _arc(2, 45.0)},
    {"arc": _arc(3, 65.0)},
    {"arc": _arc(4, 85.0)},
    {"arc": _arc(1, 30.0), "published_recently": {"transfer-ilgi-dogdu": "2026-09-01T07:00:00+03:00"}},
    # The refusal hangs off a bid the reader has actually seen in print.
    {"arc": _arc(3, 65.0),
     "published_recently": {"transfer-teklif-yapildi": "2026-09-01T07:00:00+03:00"}},
    {"contract": {"days_left": 30}},
    {"contract": {"release_clause": 12_000_000}, "fame": 10.0},
    {"facts": {"delta": 3}},
    {"facts": {"delta": -3}},
    {"facts": {"delta": 0}},
    {"relationships": {"coach": 70}, "facts": {"delta": 1}},
    {"relationships": {"fans": 30}},
    {"facts": {"catalog_id": "sos-konser", "item_title": "Konser"}},
    {"condition": 40, "facts": {"catalog_id": "sos-arkadas", "item_title": "Arkadaş buluşması"}},
    {"relationships": {"partner": 70}},
    # No history: the "nobody in the picture" story, not a break-up.
    {"relationships": {"partner": 10}, "relationship_peaks": {"partner": 10}},
    {"relationships": {"partner": 0}, "relationship_peaks": {"partner": 0}},
    # Real history that fell: the break-up story is earned here and only here.
    {"relationships": {"partner": 4}, "relationship_peaks": {"partner": 72}},
    {"relationships": {"family": 5}, "relationship_peaks": {"family": 55}},
    {"relationships": {"family": 5}, "relationship_peaks": {"family": 5}},
    {"facts": {"price": 1_850_000, "catalog_id": "estate-studio", "item_title": "Stüdyo Daire"}},
    {"facts": {"price": 12_500, "catalog_id": "home-espresso", "item_title": "Espresso Makinesi"}},
    {"fame": 12.0, "relationships": {"media": 15}},
    {"facts": {"catalog_id": "sos-taraftar", "item_title": "Taraftar etkinliği"}},
    {"facts": {"catalog_id": "sos-kafe", "item_title": "Kafe"}},
    {"relationships": {"team": 20}},
    {"relationships": {"coach": 20}},
    {"relationships": {"coach": 85}},
    {"relationships": {"fans": 15}},
    {"relationships": {"team": 85, "fans": 60}},
    {"money": 500, "inventory": ["home-tv"]},
    {"contract": {"goal_bonus": 5_000}, "season_stats": {"goals": 5, "appearances": 9}},
    {"money": 300_000},
    {"facts": _match(goals=3, result="win", goal_diff=2)},
    {"facts": _match(goals=1, result="win", goal_diff=1)},
    {"facts": _match(assists=2)},
    {"facts": _match(result="win", goal_diff=4)},
    {"facts": _match()},
    {"facts": _match(result="draw", goals=1)},
    {"facts": _match(result="loss", goal_diff=-4, score="0-4")},
    {"facts": _match(result="loss", goal_diff=-1, score="0-1")},
    {"facts": _match(is_cup=True, competition_name="Ulusal Kupa")},
    {"season_stats": {"goals": 5}},
    {"season_stats": {"appearances": 10}},
    {"facts": {"level_before": 6, "level_after": 7, "attribute_key": "shooting", "attribute_label": "Şut"}},
    {"form": {"streak_kind": "W", "streak_len": 3, "w": 4, "l": 0, "d": 1}},
    {"form": {"streak_kind": "L", "streak_len": 3, "w": 0, "l": 4, "d": 1}},
    {"standings": {"rank": 2, "played": 8}},
    {"player": {"age": 21}, "season_stats": {"appearances": 6}},
    {"facts": {"relationship_id": "partner", "delta": 2, "dialogue_id": "partner_01"}},
    {"facts": {"relationship_id": "family", "delta": 2, "dialogue_id": "family_01"}},
    {"facts": {"relationship_id": "team", "delta": 2, "dialogue_id": "team_01"}},
]


def _contexts_for(story):
    """Every scenario that satisfies this story's `applies`, with the story's
    own trigger stamped on."""
    trigger = story["triggers"][0]
    out = []
    for scenario in SCENARIOS:
        ctx = make_ctx(trigger=trigger, **scenario)
        if story["applies"](ctx):
            out.append(ctx)
    return out


# --- catalog shape (§5.1-§5.5) --------------------------------------------

def test_story_ids_are_unique():
    ids = [s["story_id"] for s in STORIES]
    assert len(ids) == len(set(ids))


def test_every_story_has_enough_headline_variants():
    for story in STORIES:
        assert len(story["headlines"]) >= MIN_HEADLINE_VARIANTS, story["story_id"]
        assert len(set(story["headlines"])) == len(story["headlines"]), story["story_id"]


def test_every_category_is_known():
    assert {s["category"] for s in STORIES} <= CATEGORIES


def test_every_trigger_is_known_and_covered():
    used = {t for s in STORIES for t in s["triggers"]}
    assert used <= TRIGGERS
    # A trigger with no archetype is a silently dead call site.
    assert used == TRIGGERS


def test_every_outlet_is_known():
    for story in STORIES:
        assert set(story["outlets"]) <= OUTLET_IDS, story["story_id"]


def test_every_effect_key_passes_catalog_validation():
    """Same predicate catalog items are held to (INV-28), so a news effect
    and a training effect can never mean different things."""
    for story in STORIES:
        for key in story.get("effects", {}) or {}:
            assert _is_known_effect_key(key), f"{story['story_id']}: {key}"


def test_slot_map_covers_exactly_the_declared_vocabulary():
    """content.SLOT_KEYS is what headlines are validated against at import;
    build_slots() is what actually fills them. If they drift, the import
    check becomes decorative."""
    slots = news.build_slots(make_ctx(), OUTLETS_BY_ID["spor-manset"])
    assert set(slots) == SLOT_KEYS


def test_every_headline_fills_against_a_sample_context():
    slots = news.build_slots(make_ctx(facts=_match()), OUTLETS_BY_ID["spor-manset"])
    for story in STORIES:
        for headline in story["headlines"]:
            # format_map on a plain dict: a slot nobody fills raises KeyError
            # here rather than printing an empty headline in production.
            assert headline.format_map(slots), story["story_id"]


def test_match_headlines_always_carry_the_result():
    """M2 hands FE exactly one news_id and that item IS the match report."""
    for story in STORIES:
        if {"match_played", "match_missed"} & set(story["triggers"]):
            for headline in story["headlines"]:
                assert "{score}" in headline or "{scoreline}" in headline, story["story_id"]


# --- reachability and rendering -------------------------------------------

def test_every_story_is_reachable_from_some_state():
    unreachable = [s["story_id"] for s in STORIES if not _contexts_for(s)]
    assert not unreachable, (
        "no scenario in SCENARIOS satisfies these archetypes; either the "
        f"content is dead or this test needs a new scenario: {unreachable}"
    )


def test_every_story_renders_without_raising():
    """Walk the catalog, build a context that satisfies each `applies`, and
    actually run its `body`. A story that crashes when selected is a 500 on
    whatever day tick happens to pick it — and `eligible_stories` swallows
    predicate errors, so nothing else would ever surface it."""
    for story in STORIES:
        for ctx in _contexts_for(story):
            rng = random.Random(f"render:{story['story_id']}")
            outlet = pick_outlet(rng, story["outlets"], ctx.rel("media"))
            slots = news.build_slots(ctx, outlet)
            for headline in story["headlines"]:
                assert headline.format_map(slots)
            paragraphs = list(story["body"](ctx, slots, rng))
            assert paragraphs, story["story_id"]
            assert all(isinstance(p, str) for p in paragraphs), story["story_id"]


@pytest.mark.parametrize("result", ["win", "draw", "loss"])
@pytest.mark.parametrize("goals", [0, 1, 2, 3])
@pytest.mark.parametrize("assists", [0, 1])
def test_every_match_outcome_has_a_report(result, goals, assists):
    """M2's response contract promises a news_id for every match. The
    goal-difference is derived from the result so the grid stays plausible
    (a 'win' with a negative difference is not a state that can occur)."""
    goal_diff = {"win": 3, "draw": 0, "loss": -3}[result]
    for is_cup in (False, True):
        ctx = make_ctx(
            trigger="match_played",
            facts=_match(
                result=result, goals=goals, assists=assists,
                goal_diff=goal_diff, is_cup=is_cup,
            ),
        )
        assert news.eligible_stories(ctx), (result, goals, assists, is_cup)


# --- publishing slots (the N1 pagination hazard) ---------------------------

def test_publishing_slots_never_collide_within_a_trigger():
    """N1 paginates with a strictly-exclusive `published_at < ?` cursor, so
    two rows sharing a timestamp are not merely unordered — a page boundary
    landing inside that group drops the rest of it from the feed forever.
    Every (trigger, index) pair a single generate() call can produce must
    therefore land on its own minute."""
    stamps = {}
    for trigger, limit in news.MAX_STORIES_PER_TRIGGER.items():
        for index in range(limit):
            at = news._published_at("2026-09-14", trigger, index)
            assert at not in stamps, f"{trigger}[{index}] collides with {stamps.get(at)}"
            stamps[at] = f"{trigger}[{index}]"


def test_publishing_slots_stay_unique_past_the_end_of_the_day():
    """Repeated same-trigger calls in one day (two lifestyle actions, two
    dialogues — nothing forbids either) walk the index up. The slot search
    must keep finding a free one even after the minute ceiling is reached."""
    seen = set()
    for index in range(80):
        at = news._published_at("2026-09-14", "lifestyle", index)
        assert at.startswith("2026-09-14T"), at   # never rolls into tomorrow
        assert at not in seen, index
        seen.add(at)


def test_free_slot_index_skips_taken_stamps():
    taken = {news._published_at("2026-09-14", "day_tick", 0)}
    assert news._free_slot_index("2026-09-14", "day_tick", taken) == 1


# --- INV-38: one write path ------------------------------------------------

_PRODUCTION_PACKAGES = ("api", "catalog", "content", "db", "domain", "worlddata")


def test_no_insert_into_news_outside_publish():
    """INV-38, checked the way test_wallet.py checks INV-19: by looking at
    what the code actually does rather than trusting a convention. Only
    domain/news.publish() may write the table — every other path has to go
    through it, which is what makes story_id/news_story_log reliable."""
    pattern = re.compile(r"INSERT\s+(?:OR\s+\w+\s+)?INTO\s+news\b", re.IGNORECASE)
    offenders = []
    for package in _PRODUCTION_PACKAGES:
        for path in (_REPO / package).rglob("*.py"):
            if path == _REPO / "domain" / "news.py":
                continue
            if pattern.search(path.read_text(encoding="utf-8")):
                offenders.append(str(path.relative_to(_REPO)))
    assert not offenders, f"INSERT INTO news outside domain/news.publish(): {offenders}"


def test_publish_is_the_only_writer_of_news_story_log():
    """The cooldown log is only trustworthy if it is written in the same
    breath as the row it describes."""
    pattern = re.compile(r"INSERT\s+(?:OR\s+\w+\s+)?INTO\s+news_story_log\b", re.IGNORECASE)
    for package in _PRODUCTION_PACKAGES:
        for path in (_REPO / package).rglob("*.py"):
            if path == _REPO / "domain" / "news.py":
                continue
            assert not pattern.search(path.read_text(encoding="utf-8")), path


# --- generator behaviour (needs a real career) -----------------------------

def _played_stories(conn, career_id):
    return [
        r["story_id"] for r in conn.execute(
            "SELECT story_id FROM news_story_log WHERE career_id = ?", (career_id,)
        ).fetchall()
    ]


def _seeded_career(conn, career_id):
    """Just enough of a career for build_context() to succeed: a user player,
    a club and the six relationships. Deliberately not a full C1 flow —
    these tests are about the generator, not about onboarding."""
    conn.execute(
        "INSERT INTO team (career_id, team_id, name, short_name, country, attack, midfield, "
        "defense, goalkeeper, mentality, color_primary, color_secondary) "
        "VALUES (?, 't_ykz', 'Yıldız Kartal', 'YKZ', 'TR', 60, 60, 60, 60, 'balanced', "
        "'#1E6FD9', '#FFFFFF')",
        (career_id,),
    )
    conn.execute(
        "INSERT INTO player (career_id, player_id, name, first_name, last_name, position, role, "
        "birth_date, team_id, target_team_id, is_user) "
        "VALUES (?, ?, 'Efe Kaan', 'Efe', 'Kaan', 'Orta saha', 'merkez_orta_saha', "
        "'2000-08-19', 't_ykz', 't_gal', 1)",
        (career_id, config.USER_PLAYER_ID),
    )
    # §4's real per-kind starting scores, not round numbers: peak_scores()
    # replays relationship_event forward from exactly these, the same
    # assumption replay_score() already documents, so a fixture seeded with
    # anything else would make the replay disagree with the stored score.
    for rid, score in sorted(STARTING_SCORES.items()):
        conn.execute(
            "INSERT INTO relationship (career_id, relationship_id, kind, category, score, "
            "person_name, contact_name) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (career_id, rid, rid, rid.title(), score, _DEFAULT_PEOPLE[rid], _DEFAULT_PEOPLE[rid]),
        )
    conn.commit()


def test_generate_is_deterministic(db_conn, career_id):
    """INV-7's determinism clause, extended to content: the same seed, the
    same date and the same state must print the same paper — same headline,
    same body, same masthead. Only news_id differs (it is a fresh surrogate
    key, §3.5's own pattern)."""
    _seeded_career(db_conn, career_id)

    def _run():
        db_conn.execute("DELETE FROM news WHERE career_id = ?", (career_id,))
        db_conn.execute("DELETE FROM news_story_log WHERE career_id = ?", (career_id,))
        db_conn.execute("DELETE FROM news_arc WHERE career_id = ?", (career_id,))
        news.generate(db_conn, career_id, trigger="interview", on_date="2026-09-14",
                      seed=42, delta=-3, relationship_id="media")
        return [
            (r["title"], r["body"], r["source"], r["category"], r["published_at"])
            for r in db_conn.execute(
                "SELECT * FROM news WHERE career_id = ? ORDER BY published_at, news_id",
                (career_id,),
            ).fetchall()
        ]

    first = _run()
    assert first, "an interview must always print something"
    assert _run() == first


def test_generate_respects_cooldown(db_conn, career_id):
    _seeded_career(db_conn, career_id)
    story = next(s for s in STORIES if s["story_id"] == "roportaj-tepki-ceken")
    assert story["cooldown_days"] > 0

    news.generate(db_conn, career_id, trigger="interview", on_date="2026-09-14",
                  seed=42, delta=-3, relationship_id="media")
    printed = _played_stories(db_conn, career_id)
    assert printed, "nothing was published, so the cooldown test proves nothing"
    first = printed[0]

    # Same day + every day inside the window: the same archetype must not run
    # a second time, whatever else the generator decides to print.
    cooldown = next(s for s in STORIES if s["story_id"] == first)["cooldown_days"]
    for offset in range(cooldown):
        day = (_dt.date(2026, 9, 14) + _dt.timedelta(days=offset)).isoformat()
        news.generate(db_conn, career_id, trigger="interview", on_date=day,
                      seed=42, delta=-3, relationship_id="media")
        assert _played_stories(db_conn, career_id).count(first) == 1, day

    # ...and it becomes eligible again the day the window closes.
    after = (_dt.date(2026, 9, 14) + _dt.timedelta(days=cooldown)).isoformat()
    ctx = news.build_context(
        db_conn, career_id, trigger="interview", on_date=after, facts={"delta": -3},
    )
    assert any(s["story_id"] == first for s in news.eligible_stories(ctx))


def test_generate_rejects_an_unknown_trigger(db_conn, career_id):
    _seeded_career(db_conn, career_id)
    with pytest.raises(ValueError):
        news.generate(db_conn, career_id, trigger="volcano", on_date="2026-09-14", seed=1)


def test_generate_does_not_commit(db_conn, career_id):
    """Same contract as every other domain write path: the caller owns the
    transaction, so a later failure in the same request rolls the news back
    with everything else."""
    _seeded_career(db_conn, career_id)
    news.generate(db_conn, career_id, trigger="interview", on_date="2026-09-14",
                  seed=42, delta=-3, relationship_id="media")
    db_conn.rollback()
    rows = db_conn.execute(
        "SELECT COUNT(*) AS n FROM news WHERE career_id = ?", (career_id,)
    ).fetchone()
    assert rows["n"] == 0


# --- the transfer arc ------------------------------------------------------

def test_transfer_heat_rises_with_good_form_and_falls_when_quiet():
    hot = make_ctx(
        season_stats={"appearances": 10, "goals": 8, "assists": 4, "minutes": 900},
        fame=40.0,
        standings={"rank": 1, "teams": 18, "points": 24, "played": 10,
                   "competition": "1. Lig", "competition_id": "c_lig2"},
        contract={"days_left": 60},
        form={"w": 4, "d": 1, "l": 0, "played": 5, "last_result": "W",
              "streak_kind": "W", "streak_len": 4, "results": ["W", "W", "W", "W", "D"]},
    )
    cold = make_ctx(
        season_stats={"appearances": 10, "goals": 0, "assists": 0, "minutes": 900},
        fame=0.0,
        standings={"rank": 18, "teams": 18, "points": 3, "played": 10,
                   "competition": "1. Lig", "competition_id": "c_lig2"},
        form={"w": 0, "d": 1, "l": 4, "played": 5, "last_result": "L",
              "streak_kind": "L", "streak_len": 4, "results": ["L", "L", "L", "L", "D"]},
    )
    assert news.transfer_heat_delta(hot) > 0
    assert news.transfer_heat_delta(cold) < 0
    assert news.transfer_heat_delta(hot) > news.transfer_heat_delta(cold)


def test_transfer_arc_stage_advances_and_never_reverses(db_conn, career_id):
    _seeded_career(db_conn, career_id)
    arc_id = news.transfer_arc_id(db_conn, career_id)
    assert arc_id.startswith("transfer:")
    assert news.read_arc(db_conn, career_id, arc_id) is None  # nothing printed yet

    hot = make_ctx(
        career_id=career_id,
        season_stats={"appearances": 10, "goals": 9, "assists": 5, "minutes": 900},
        fame=60.0,
        contract={"days_left": 45},
        form={"w": 5, "d": 0, "l": 0, "played": 5, "last_result": "W",
              "streak_kind": "W", "streak_len": 5, "results": ["W"] * 5},
    )

    heats, stages = [], []
    for _ in range(12):
        arc = news.touch_arc(db_conn, hot)
        heats.append(arc["heat"])
        stages.append(arc["stage"])

    assert heats == sorted(heats), "good form must not cool a rumour down"
    assert stages == sorted(stages), "the press cannot un-print a stage"
    assert stages[-1] >= 1, "a season of this form should open the story"

    # Heat can fall afterwards; the stage the press already printed stays.
    quiet = make_ctx(
        career_id=career_id,
        season_stats={"appearances": 10, "goals": 0, "assists": 0, "minutes": 900},
        fame=0.0,
        form={"w": 0, "d": 0, "l": 5, "played": 5, "last_result": "L",
              "streak_kind": "L", "streak_len": 5, "results": ["L"] * 5},
    )
    peak_stage = stages[-1]
    for _ in range(10):
        arc = news.touch_arc(db_conn, quiet)
    assert arc["heat"] < heats[-1]
    assert arc["stage"] == peak_stage


def test_stage_for_heat_is_monotone():
    previous = -1
    for heat in range(0, 101, 5):
        stage = news.stage_for_heat(float(heat))
        assert stage >= previous
        previous = stage


# --- wired call sites (the part that was missing) --------------------------

def test_interview_publishes_a_news_item(api_client):
    """worlddata/relationships.py's media card promises the player that
    every quote can become tomorrow's headline. R3 with relationship_id
    'media' is the only place that promise can be kept."""
    career_id, _ = new_career(api_client)

    # r1 is the ungated, negative-delta leaf (catalog/dialogue.py): r0 has a
    # charisma requirement a fresh career cannot meet (D42/INV-30).
    resp = api_client.post(
        f"/careers/{career_id}/relationships/media/interact",
        json={"dialogue_id": "media_01", "choice_path": ["r1"]},
    )
    assert resp.status_code == 200, resp.json()

    items = api_client.get(f"/careers/{career_id}/news").json()["items"]
    assert [i for i in items if i["category"] == "Röportaj"], items


def test_dialogue_with_a_non_media_contact_is_not_an_interview(api_client):
    """Everything that is not the press goes down the `dialogue` trigger,
    which prints gossip, not a press conference."""
    career_id, _ = new_career(api_client)
    resp = api_client.post(
        f"/careers/{career_id}/relationships/partner/interact",
        json={"dialogue_id": "partner_01", "choice_path": ["r0"]},
    )
    assert resp.status_code == 200, resp.json()
    items = api_client.get(f"/careers/{career_id}/news").json()["items"]
    assert not [i for i in items if i["category"] == "Röportaj"]


def test_creating_a_career_publishes_nothing(api_client):
    """C3's news_preview is empty on a fresh career, and must stay empty:
    onboarding advances no day, so no trigger has fired yet."""
    body = create_career(api_client)
    assert body["news_preview"] == []
    items = api_client.get(f"/careers/{body['career_id']}/news").json()["items"]
    assert items == []


def test_advancing_days_eventually_prints_something(api_client, mock_engine):
    career_id, _ = new_career(api_client)
    printed = []
    for _ in range(20):
        resp = api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})
        assert resp.status_code == 200, resp.json()
        printed += resp.json()["news_created"]
    assert printed, "twenty advanced days produced no news at all"

    # Every id the response claimed must be readable through N2.
    for news_id in printed:
        assert api_client.get(f"/careers/{career_id}/news/{news_id}").status_code == 200


def test_match_result_publishes_exactly_one_report(api_client, mock_engine):
    from tests.conftest import advance_to_match_day

    career_id, _ = new_career(api_client)
    advance_to_match_day(api_client, career_id)
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]

    zero = dict.fromkeys(
        ["goals", "shots", "shots_on_target", "corners", "dangerous_attacks",
         "total_attacks", "yellow_cards", "red_cards", "penalties", "penalty_goals",
         "fouls", "substitutions", "possession_ticks"], 0,
    )
    body = api_client.post(
        f"/careers/{career_id}/matches/{fixture_id}/result",
        json={
            "match_id": "m_news", "score": {"home": 2, "away": 2},
            "stats": {"home": {**zero, "goals": 2}, "away": {**zero, "goals": 2}},
            "final_possession_home": 50.0, "final_condition": 60, "interventions": [],
        },
    ).json()

    assert len(body["news_created"]) == 1
    item = api_client.get(f"/careers/{career_id}/news/{body['news_created'][0]}").json()
    assert item["category"] == "Maç"
    assert "2-2" in item["title"]
    # M2's report keeps the fixture link so FE can jump from feed to match.
    assert item["fixture_id"] == fixture_id


def test_news_feed_has_no_duplicate_timestamps_after_a_long_run(api_client, mock_engine):
    """The pagination hazard, end to end: if any two rows in one career ever
    shared a published_at, a `before` cursor landing between them would drop
    the rest of that group silently."""
    career_id, _ = new_career(api_client)
    for _ in range(25):
        assert api_client.post(
            f"/careers/{career_id}/advance", json={"to": "next_day"}
        ).status_code == 200
        # Two interviews on the same date is the case the per-call slot
        # search exists for: both would otherwise be stamped 18:30.
        for leaf in ("r2", "r1"):
            assert api_client.post(
                f"/careers/{career_id}/relationships/media/interact",
                json={"dialogue_id": "media_01", "choice_path": [leaf]},
            ).status_code == 200

    items = api_client.get(f"/careers/{career_id}/news", params={"limit": 100}).json()["items"]
    assert len(items) > 10, "not enough news to make this test meaningful"
    stamps = [i["published_at"] for i in items]
    assert len(stamps) == len(set(stamps)), "duplicate published_at in one career"

    # And the feed really is complete: paging through it with N1's own
    # cursor must return every item exactly once.
    paged, before = [], None
    while True:
        params = {"limit": 3}
        if before:
            params["before"] = before
        page = api_client.get(f"/careers/{career_id}/news", params=params).json()
        paged += [i["news_id"] for i in page["items"]]
        before = page["next_before"]
        if not before:
            break
    assert paged == [i["news_id"] for i in items]


def test_deleting_a_career_wipes_the_news_state_tables(api_client, mock_engine):
    """INV-9. news_story_log and news_arc are career-scoped like everything
    else; test_end_to_end.py's exhaustive sweep would catch this too, but
    this names the two tables the news layer added."""
    from db.connection import get_connection

    career_id, _ = new_career(api_client)
    for _ in range(15):
        api_client.post(f"/careers/{career_id}/advance", json={"to": "next_day"})

    assert api_client.delete(f"/careers/{career_id}").status_code == 204
    conn = get_connection(config.DB_PATH)
    try:
        for table in ("news", "news_story_log", "news_arc"):
            left = conn.execute(
                f"SELECT COUNT(*) AS n FROM {table} WHERE career_id = ?", (career_id,)
            ).fetchone()["n"]
            assert left == 0, table
    finally:
        conn.close()


# --- rendered-text quality (review round 1) --------------------------------

# Turkish reduplication is a real construction ("zaman zaman" = now and then,
# "tek tek" = one by one), so the doubled-word check needs an allowlist. It is
# deliberately short: every entry is a phrase somebody chose to write, and a
# new one has to be added here on purpose rather than slipping through.
LEGITIMATE_REDUPLICATIONS = frozenset({
    "zaman zaman", "tek tek", "yavaş yavaş", "teker teker", "adım adım",
    "hemen hemen", "sık sık", "birer birer", "azar azar",
})

_DOUBLED_WORD = re.compile(r"\b(\w+) \1\b", re.IGNORECASE)


def _doubled_words(text: str) -> list:
    return [
        m.group(0) for m in _DOUBLED_WORD.finditer(text)
        if m.group(0).lower() not in LEGITIMATE_REDUPLICATIONS
    ]


def test_no_rendered_text_repeats_a_word():
    """The bug this guards: a headline template ending in a verb whose slot
    already supplied one — "{team} rakibini geçti geçti" — printed five times
    in one season before anybody noticed. format_map cannot see it (the
    template is valid and every slot resolves), so only the rendered string
    can. Bodies are checked too: the same mistake is one paste away there.
    """
    offenders = []
    for story in STORIES:
        for ctx in _contexts_for(story):
            for outlet_id in story["outlets"]:
                slots = news.build_slots(ctx, OUTLETS_BY_ID[outlet_id])
                for headline in story["headlines"]:
                    for hit in _doubled_words(headline.format_map(slots)):
                        offenders.append((story["story_id"], "headline", hit))
                for seed in range(8):
                    rng = random.Random(f"doubled:{story['story_id']}:{seed}")
                    for paragraph in story["body"](ctx, slots, rng):
                        for hit in _doubled_words(paragraph):
                            offenders.append((story["story_id"], "body", hit))
    assert not offenders, sorted(set(offenders))


def _can_repeat(story, ctx) -> bool:
    """Would this archetype still apply after it has already run once?

    Some archetypes limit themselves through `applies` rather than through
    `cooldown_days` — the transfer arc's stage stories each print exactly
    once per career, so a fixed opening paragraph can never repeat and
    demanding variants from them would be busywork. This asks the archetype
    itself instead of maintaining a hand-written exemption list.
    """
    seen = {**ctx.published_recently, story["story_id"]: "2026-01-01T07:00:00+03:00"}
    return story["applies"](replace(ctx, published_recently=seen))


# The triggers whose archetypes a player sees over and over: one match report
# per fixture (~38 a season, cooldown 0) and the ambient daily feed.
HIGH_FREQUENCY_TRIGGERS = frozenset({"day_tick", "match_played", "match_missed"})


def test_repeatable_high_frequency_stories_vary_their_lede():
    """N1's `excerpt` is paragraph 1 and NOTHING else (api/routers/news.py
    `_excerpt` splits on the first blank line), and the feed list is what
    players actually read. Every archetype in this catalog originally put
    its `rng.choice` in paragraph 2 or 3, so the list showed the same
    sentence every time while the variation hid inside a detail view nobody
    had opened yet — ten distinct excerpts each appeared 3+ times in a
    91-item feed.

    So: an archetype that can run twice must be able to open twice.
    """
    thin = []
    for story in STORIES:
        if not HIGH_FREQUENCY_TRIGGERS & set(story["triggers"]):
            continue
        contexts = _contexts_for(story)
        if not contexts or not _can_repeat(story, contexts[0]):
            continue
        ctx = contexts[0]
        slots = news.build_slots(ctx, OUTLETS_BY_ID[story["outlets"][0]])
        ledes = {
            list(story["body"](ctx, slots, random.Random(f"lede:{i}")))[0]
            for i in range(24)
        }
        if len(ledes) < 2:
            thin.append(story["story_id"])
    assert not thin, (
        "these archetypes can repeat but always open with the same sentence, "
        f"so N1's excerpt would too: {thin}"
    )


# --- the rumour arc never walks backwards ----------------------------------

def _stage_of(story_id):
    return dict((sid, stage) for stage, sid in ARC_STAGE_STORIES).get(story_id)


def test_arc_stage_sequence_is_strictly_increasing(db_conn, career_id):
    """The arc advanced correctly but re-published stages it had already
    passed: "temsilci masaya oturdu" three times, and the scouting piece
    five — twice AFTER the offer had been reported. Reaching stage 4 leaves
    every `stage >= N` predicate true, so the weighted picker was free to
    walk the story backwards, and each stage's cooldown let it do so again
    a few weeks later.

    Drives a real career from cold to maximum heat and reads the published
    order back out of news_story_log.
    """
    _seeded_career(db_conn, career_id)
    # Goals are the loudest input to transfer_heat_delta(), so a scoring
    # season is the shortest path from heat 0 to the top stage.
    db_conn.execute(
        "INSERT INTO player_season_stat (career_id, player_id, season_id, competition_id, "
        "appearances, starts, goals, assists, minutes, passes_completed, passes_attempted) "
        "VALUES (?, ?, '25/26', 'c_lig2', 20, 20, 20, 10, 1800, 0, 0)",
        (career_id, config.USER_PLAYER_ID),
    )
    db_conn.commit()

    for day in range(120):
        on_date = (_dt.date(2026, 1, 1) + _dt.timedelta(days=day)).isoformat()
        news.generate(db_conn, career_id, trigger="day_tick", on_date=on_date, seed=1)

    rows = db_conn.execute(
        "SELECT story_id, published_at FROM news_story_log WHERE career_id = ? "
        "ORDER BY published_at, news_id",
        (career_id,),
    ).fetchall()
    stages = [_stage_of(r["story_id"]) for r in rows]
    stages = [s for s in stages if s is not None]

    assert stages, "the arc never printed anything; the test proves nothing"
    assert len(stages) == len(set(stages)), f"a stage printed twice: {stages}"
    assert stages == sorted(stages), f"the arc went backwards: {stages}"

    arc = news.read_arc(db_conn, career_id, news.transfer_arc_id(db_conn, career_id))
    assert arc["stage"] >= 3, "a 20-goal season should have escalated the rumour"


def test_arc_satellites_wait_for_the_beat_they_answer():
    """The club's refusal is a reply to a bid the reader has SEEN, not to a
    stage number only news_arc knows."""
    refusal = next(s for s in STORIES if s["story_id"] == "transfer-kulup-reddetti")
    hot_arc = {"arc": _arc(3, 65.0), "trigger": "day_tick"}

    assert not refusal["applies"](make_ctx(**hot_arc))
    assert refusal["applies"](make_ctx(
        published_recently={"transfer-teklif-yapildi": "2026-09-01T07:00:00+03:00"}, **hot_arc,
    ))
    # ...and it never runs twice, nor after the handshake made it moot.
    assert not refusal["applies"](make_ctx(
        published_recently={
            "transfer-teklif-yapildi": "2026-09-01T07:00:00+03:00",
            "transfer-kulup-reddetti": "2026-09-05T07:00:00+03:00",
        }, **hot_arc,
    ))
    assert not refusal["applies"](make_ctx(
        published_recently={
            "transfer-teklif-yapildi": "2026-09-01T07:00:00+03:00",
            "transfer-anlasma-yakin": "2026-09-09T07:00:00+03:00",
        }, **hot_arc,
    ))


# --- a break-up needs a relationship ---------------------------------------

def test_breakup_story_needs_a_relationship_that_existed():
    """`partner` starts at 0 for every career (§4: "you haven't called home
    yet"), so keying the break-up story on the current score alone reported
    the end of a relationship the player never had — on week two of a fresh
    career. peak() is the guard: it reads relationship_event's own history.
    """
    breakup = next(s for s in STORIES if s["story_id"] == "magazin-ayrilik-soylentisi")
    alone = next(s for s in STORIES if s["story_id"] == "magazin-partner-yalniz-aksam")

    fresh = make_ctx(relationships={"partner": 0}, relationship_peaks={"partner": 0})
    assert not breakup["applies"](fresh), "a fresh career has nothing to break up"
    assert alone["applies"](fresh), "...but 'nobody in the picture' still fits"

    lost = make_ctx(relationships={"partner": 3}, relationship_peaks={"partner": 68})
    assert breakup["applies"](lost)
    assert not alone["applies"](lost), "the two must not both fire on one state"


def test_family_reproach_needs_a_bond_to_have_weakened():
    sitem = next(s for s in STORIES if s["story_id"] == "magazin-aileden-sitem")
    assert not sitem["applies"](
        make_ctx(relationships={"family": 0}, relationship_peaks={"family": 0})
    )
    assert sitem["applies"](
        make_ctx(relationships={"family": 4}, relationship_peaks={"family": 52})
    )


def test_peak_scores_reads_the_relationship_audit_trail(db_conn, career_id):
    """domain.relationships.peak_scores() is what makes the two tests above
    possible; it must agree with the stored score on the way down."""
    from domain import relationships as relationships_domain

    _seeded_career(db_conn, career_id)
    for delta in (30, 25, -40, -5):
        relationships_domain.apply_delta(
            db_conn, career_id, "partner", delta, "test", "2026-01-01T00:00:00+03:00",
        )
    db_conn.commit()

    peaks = relationships_domain.peak_scores(db_conn, career_id)
    # partner starts at 0 (§4), so 0 -> 30 -> 55 -> 15 -> 10. Nothing clamps,
    # so the replay and the stored score have to agree exactly.
    assert peaks["partner"] == 55
    assert relationships_domain.get_score(db_conn, career_id, "partner") == 10
    # An untouched relationship peaks at its own starting score, never 0.
    assert peaks["coach"] == STARTING_SCORES["coach"]
