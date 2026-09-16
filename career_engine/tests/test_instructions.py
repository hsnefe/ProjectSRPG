"""§12.10 — the coach's match-day instruction (`focus` default + freeze)."""
import pytest

from domain import instructions


def _insert_fixture(conn, career_id, fixture_id="f_test0001"):
    conn.execute(
        "INSERT INTO fixture "
        "(career_id, fixture_id, season_id, competition_id, round_no, "
        " kickoff_at, home_team_id, away_team_id, status) "
        "VALUES (?, ?, '25/26', 'lig', 1, '2026-08-19T18:00:00+03:00', "
        " 't_ykz', 't_dnz', 'scheduled')",
        (career_id, fixture_id),
    )
    conn.commit()
    return fixture_id


def _set_role(conn, career_id, player_id, role_id):
    conn.execute(
        "UPDATE player SET role = ? WHERE career_id = ? AND player_id = ?",
        (role_id, career_id, player_id),
    )
    conn.commit()


def _row_value(conn, career_id, fixture_id):
    return conn.execute(
        "SELECT user_match_instruction FROM fixture WHERE career_id = ? AND fixture_id = ?",
        (career_id, fixture_id),
    ).fetchone()["user_match_instruction"]


# --- lazy freeze ------------------------------------------------------------

def test_unasked_fixture_row_stays_sql_null(db_conn, career_id, player_id):
    """Before anything asks, the column is SQL NULL — not the 'any' string.
    The two absences mean different things (§12.10 migration note) and only
    `instruction_for`/`set_instruction` may collapse one into the other."""
    fixture_id = _insert_fixture(db_conn, career_id)
    assert _row_value(db_conn, career_id, fixture_id) is None


def test_decided_once_and_sticks(db_conn, career_id, player_id):
    """`stoper` is 'defend' (worlddata/positions.py). First ask derives and
    freezes it; a later role change must not move the frozen value."""
    fixture_id = _insert_fixture(db_conn, career_id)
    _set_role(db_conn, career_id, player_id, "stoper")

    first = instructions.instruction_for(db_conn, career_id, fixture_id)
    db_conn.commit()
    assert first == "defend"
    assert _row_value(db_conn, career_id, fixture_id) == "defend"

    # Role changes after the freeze; the fixture's instruction must not.
    _set_role(db_conn, career_id, player_id, "forvet")  # 'attack'
    second = instructions.instruction_for(db_conn, career_id, fixture_id)
    assert second == "defend"


def test_any_instruction_freezes_as_the_string_not_null(db_conn, career_id, player_id):
    """`box_to_box` is deliberately 'any' — freezing it must write the
    string, not leave the column NULL (which would read back as
    "never asked" and re-decide every time)."""
    fixture_id = _insert_fixture(db_conn, career_id)
    _set_role(db_conn, career_id, player_id, "box_to_box")

    value = instructions.instruction_for(db_conn, career_id, fixture_id)
    db_conn.commit()
    assert value == "any"
    assert _row_value(db_conn, career_id, fixture_id) == "any"


def test_unknown_or_missing_role_defaults_to_any(db_conn, career_id, player_id):
    """A career past onboarding always has a role, but the fallback exists
    so a fixture row never 500s just because a role_id doesn't resolve."""
    fixture_id = _insert_fixture(db_conn, career_id)
    _set_role(db_conn, career_id, player_id, "bir_gun_eklenecek_rol")

    assert instructions.instruction_for(db_conn, career_id, fixture_id) == "any"


def test_no_fixture_row_reports_any_without_writing(db_conn, career_id):
    """A fixture that doesn't belong to this career (or doesn't exist) is
    not this module's problem to raise on — callers gate on the fixture's
    existence themselves. Mirrors `squad.status_for`'s `None -> OUT`."""
    assert instructions.instruction_for(db_conn, career_id, "f_does_not_exist") == "any"


# --- peek: read without freezing --------------------------------------------

def test_peek_does_not_write(db_conn, career_id, player_id):
    """The whole reason `peek` exists: a validation gate that runs before
    `day_budget.spend()` must not freeze a default as a side effect of a
    request that might still be refused (INV-4)."""
    fixture_id = _insert_fixture(db_conn, career_id)
    _set_role(db_conn, career_id, player_id, "regista")

    assert instructions.peek(db_conn, career_id, fixture_id) == "tactical"
    assert _row_value(db_conn, career_id, fixture_id) is None  # still unfrozen


def test_peek_reads_a_frozen_value_once_one_exists(db_conn, career_id, player_id):
    fixture_id = _insert_fixture(db_conn, career_id)
    _set_role(db_conn, career_id, player_id, "regista")
    instructions.instruction_for(db_conn, career_id, fixture_id)
    db_conn.commit()

    # Role changes after freezing; peek must report the frozen value, not
    # re-derive from the new role.
    _set_role(db_conn, career_id, player_id, "forvet")
    assert instructions.peek(db_conn, career_id, fixture_id) == "tactical"


# --- set_instruction: the one override path ---------------------------------

def test_set_instruction_overwrites_a_frozen_value(db_conn, career_id, player_id):
    fixture_id = _insert_fixture(db_conn, career_id)
    _set_role(db_conn, career_id, player_id, "stoper")
    instructions.instruction_for(db_conn, career_id, fixture_id)
    db_conn.commit()

    instructions.set_instruction(db_conn, career_id, fixture_id, "attack")
    db_conn.commit()

    assert instructions.instruction_for(db_conn, career_id, fixture_id) == "attack"
    assert _row_value(db_conn, career_id, fixture_id) == "attack"


def test_set_instruction_rejects_an_unknown_value(db_conn, career_id, player_id):
    fixture_id = _insert_fixture(db_conn, career_id)
    with pytest.raises(AssertionError):
        instructions.set_instruction(db_conn, career_id, fixture_id, "farketmez")


# --- wire helpers ------------------------------------------------------------

def test_focus_wire_maps_any_to_null_and_passes_the_rest_through():
    assert instructions.focus_wire("any") is None
    assert instructions.focus_wire("attack") == "attack"
    assert instructions.focus_wire("defend") == "defend"
    assert instructions.focus_wire("tactical") == "tactical"


def test_label_matches_the_directive_options_focus_strings():
    """Same four labels §8.1's `directive_options.focus` sends, so the
    pre-match card and the in-match 'Rol' sheet agree."""
    assert instructions.label("attack") == "Hücum"
    assert instructions.label("defend") == "Savunma"
    assert instructions.label("tactical") == "Taktik"
    assert instructions.label("any") == "Farketmez"
