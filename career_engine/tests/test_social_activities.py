"""§14.3 D83-D86 - the social-skill activities: modes, partners, risk, news."""
import json

import pytest

from api import config
from catalog import KNOWN_PASSIVE_EFFECT_KEYS
from catalog.lifestyle import LIFESTYLE_ITEMS, validate_social_fields
from domain import social_activity
from tests.conftest import create_career, grant_money, set_attribute

BY_ID = {i["catalog_id"]: i for i in LIFESTYLE_ITEMS}
KISI = {k for k, family in config.ATTRIBUTE_KEYS.items() if family == "kişi"}


@pytest.fixture
def created_career(api_client):
    return create_career(api_client)


def _act(api_client, career_id, catalog_id, **body):
    return api_client.post(
        f"/careers/{career_id}/actions", json={"catalog_id": catalog_id, **body}
    )


def _change(resp, key):
    return next(c for c in resp.json()["attribute_changes"] if c["key"] == key)


# --- catalog -------------------------------------------------------------

def test_the_docs_fifty_activities_are_all_present():
    """47 new rows plus the three the catalog already had (#4, #11, #34)."""
    from catalog.lifestyle_social import SOCIAL_ACTIVITIES

    assert len(SOCIAL_ACTIVITIES) == 47
    assert {"ev-meditasyon", "sos-kafe", "sos-taraftar"} <= set(BY_ID)
    groups = {i["group"] for i in SOCIAL_ACTIVITIES}
    assert groups == {
        "EV VE KİŞİSEL GELİŞİM", "ŞEHİRDE", "KULÜP VE FUTBOL ÇEVRESİ",
        "MEDYA VE DİJİTAL", "GECE VE SOSYAL HAYAT",
    }


def test_every_social_activity_grows_a_social_skill_and_partnered_ones_name_who_with():
    from catalog.lifestyle_social import SOCIAL_ACTIVITIES

    for item in SOCIAL_ACTIVITIES:
        skills = {k.split(":", 1)[1] for k in item["effects"] if k.startswith("attribute:")}
        assert skills and skills <= KISI, item["catalog_id"]
        if item["mode"] == "S":
            assert "with" not in item
        else:
            assert set(item["with"]) <= set(config.RELATIONSHIP_KINDS)
    # Main skill earns twice what the side skill does.
    jokes = BY_ID["kulup-soyunma-saka"]["effects"]
    assert jokes["attribute:courage"] == 2 * jokes["attribute:charisma"]


def test_the_three_risky_activities_and_the_one_skill_gated_one():
    risky = {i["catalog_id"] for i in LIFESTYLE_ITEMS if i.get("risk")}
    assert risky == {"kulup-soyunma-saka", "medya-paylasim", "gece-poker"}
    assert BY_ID["sehir-acik-mikrofon"]["requires"] == {"courage": 6}


def test_validate_social_fields_rejects_nonsense():
    base = {"catalog_id": "x", "mode": "B", "with": ["team"], "with_delta": 2}
    validate_social_fields([base])
    for bad in (
        {**base, "with": ["captain"]},                      # not a relationship kind
        {**base, "mode": "S"},                              # solo but lists `with`
        {**base, "with_delta": 0},
        {**base, "risk": {"chance": 1.5, "fail_effects": {"money": -1}}},
        {**base, "risk": {"chance": 0.3, "fail_effects": {}}},
        {**base, "risk": {"chance": 0.3, "fail_effects": {"nonsense": 1}}},
        {**base, "news": {"fail": {"category": "a", "title": "b", "body": "c"}}},  # no risk
    ):
        with pytest.raises(ValueError):
            validate_social_fields([bad])


# --- partner (D84) -------------------------------------------------------

def test_a_solo_activity_refuses_a_partner(api_client, created_career):
    career_id = created_career["career_id"]
    resp = _act(api_client, career_id, "ev-kitap", relationship_id="team")
    assert resp.status_code == 422


def test_a_partnered_activity_needs_someone_from_its_own_list(api_client, created_career):
    career_id = created_career["career_id"]
    assert _act(api_client, career_id, "kulup-malzemeci").status_code == 422
    # The equipment manager is `team`; the coach is not on the list.
    assert _act(api_client, career_id, "kulup-malzemeci", relationship_id="coach").status_code == 422


def test_doing_it_with_someone_raises_that_relationship(api_client, created_career):
    career_id = created_career["career_id"]
    before = api_client.get(f"/careers/{career_id}/relationships/team").json()["score"]
    resp = _act(api_client, career_id, "kulup-malzemeci", relationship_id="team")
    assert resp.status_code == 200, resp.json()
    assert resp.json()["with"] == "team"
    assert resp.json()["applied_effects"]["relationship:team"] == 2
    assert api_client.get(f"/careers/{career_id}/relationships/team").json()["score"] == before + 2


def test_you_cannot_spend_an_evening_with_someone_you_have_not_met(api_client, created_career):
    career_id = created_career["career_id"]
    resp = _act(api_client, career_id, "sehir-sahil-yuruyusu", relationship_id="partner")
    assert resp.status_code == 409 and resp.json()["code"] == "relationship_absent"
    # ... and nothing was spent (the check comes before the budget).
    day = api_client.get(f"/careers/{career_id}/day").json()["career_state"]["day_budget"]
    assert day["time"] == config.DAY_BUDGET_DEFAULTS["time"]


def test_solo_is_worth_more_skill_but_earns_no_relationship(api_client, created_career):
    """The trade D84 exists for: an S/B activity alone grows the skill
    SOLO_SKILL_BONUS times as much and befriends nobody."""
    career_id = created_career["career_id"]
    with_ = _act(api_client, career_id, "sehir-muze", relationship_id="family")
    alone = _act(api_client, career_id, "sehir-muze")
    gain_with = _change(with_, "intelligence")["after"] - _change(with_, "intelligence")["before"]
    gain_alone = _change(alone, "intelligence")["after"] - _change(alone, "intelligence")["before"]
    assert gain_alone == pytest.approx(gain_with * config.SOLO_SKILL_BONUS)
    assert "relationship:family" in with_.json()["applied_effects"]
    assert not any(k.startswith("relationship:") for k in alone.json()["applied_effects"])


# --- skill gate (D86) ----------------------------------------------------

def test_open_mic_is_locked_until_courage_six(api_client, created_career):
    career_id = created_career["career_id"]
    refused = _act(api_client, career_id, "sehir-acik-mikrofon")      # courage starts at level 5
    assert refused.status_code == 409 and refused.json()["code"] == "requirement_not_met"
    set_attribute(career_id, "courage", 60.0)
    assert _act(api_client, career_id, "sehir-acik-mikrofon").status_code == 200


# --- risk (D85) ----------------------------------------------------------

def _make_certain_to_fail(monkeypatch, catalog_id):
    risk = BY_ID[catalog_id]["risk"]
    monkeypatch.setitem(risk, "chance", 0.999)
    monkeypatch.setitem(risk, "mitigated_by", None)


def test_a_failed_roll_adds_its_penalty_on_top_of_the_normal_effects(
    api_client, created_career, monkeypatch
):
    career_id = created_career["career_id"]
    _make_certain_to_fail(monkeypatch, "kulup-soyunma-saka")
    team_before = api_client.get(f"/careers/{career_id}/relationships/team").json()["score"]

    resp = _act(api_client, career_id, "kulup-soyunma-saka", relationship_id="team")
    assert resp.status_code == 200, resp.json()
    body = resp.json()
    assert body["risk"]["failed"] is True
    assert body["fail_effects"] == {"relationship:team": -6, "attribute:discipline": -0.2}
    # The evening still earned its skill and its +2 ...
    assert _change(resp, "courage")["after"] > _change(resp, "courage")["before"]
    # ... and then lost 6: +2 - 6 = -4 on the team.
    assert api_client.get(f"/careers/{career_id}/relationships/team").json()["score"] == team_before - 4
    assert _change(resp, "discipline")["after"] == pytest.approx(_change(resp, "discipline")["before"] - 0.2)


def test_the_log_keeps_the_penalty_apart_from_the_normal_effects(
    api_client, created_career, monkeypatch
):
    from db.connection import get_connection

    career_id = created_career["career_id"]
    _make_certain_to_fail(monkeypatch, "kulup-soyunma-saka")
    _act(api_client, career_id, "kulup-soyunma-saka", relationship_id="team")
    conn = get_connection(config.DB_PATH)
    try:
        logged = json.loads(conn.execute(
            "SELECT applied_effects FROM activity_log WHERE catalog_id = 'kulup-soyunma-saka'"
        ).fetchone()["applied_effects"])
    finally:
        conn.close()
    assert logged["relationship:team"] == 2
    assert logged["fail:relationship:team"] == -6


def test_a_money_penalty_never_exceeds_the_balance(api_client, created_career, monkeypatch):
    """The roll already said it went wrong; answering with insufficient_funds
    would turn a bad night into a rejected request."""
    career_id = created_career["career_id"]
    _make_certain_to_fail(monkeypatch, "gece-poker")
    monkeypatch.setitem(BY_ID["gece-poker"]["risk"]["fail_effects"], "money", -100000)
    resp = _act(api_client, career_id, "gece-poker", relationship_id="team")
    assert resp.status_code == 200, resp.json()
    assert resp.json()["career_state"]["money"] == 0            # lost what there was, no more


def test_a_safe_activity_reports_no_risk(api_client, created_career):
    career_id = created_career["career_id"]
    body = _act(api_client, career_id, "ev-kitap").json()
    assert body["risk"] is None and body["fail_effects"] is None and body["news_id"] is None


def test_the_same_seed_rolls_the_same_outcome(api_client):
    """Replaying a career from its seed must replay its bad nights too."""
    outcomes = []
    for _ in range(2):
        career = create_career(api_client, seed=7)
        grant_money(career["career_id"], 100)
        resp = _act(api_client, career["career_id"], "medya-paylasim")
        outcomes.append(resp.json()["risk"])
        api_client.delete(f"/careers/{career['career_id']}")
    assert outcomes[0] == outcomes[1]


def test_a_skill_lowers_the_chance_but_never_to_zero(db_conn, career_id, player_id):
    risk = {"chance": 0.30, "mitigated_by": {"attribute": "intelligence", "per_level": 0.03}}
    for level, expected in ((0, 0.30), (5, 0.15), (10, config.MIN_RISK_CHANCE)):
        db_conn.execute(
            "INSERT OR REPLACE INTO player_attribute (career_id, player_id, attribute_key, value) "
            "VALUES (?, ?, 'intelligence', ?)", (career_id, player_id, level * 10.0),
        )
        assert social_activity.risk_chance(db_conn, career_id, risk) == pytest.approx(expected)
    # Nothing left to lose means nothing to roll for.
    assert social_activity.risk_chance(db_conn, career_id, {"chance": 0.02}) == config.MIN_RISK_CHANCE


# --- news (§14.7) --------------------------------------------------------

def _news_titles(career_id):
    from db.connection import get_connection

    conn = get_connection(config.DB_PATH)
    try:
        return [r["title"] for r in conn.execute(
            "SELECT title FROM news WHERE career_id = ?", (career_id,)).fetchall()]
    finally:
        conn.close()


def test_a_failed_post_makes_the_bad_headline(api_client, created_career, monkeypatch):
    career_id = created_career["career_id"]
    _make_certain_to_fail(monkeypatch, "medya-paylasim")
    resp = _act(api_client, career_id, "medya-paylasim")
    assert resp.json()["news_id"] is not None
    assert "Paylaşım tepki çekti" in _news_titles(career_id)


def test_a_good_live_stream_makes_the_good_headline(api_client, created_career):
    career_id = created_career["career_id"]
    resp = _act(api_client, career_id, "medya-canli-yayin")
    assert resp.json()["news_id"] is not None
    assert "Canlı yayında taraftarlarla buluştu" in _news_titles(career_id)
