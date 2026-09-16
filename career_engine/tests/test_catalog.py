import json

import pytest

from catalog import validate_catalog
from catalog.dialogue import DIALOGUE_OUTCOMES, public_catalog
from catalog.lifestyle import LIFESTYLE_ITEMS
from catalog.shop import SHOP_ITEMS
from catalog.training import TRAINING_ITEMS


def test_training_catalog_covers_every_attribute():
    keys = {
        e.split(":", 1)[1]
        for item in TRAINING_ITEMS
        for e in item["effects"]
        if e.startswith("attribute:")
    }
    from api.config import ATTRIBUTE_KEYS
    assert keys == set(ATTRIBUTE_KEYS)


def test_training_catalog_covers_every_tactic():
    keys = {
        e.split(":", 1)[1]
        for item in TRAINING_ITEMS
        for e in item["effects"]
        if e.startswith("tactic:")
    }
    from api.config import TACTIC_KEYS
    assert keys == set(TACTIC_KEYS)


def test_validate_catalog_rejects_unknown_effect_key():
    with pytest.raises(ValueError):
        validate_catalog(
            [{"catalog_id": "x", "costs": {}, "effects": {"not_a_real_key": 1}}], "test"
        )


def test_validate_catalog_rejects_unknown_cost_key():
    with pytest.raises(ValueError):
        validate_catalog(
            [{"catalog_id": "x", "costs": {"stamina_points": 5}, "effects": {}}], "test"
        )


def test_validate_catalog_rejects_unknown_attribute_in_effect():
    with pytest.raises(ValueError):
        validate_catalog(
            [{"catalog_id": "x", "costs": {}, "effects": {"attribute:speed": 1}}], "test"
        )


def test_validate_catalog_rejects_unknown_tactic_in_effect():
    with pytest.raises(ValueError):
        validate_catalog(
            [{"catalog_id": "x", "costs": {}, "effects": {"tactic:tiki_taka": 1}}], "test"
        )


def test_validate_catalog_accepts_all_documented_anchor_shapes():
    validate_catalog(
        [{
            "catalog_id": "x", "costs": {"time": 10, "energy": 5},
            "effects": {
                "attribute:shooting": 1.0, "tactic:gegenpress": 0.8,
                "condition": 5, "energy": 3,
                "money": -100, "fame:overall": 1, "relationship:coach": 2,
            },
        }],
        "test",
    )


@pytest.mark.parametrize(
    "items,name",
    [(TRAINING_ITEMS, "training"), (LIFESTYLE_ITEMS, "lifestyle"), (SHOP_ITEMS, "shop")],
)
def test_real_catalogs_pass_validation(items, name):
    validate_catalog(items, name)  # would already have raised at import time


# --- §6.6: `daily_effects` on shop items ---------------------------------

def test_validate_catalog_rejects_unknown_daily_effect_key():
    """Narrower than `effects` on purpose: the day loop applies `condition`
    and nothing else, so a `money` key here would be a row that silently
    does nothing every day (INV-28)."""
    with pytest.raises(ValueError):
        validate_catalog([{"catalog_id": "x", "daily_effects": {"money": 10}}], "test")


def test_validate_catalog_rejects_non_numeric_daily_effect():
    with pytest.raises(ValueError):
        validate_catalog([{"catalog_id": "x", "daily_effects": {"condition": "iki"}}], "test")


def test_validate_catalog_rejects_a_boolean_daily_effect():
    # bool is an int subclass; True would otherwise read as +1 a day.
    with pytest.raises(ValueError):
        validate_catalog([{"catalog_id": "x", "daily_effects": {"condition": True}}], "test")


def test_validate_catalog_rejects_a_negative_daily_effect():
    with pytest.raises(ValueError):
        validate_catalog([{"catalog_id": "x", "daily_effects": {"condition": -3}}], "test")


def test_validate_catalog_accepts_an_item_with_no_daily_effects_at_all():
    validate_catalog([{"catalog_id": "x", "costs": {}, "effects": {}}], "test")


def test_daily_condition_bonus_sums_only_the_items_that_carry_one():
    from catalog.shop import DAILY_CONDITION_BONUS, daily_condition_bonus

    assert set(DAILY_CONDITION_BONUS) <= {i["catalog_id"] for i in SHOP_ITEMS}
    assert daily_condition_bonus([]) == 0
    assert daily_condition_bonus(["home-tv"]) == 0
    assert daily_condition_bonus(list(DAILY_CONDITION_BONUS)) == sum(DAILY_CONDITION_BONUS.values())


def test_every_daily_effect_bonus_is_reachable_from_the_shop():
    """The bonus table is derived from SHOP_ITEMS at import, so a typo'd id
    can't hide in it — this asserts the derivation, which is what makes
    "adding an item is a one-file edit" true."""
    from catalog.shop import DAILY_CONDITION_BONUS

    for item in SHOP_ITEMS:
        expected = item.get("daily_effects", {}).get("condition")
        assert DAILY_CONDITION_BONUS.get(item["catalog_id"]) == expected or expected in (None, 0)


# --- D42: `requires` on catalog items ------------------------------------

def test_validate_catalog_rejects_unknown_attribute_in_requires():
    with pytest.raises(ValueError):
        validate_catalog(
            [{"catalog_id": "x", "costs": {}, "effects": {}, "requires": {"speed": 3}}], "test"
        )


def test_validate_catalog_rejects_out_of_range_requirement_level():
    with pytest.raises(ValueError):
        validate_catalog(
            [{"catalog_id": "x", "costs": {}, "effects": {}, "requires": {"charisma": 11}}], "test"
        )


def test_validate_catalog_accepts_an_item_with_no_requires_at_all():
    validate_catalog([{"catalog_id": "x", "costs": {}, "effects": {}}], "test")


def test_social_lifestyle_items_grow_kişi_attributes():
    """D31/D42's third leg: a social activity develops the player, not just
    their wallet and condition."""
    from api.config import ATTRIBUTE_KEYS

    social = [i for i in LIFESTYLE_ITEMS if i["group"] == "SOSYAL AKTİVİTELER"]
    assert social, "the SOSYAL group is what this test is about"
    for item in social:
        kişi = {
            e.split(":", 1)[1] for e in item["effects"]
            if e.startswith("attribute:") and ATTRIBUTE_KEYS[e.split(":", 1)[1]] == "kişi"
        }
        assert kişi, f"{item['catalog_id']} moves no kişi attribute"


# --- INV-32 / N3 'dialogue' ----------------------------------------------

def test_every_dialogue_tree_keeps_at_least_one_ungated_leaf():
    """INV-32 — asserted at import too, restated here so the guarantee is
    visible to anyone reading the tests rather than the module footer."""
    for dialogue_id, leaves in DIALOGUE_OUTCOMES.items():
        assert any(not leaf.get("requires") for leaf in leaves.values()), dialogue_id


def test_dialogue_catalog_lists_every_tree_with_its_relationship():
    from catalog.dialogue import DIALOGUE_RELATIONSHIP

    items = public_catalog()
    assert {i["dialogue_id"] for i in items} == set(DIALOGUE_OUTCOMES)
    for item in items:
        assert item["relationship_id"] == DIALOGUE_RELATIONSHIP[item["dialogue_id"]]
        assert {leaf["leaf_id"] for leaf in item["leaves"]} == set(
            DIALOGUE_OUTCOMES[item["dialogue_id"]]
        )


def test_dialogue_catalog_never_leaks_the_outcome_table():
    """The whole reason this projection exists (D23/D42): publishing the
    deltas would spoil the conversation AND hand a client the table the
    server keeps precisely so the client can't score itself."""
    serialized = json.dumps(public_catalog())
    assert "relationship_delta" not in serialized
    assert "attribute_effects" not in serialized
    for item in public_catalog():
        for leaf in item["leaves"]:
            assert set(leaf) == {"leaf_id", "requires"}


def test_dialogue_catalog_carries_the_thresholds_fe_needs(api_client):
    resp = api_client.get("/catalog/dialogue")
    assert resp.status_code == 200
    media = next(i for i in resp.json()["items"] if i["dialogue_id"] == "media_01")
    r0 = next(leaf for leaf in media["leaves"] if leaf["leaf_id"] == "r0")
    assert r0["requires"] == {"charisma": 8}
    r1 = next(leaf for leaf in media["leaves"] if leaf["leaf_id"] == "r1")
    assert r1["requires"] == {}


def test_unknown_catalog_kind_still_errors(api_client):
    assert api_client.get("/catalog/dialogues").status_code == 422
