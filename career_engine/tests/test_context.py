"""§14.7 - what an item means beyond its grade: the winter coat, the sports car in a
losing run, boosts on activities, and the headlines items make."""
import sqlite3

import pytest

from api import config
from catalog import shop
from domain import context, form, inventory
from tests.conftest import advance_to_match_day, create_career, grant_money
from tests.test_matches_router import _valid_result_body


@pytest.fixture
def created_career(api_client):
    return create_career(api_client)


def _db():
    conn = sqlite3.connect(config.DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def _wear(cid, *item_ids):
    conn = _db()
    for item_id in item_ids:
        inventory.add(conn, cid, shop.gear_by_id(item_id), "2026-08-01", 0)
    conn.commit()
    conn.close()


def _set_date(cid, date):
    conn = _db()
    conn.execute("UPDATE career_state SET game_date = ? WHERE career_id = ?", (date, cid))
    conn.commit()
    conn.close()


def _charisma_bonus(api_client, cid):
    attrs = api_client.get(f"/careers/{cid}/player").json()["attributes"]
    return next(a for a in attrs if a["key"] == "charisma")["passive_bonus"]


def _user_team(conn, cid):
    return conn.execute("SELECT team_id FROM player WHERE career_id = ? AND is_user = 1", (cid,)).fetchone()[0]


def _play(conn, cid, n, *, user_goals, opp_goals, day):
    """Adds a finished fixture the user's team played (home side)."""
    team = _user_team(conn, cid)
    other = conn.execute(
        "SELECT team_id FROM team WHERE career_id = ? AND team_id != ? LIMIT 1", (cid, team)
    ).fetchone()[0]
    cols = [r[1] for r in conn.execute("PRAGMA table_info(fixture)")]
    template = dict(conn.execute("SELECT * FROM fixture WHERE career_id = ? LIMIT 1", (cid,)).fetchone())
    template.update(
        fixture_id=f"fx_form_{n}", kickoff_at=f"2026-08-{day:02d}T20:00:00+03:00", home_team_id=team,
        away_team_id=other, status="played", home_score=user_goals, away_score=opp_goals,
        user_squad_status=None,
    )
    conn.execute(
        f"INSERT INTO fixture ({','.join(cols)}) VALUES ({','.join('?' * len(cols))})",
        [template[c] for c in cols],
    )


# --- catalog ---------------------------------------------------------------

def test_the_context_notes_are_on_the_rows_the_doc_names():
    assert set(shop.ITEM_CONTEXT) == {
        "cloth-cashmere-coat", "cloth-leather-jacket", "cloth-luxury-outfit", "tech-stream-kit",
        "tech-photographer", "tech-youtube-team", "veh-sports-car", "veh-custom-supercar",
    }
    assert shop.gear_by_id("cloth-cashmere-coat")["context"] == {"months": [11, 12, 1, 2, 3]}


def test_validation_rejects_a_typo_in_a_context_note():
    base = {"catalog_id": "x", "category": "clothing"}
    shop.validate_context([{**base, "context": {"months": [1, 12]}}])
    for bad in ({"months": [13]}, {"boosts": {"no-such-activity": 1.5}}, {"boosts": {"medya-paylasim": 1.0}},
                {"bad_form": {"title": "only"}}, {"nonsense": 1}):
        with pytest.raises(ValueError):
            shop.validate_context([{**base, "context": bad}])


# --- the winter coat -------------------------------------------------------

def test_the_coat_counts_in_winter_and_not_in_summer(api_client, created_career):
    cid = created_career["career_id"]
    _wear(cid, "cloth-cashmere-coat")
    _set_date(cid, "2026-12-10")
    assert _charisma_bonus(api_client, cid) == 1.5
    _set_date(cid, "2027-01-20")
    assert _charisma_bonus(api_client, cid) == 1.5
    _set_date(cid, "2027-05-10")
    assert _charisma_bonus(api_client, cid) == 0.0
    _set_date(cid, "2026-10-31")
    assert _charisma_bonus(api_client, cid) == 0.0


# --- the sports car --------------------------------------------------------

def test_a_losing_run_streak_needs_three_straight_defeats(api_client, created_career):
    cid = created_career["career_id"]
    conn = _db()
    assert form.losing_streak(conn, cid) is False
    _play(conn, cid, 1, user_goals=0, opp_goals=1, day=1)
    _play(conn, cid, 2, user_goals=0, opp_goals=2, day=2)
    assert form.losing_streak(conn, cid) is False
    _play(conn, cid, 3, user_goals=1, opp_goals=1, day=3)           # a draw ends it
    _play(conn, cid, 4, user_goals=0, opp_goals=1, day=4)
    assert form.losing_streak(conn, cid) is False
    _play(conn, cid, 5, user_goals=0, opp_goals=1, day=5)
    _play(conn, cid, 6, user_goals=2, opp_goals=3, day=6)
    assert form.losing_streak(conn, cid) is True
    conn.close()


def test_a_flashy_car_flips_its_charisma_in_a_bad_run_and_comes_back(api_client, created_career):
    cid = created_career["career_id"]
    _wear(cid, "veh-sports-car")
    assert _charisma_bonus(api_client, cid) == 2.0
    conn = _db()
    for n in range(1, 4):
        _play(conn, cid, n, user_goals=0, opp_goals=1, day=n)
    conn.commit()
    assert _charisma_bonus(api_client, cid) == -2.0                  # derived, nothing was written
    _play(conn, cid, 9, user_goals=3, opp_goals=0, day=9)            # one win and it is over
    conn.commit()
    conn.close()
    assert _charisma_bonus(api_client, cid) == 2.0


def test_ordinary_gear_is_untouched_by_a_bad_run(api_client, created_career):
    cid = created_career["career_id"]
    _wear(cid, "veh-compact-car")
    conn = _db()
    for n in range(1, 4):
        _play(conn, cid, n, user_goals=0, opp_goals=1, day=n)
    conn.commit()
    conn.close()
    assert _charisma_bonus(api_client, cid) == 1.0


def test_a_defeat_in_a_bad_run_writes_the_car_headline(api_client, mock_engine):
    cid = create_career(api_client)["career_id"]
    advance_to_match_day(api_client, cid)
    _wear(cid, "veh-sports-car")
    conn = _db()
    _play(conn, cid, 1, user_goals=0, opp_goals=1, day=1)
    _play(conn, cid, 2, user_goals=0, opp_goals=1, day=2)
    conn.commit()
    conn.close()

    nxt = api_client.get(f"/careers/{cid}/matches/next").json()
    side, fixture_id = nxt["user_side"], nxt["fixture_id"]
    body = _valid_result_body(
        fixture_id, home_goals=0 if side == "home" else 2, away_goals=2 if side == "home" else 0,
    )
    body["interventions"] = []
    resp = api_client.post(f"/careers/{cid}/matches/{fixture_id}/result", json=body)
    assert resp.status_code == 200, resp.text
    ids = resp.json()["news_created"]
    assert len(ids) == 2                         # the result, and the car

    titles = {api_client.get(f"/careers/{cid}/news/{i}").json()["title"] for i in ids}
    assert "\"Maçları bırakmış, araba alıyor\"" in titles


def test_the_same_defeat_without_the_car_writes_only_the_result(api_client, mock_engine):
    cid = create_career(api_client)["career_id"]
    advance_to_match_day(api_client, cid)
    conn = _db()
    _play(conn, cid, 1, user_goals=0, opp_goals=1, day=1)
    _play(conn, cid, 2, user_goals=0, opp_goals=1, day=2)
    conn.commit()
    conn.close()
    nxt = api_client.get(f"/careers/{cid}/matches/next").json()
    side, fixture_id = nxt["user_side"], nxt["fixture_id"]
    body = _valid_result_body(
        fixture_id, home_goals=0 if side == "home" else 2, away_goals=2 if side == "home" else 0,
    )
    body["interventions"] = []
    assert len(api_client.post(f"/careers/{cid}/matches/{fixture_id}/result", json=body).json()["news_created"]) == 1


# --- boosts ----------------------------------------------------------------

def _live(api_client, cid):
    resp = api_client.post(f"/careers/{cid}/actions", json={"catalog_id": "medya-canli-yayin"})
    assert resp.status_code == 200, resp.text
    return resp.json()["applied_effects"]


def test_a_worn_stream_kit_makes_a_broadcast_teach_more_and_only_the_gains(api_client, created_career):
    cid = created_career["career_id"]
    grant_money(cid, 5000)
    plain = _live(api_client, cid)
    api_client.post(f"/careers/{cid}/advance", json={"to": "next_day"})
    _wear(cid, "tech-stream-kit")
    boosted = _live(api_client, cid)

    for key, value in plain.items():
        if key.startswith("attribute:") and value > 0:
            assert boosted[key] == round(value * 1.5, 3), key
        else:
            assert boosted[key] == value, key


def test_a_group_boost_reaches_every_activity_in_the_group(api_client, created_career):
    item = {"catalog_id": "gece-poker", "group": "GECE VE SOSYAL HAYAT"}
    conn = _db()
    cid = created_career["career_id"]
    inventory.add(conn, cid, shop.gear_by_id("cloth-leather-jacket"), "2026-08-01", 0)
    boosted = context.boost_effects(conn, cid, item, {"attribute:courage": 0.4, "condition": -4, "money": -10})
    assert boosted == {"attribute:courage": 0.52, "condition": -4, "money": -10}
    other = context.boost_effects(conn, cid, {"catalog_id": "ev-uyku", "group": "EV AKTİVİTELERİ"},
                                  {"attribute:courage": 0.4})
    assert other == {"attribute:courage": 0.4}
    conn.close()


def test_an_unworn_item_boosts_nothing(api_client, created_career):
    cid = created_career["career_id"]
    conn = _db()
    inventory.add(conn, cid, shop.gear_by_id("tech-photographer"), "2026-08-01", 0)
    inventory.unequip(conn, cid, "tech-photographer")
    effects = {"attribute:charisma": 0.3}
    assert context.boost_effects(conn, cid, {"catalog_id": "medya-paylasim", "group": "x"}, effects) == effects
    conn.close()


# --- headlines -------------------------------------------------------------

def test_buying_the_painted_supercar_makes_the_papers(api_client, created_career):
    cid = created_career["career_id"]
    grant_money(cid, 50_000_000)
    resp = api_client.post(f"/careers/{cid}/purchases", json={"catalog_id": "veh-custom-supercar"})
    assert resp.status_code == 200, resp.text
    news = api_client.get(f"/careers/{cid}/news/{resp.json()['news_id']}").json()
    assert news["title"] == "Özel boyalı süper araba manşette"


def test_buying_an_ordinary_car_makes_no_news(api_client, created_career):
    cid = created_career["career_id"]
    grant_money(cid, 50_000)
    assert api_client.post(
        f"/careers/{cid}/purchases", json={"catalog_id": "veh-compact-car"}
    ).json()["news_id"] is None


def test_a_worn_channel_publishes_every_monday(api_client, created_career, mock_engine):
    cid = created_career["career_id"]
    _wear(cid, "tech-youtube-team")
    published = []
    for _ in range(6):                      # the 29th is a match day: stop before it
        body = api_client.post(f"/careers/{cid}/advance", json={"to": "next_day"}).json()
        for news_id in body["news_created"]:
            row = api_client.get(f"/careers/{cid}/news/{news_id}").json()
            if row["category"] == "Röportaj":
                published.append((body["career_state"]["current_date"], row["title"]))
    # 2026-08-22 is a Saturday: the only Monday before the first match is the 24th.
    assert [d for d, _ in published] == ["2026-08-24"]


def test_the_weekly_pick_is_the_same_for_the_same_career_and_week(api_client, created_career):
    cid = created_career["career_id"]
    conn = _db()
    inventory.add(conn, cid, shop.gear_by_id("tech-youtube-team"), "2026-08-01", 0)
    a = context.weekly_headlines(conn, cid, "2026-08-24", 42)
    assert a == context.weekly_headlines(conn, cid, "2026-08-24", 42)
    assert len({tuple(h["title"] for h in context.weekly_headlines(conn, cid, f"2026-{m:02d}-01", 42))
                for m in range(9, 13)}) > 1
    conn.close()
