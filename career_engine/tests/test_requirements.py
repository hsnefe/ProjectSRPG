"""§5.7 D42/D43 - the attribute gate's unit level: the scale itself
(attributes.level) and the check that reads it (requirements.check)."""
import pytest

from api import config
from api.errors import ApiError
from catalog import validate_requires
from domain import attributes, requirements


# --- D43: the scale --------------------------------------------------------

@pytest.mark.parametrize("value,expected", [
    (0.0, 0), (4.0, 0), (9.9, 0),      # the eleventh bucket
    (10.0, 1), (19.99, 1),
    (58.0, 5), (63.0, 6), (74.0, 7),   # three of the fresh-career kişi values
    (79.9, 7), (80.0, 8),
    (99.9, 9), (100.0, 10),            # only a maxed attribute reaches 10
])
def test_level_buckets_every_ten_points(value, expected):
    assert attributes.level(value) == expected


@pytest.mark.parametrize("n", range(11))
def test_level_is_exactly_the_threshold_equivalence(n):
    """The whole contract is `level N <=> value >= 10 * N`. If this ever
    stops holding, every `requires` threshold silently shifts."""
    assert attributes.level(10.0 * n) >= n
    if n > 0:
        assert attributes.level(10.0 * n - 0.01) < n


# --- unmet(): pure, no database -------------------------------------------

def test_unmet_reports_only_the_failing_keys_with_both_levels():
    levels = {"charisma": 7, "courage": 6}
    assert requirements.unmet(levels, {"charisma": 8, "courage": 6}) == {"charisma": (7, 8)}


def test_unmet_treats_a_missing_key_as_level_zero():
    assert requirements.unmet({}, {"charisma": 1}) == {"charisma": (0, 1)}


def test_unmet_of_an_empty_map_is_empty():
    assert requirements.unmet({"charisma": 0}, {}) == {}


# --- check(): against a real career ---------------------------------------

@pytest.fixture
def gated_player(db_conn, career_id, player_id):
    db_conn.execute(
        "INSERT INTO player_attribute (career_id, player_id, attribute_key, value) VALUES (?, ?, ?, ?)",
        (career_id, player_id, "charisma", 74.0),
    )
    return career_id, player_id


def test_check_passes_when_the_level_is_met_exactly(db_conn, gated_player):
    career_id, pid = gated_player
    requirements.check(db_conn, career_id, pid, {"charisma": 7})  # 74.0 -> 7


def test_check_raises_when_the_level_is_one_short(db_conn, gated_player):
    career_id, pid = gated_player
    with pytest.raises(ApiError) as exc:
        requirements.check(db_conn, career_id, pid, {"charisma": 8})
    assert exc.value.status_code == 409
    assert exc.value.code == "requirement_not_met"
    # §1.3: FE writes the sentence, so both numbers travel in the message.
    assert "7" in exc.value.message and "8" in exc.value.message


@pytest.mark.parametrize("requires", [None, {}])
def test_check_treats_an_absent_map_as_no_gate(db_conn, gated_player, requires):
    """The field is optional; its absence means "no gate", never "a gate
    with no keys that nobody can pass"."""
    career_id, pid = gated_player
    requirements.check(db_conn, career_id, pid, requires)


def test_check_raises_on_the_first_unmet_key_in_authored_order(db_conn, gated_player):
    career_id, pid = gated_player
    # Neither is met (empathy has no row at all -> level 0); the author's
    # order decides which one the message names.
    with pytest.raises(ApiError) as exc:
        requirements.check(db_conn, career_id, pid, {"empathy": 6, "charisma": 9})
    assert "empathy" in exc.value.message


def test_check_reads_a_missing_attribute_row_as_level_zero(db_conn, gated_player):
    career_id, pid = gated_player
    with pytest.raises(ApiError):
        requirements.check(db_conn, career_id, pid, {"discipline": 1})


# --- INV-31: what a `requires` map may contain ----------------------------

@pytest.mark.parametrize("bad", [
    {"speed": 3},          # not an attribute (§3.2's catalogue is closed)
    {"charisma": 11},      # above the scale — unclearable, so a typo
    {"charisma": -1},
    {"charisma": 6.5},     # levels are integers, not raw values
    {"charisma": "6"},
    {"charisma": True},    # bool is an int subclass; would read as level 1
])
def test_validate_requires_rejects(bad):
    with pytest.raises(ValueError):
        validate_requires(bad, "test")


@pytest.mark.parametrize("ok", [None, {}, {"charisma": 0}, {"charisma": 10},
                                {"empathy": 6, "intelligence": 6}])
def test_validate_requires_accepts(ok):
    validate_requires(ok, "test")


def test_every_shipped_requirement_names_a_real_attribute():
    """Belt and braces over the import-time asserts: if a catalog file ever
    stops calling validate_catalog(), this still catches a typo."""
    from catalog.dialogue import DIALOGUE_OUTCOMES
    from catalog.lifestyle import LIFESTYLE_ITEMS
    from catalog.training import TRAINING_ITEMS

    shipped = [item.get("requires", {}) for item in LIFESTYLE_ITEMS + TRAINING_ITEMS]
    shipped += [leaf.get("requires", {})
                for leaves in DIALOGUE_OUTCOMES.values() for leaf in leaves.values()]
    for requires in shipped:
        assert set(requires) <= set(config.ATTRIBUTE_KEYS)
