import pytest

from catalog import validate_catalog
from catalog.lifestyle import LIFESTYLE_ITEMS
from catalog.shop import SHOP_ITEMS
from catalog.training import TRAINING_ITEMS


def test_training_catalog_covers_all_eleven_attributes():
    keys = {
        e.split(":", 1)[1]
        for item in TRAINING_ITEMS
        for e in item["effects"]
        if e.startswith("attribute:")
    }
    from api.config import ATTRIBUTE_KEYS
    assert keys == set(ATTRIBUTE_KEYS)


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


def test_validate_catalog_accepts_all_documented_anchor_shapes():
    validate_catalog(
        [{
            "catalog_id": "x", "costs": {"time": 10, "energy": 5},
            "effects": {
                "attribute:shooting": 1.0, "condition": 5, "energy": 3,
                "money": -100, "fame:overall": 1, "relationship:coach": 2,
            },
        }],
        "test",
    )


@pytest.mark.parametrize("items,name", [(TRAINING_ITEMS, "training"), (LIFESTYLE_ITEMS, "lifestyle")])
def test_real_catalogs_pass_validation(items, name):
    validate_catalog(items, name)  # would already have raised at import time
