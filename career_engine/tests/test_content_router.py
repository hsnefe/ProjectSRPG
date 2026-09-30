import sqlite3

import pytest

from api import config
from tests.conftest import advance_to_match_day, create_career


@pytest.fixture
def created_career(api_client):
    return create_career(api_client)


def _seed_news(career_id, n=3, category="Analiz", prefix="n_test"):
    conn = sqlite3.connect(config.DB_PATH)
    for i in range(n):
        conn.execute(
            "INSERT INTO news (career_id, news_id, published_at, category, title, source, body, fixture_id) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, NULL)",
            (
                career_id, f"{prefix}_{i:03d}", f"2026-08-0{i + 1}T09:00:00+03:00", category,
                f"Başlık {i}", "Test Kaynağı",
                f"İlk paragraf {i}.\n\nİkinci paragraf {i}.",
            ),
        )
    conn.commit()
    conn.close()


# --- N1/N2 ----------------------------------------------------------------

def test_list_news_returns_excerpt_not_full_body(api_client, created_career):
    career_id = created_career["career_id"]
    _seed_news(career_id, n=1)

    resp = api_client.get(f"/careers/{career_id}/news")
    assert resp.status_code == 200
    items = resp.json()["items"]
    assert len(items) == 1
    assert items[0]["excerpt"] == "İlk paragraf 0."
    assert "body" not in items[0]


def test_list_news_orders_newest_first(api_client, created_career):
    career_id = created_career["career_id"]
    _seed_news(career_id, n=3)

    items = api_client.get(f"/careers/{career_id}/news").json()["items"]
    published = [i["published_at"] for i in items]
    assert published == sorted(published, reverse=True)


def test_list_news_before_cursor_excludes_newer(api_client, created_career):
    career_id = created_career["career_id"]
    _seed_news(career_id, n=3)  # n_test_000..002, days 08-01..08-03

    resp = api_client.get(
        f"/careers/{career_id}/news", params={"before": "2026-08-03T09:00:00+03:00"}
    )
    items = resp.json()["items"]
    assert all(i["published_at"] < "2026-08-03T09:00:00+03:00" for i in items)
    assert len(items) == 2


def test_list_news_filters_by_category(api_client, created_career):
    career_id = created_career["career_id"]
    _seed_news(career_id, n=2, category="Transfer", prefix="n_tr")
    _seed_news(career_id, n=1, category="Analiz", prefix="n_an")

    resp = api_client.get(f"/careers/{career_id}/news", params={"category": "Transfer"})
    items = resp.json()["items"]
    assert len(items) == 2
    assert all(i["category"] == "Transfer" for i in items)


def test_get_news_item_includes_full_body(api_client, created_career):
    career_id = created_career["career_id"]
    _seed_news(career_id, n=1)

    resp = api_client.get(f"/careers/{career_id}/news/n_test_000")
    assert resp.status_code == 200
    body = resp.json()
    assert body["body"] == "İlk paragraf 0.\n\nİkinci paragraf 0."
    assert body["excerpt"] == "İlk paragraf 0."


def test_get_news_item_unknown_id_errors(api_client, created_career):
    resp = api_client.get(f"/careers/{created_career['career_id']}/news/n_doesnotexist")
    assert resp.status_code == 422


def test_match_result_news_is_readable_via_n1_n2(api_client, created_career, mock_engine):
    career_id = created_career["career_id"]
    advance_to_match_day(api_client, career_id)  # §6.1 - M1 only serves today's fixture
    fixture_id = api_client.get(f"/careers/{career_id}/matches/next").json()["fixture_id"]
    result = api_client.post(
        f"/careers/{career_id}/matches/{fixture_id}/result",
        json={
            "match_id": "m_test",
            "score": {"home": 1, "away": 0},
            "stats": {"home": {**dict.fromkeys(
                ["goals", "shots", "shots_on_target", "corners", "dangerous_attacks",
                 "total_attacks", "yellow_cards", "red_cards", "penalties",
                 "penalty_goals", "fouls", "substitutions", "possession_ticks"], 0), "goals": 1},
                       "away": dict.fromkeys(
                           ["goals", "shots", "shots_on_target", "corners", "dangerous_attacks",
                            "total_attacks", "yellow_cards", "red_cards", "penalties",
                            "penalty_goals", "fouls", "substitutions", "possession_ticks"], 0)},
            "final_possession_home": 50.0,
            "final_condition": 60,
            "interventions": [],
        },
    ).json()

    news_id = result["news_created"][0]
    resp = api_client.get(f"/careers/{career_id}/news/{news_id}")
    assert resp.status_code == 200
    assert "1-0" in resp.json()["title"]


# --- N3 ---------------------------------------------------------------

def test_get_catalog_training(api_client):
    resp = api_client.get("/catalog/training")
    assert resp.status_code == 200
    items = resp.json()["items"]
    # §13.5/D77: 7 saha + 3 taktik. Was 15 while the five kişi rows existed.
    assert len(items) == 10
    assert {i["catalog_id"] for i in items} >= {"sut", "kondisyon-kosusu", "mudahale", "gegenpress"}
    assert {i["family"] for i in items} == {"saha", "taktik"}
    assert "medya-egitimi" not in {i["catalog_id"] for i in items}


def test_get_catalog_lifestyle(api_client):
    resp = api_client.get("/catalog/lifestyle")
    assert resp.status_code == 200
    assert len(resp.json()["items"]) == 62


def test_get_catalog_shop(api_client):
    resp = api_client.get("/catalog/shop")
    assert resp.status_code == 200
    assert len(resp.json()["items"]) == 43


def test_get_catalog_unknown_kind_errors(api_client):
    resp = api_client.get("/catalog/nonsense")
    assert resp.status_code == 422


def test_catalog_is_career_independent(api_client):
    # No career_id in the path at all — same catalog regardless.
    a = api_client.get("/catalog/training").json()
    b = api_client.get("/catalog/training").json()
    assert a == b
