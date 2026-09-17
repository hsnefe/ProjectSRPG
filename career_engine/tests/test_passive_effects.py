"""§13.3 - passive attribute bonuses from owned items."""
import pytest

from api import config
from catalog.shop import PASSIVE_ATTRIBUTE_BONUS
from tests.conftest import create_career, grant_money, set_attribute


@pytest.fixture
def created_career(api_client):
    return create_career(api_client)


def _db():
    from db.connection import get_connection
    return get_connection(config.DB_PATH)


def _attribute(api_client, career_id, key):
    attrs = api_client.get(f"/careers/{career_id}/player").json()["attributes"]
    return next(a for a in attrs if a["key"] == key)


def test_catalog_only_allows_kisi_attributes():
    """§13.3 - the space is deliberately narrow. A wristwatch raising shooting
    accuracy has no story behind it, and saha is still earned by training."""
    from catalog import KNOWN_PASSIVE_EFFECT_KEYS

    kisi = {k for k, family in config.ATTRIBUTE_KEYS.items() if family == "kişi"}
    assert KNOWN_PASSIVE_EFFECT_KEYS == {f"attribute:{k}" for k in kisi}

    for item_id, bonuses in PASSIVE_ATTRIBUTE_BONUS.items():
        assert set(bonuses) <= kisi, item_id


def test_validate_passive_effects_rejects_saha_and_negatives():
    from catalog import validate_passive_effects

    with pytest.raises(ValueError):
        validate_passive_effects({"attribute:shooting": 2.0}, "test")
    with pytest.raises(ValueError):
        validate_passive_effects({"attribute:politeness": -1.0}, "test")
    with pytest.raises(ValueError):
        validate_passive_effects({"attribute:politeness": True}, "test")
    validate_passive_effects({"attribute:politeness": 2.0}, "test")   # the happy path


def test_buying_an_item_raises_the_effective_value_not_the_base(api_client, created_career):
    """INV-60 - the stored column never moves. The bonus is derived per read."""
    career_id = created_career["career_id"]
    grant_money(career_id, 10000)
    set_attribute(career_id, "politeness", 58.0)

    before = _attribute(api_client, career_id, "politeness")
    assert (before["value"], before["passive_bonus"], before["effective_value"]) == (58.0, 0, 58.0)

    resp = api_client.post(f"/careers/{career_id}/purchases", json={"catalog_id": "personal-suit"})
    assert resp.status_code == 200

    after = _attribute(api_client, career_id, "politeness")
    assert after["value"] == 58.0              # base untouched (INV-60)
    assert after["passive_bonus"] == 3.0       # personal-suit
    assert after["effective_value"] == 61.0
    assert after["level"] == 6                 # D74: derived from the EFFECTIVE value

    conn = _db()
    try:
        stored = conn.execute(
            "SELECT value FROM player_attribute WHERE career_id = ? AND attribute_key = 'politeness'",
            (career_id,),
        ).fetchone()["value"]
    finally:
        conn.close()
    assert stored == 58.0


def test_bonus_disappears_with_the_item(api_client, created_career):
    """§13.3/D73's whole reason for deriving rather than storing: nothing has
    to be taken back, so INV-22 (no attribute ever falls on its own) is never
    even tested."""
    career_id = created_career["career_id"]
    grant_money(career_id, 10000)
    set_attribute(career_id, "politeness", 58.0)
    api_client.post(f"/careers/{career_id}/purchases", json={"catalog_id": "personal-suit"})
    assert _attribute(api_client, career_id, "politeness")["effective_value"] == 61.0

    # The way D29 repossession takes it away: the inventory row goes.
    conn = _db()
    try:
        conn.execute(
            "DELETE FROM inventory WHERE career_id = ? AND item_id = 'personal-suit'", (career_id,)
        )
        conn.commit()
    finally:
        conn.close()

    after = _attribute(api_client, career_id, "politeness")
    assert (after["value"], after["passive_bonus"], after["effective_value"]) == (58.0, 0, 58.0)


def test_effective_value_is_clamped_to_one_hundred(api_client, created_career):
    """§13.3 - or `level` would produce an eleventh bucket no `requires`
    threshold can express (MAX_REQUIREMENT_LEVEL is 10)."""
    career_id = created_career["career_id"]
    grant_money(career_id, 10000)
    set_attribute(career_id, "politeness", 99.0)
    api_client.post(f"/careers/{career_id}/purchases", json={"catalog_id": "personal-suit"})

    attr = _attribute(api_client, career_id, "politeness")
    assert attr["effective_value"] == 100.0
    assert attr["level"] == 10


def test_a_bought_item_opens_a_gate(api_client, created_career):
    """INV-61, and the point of §13.3 rather than a detail of it: the suit is
    supposed to open a door, and requirements.check reads the same number the
    screen shows."""
    career_id = created_career["career_id"]
    grant_money(career_id, 10000)
    # sos-taraftar wants charisma 7; sit just under it.
    set_attribute(career_id, "charisma", 68.0)   # level 6

    refused = api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": "sos-taraftar"})
    assert refused.status_code == 409
    assert refused.json()["code"] == "requirement_not_met"

    # personal-watch carries charisma +2.0 -> effective 70.0 -> level 7.
    assert api_client.post(
        f"/careers/{career_id}/purchases", json={"catalog_id": "personal-watch"}
    ).status_code == 200
    assert _attribute(api_client, career_id, "charisma")["level"] == 7

    allowed = api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": "sos-taraftar"})
    assert allowed.status_code == 200


def test_change_levels_are_reported_from_the_effective_value(api_client, created_career):
    """INV-61 on the write path too: a client updating its local copy from
    this response must not disagree with P1."""
    career_id = created_career["career_id"]
    grant_money(career_id, 10000)
    set_attribute(career_id, "charisma", 68.0)
    api_client.post(f"/careers/{career_id}/purchases", json={"catalog_id": "personal-watch"})  # +2

    # sos-arkadas gives charisma +0.3: base 68.0 -> 68.3, effective 70.0 -> 70.3.
    resp = api_client.post(f"/careers/{career_id}/actions", json={"catalog_id": "sos-arkadas"})
    assert resp.status_code == 200
    change = next(c for c in resp.json()["attribute_changes"] if c["key"] == "charisma")
    assert change["before"] == 68.0
    assert change["after"] == pytest.approx(68.3)
    assert change["passive_bonus"] == 2.0
    # Both levels come from base+bonus, which is why they read 7 and not 6.
    assert (change["level_before"], change["level_after"]) == (7, 7)
