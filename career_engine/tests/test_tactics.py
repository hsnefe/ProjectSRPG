"""§12.11 D63 - domain.tactics is player_tactics.value's single write path,
the same clamp shape as domain.attributes but on its own upserted table
(no seed row at career creation)."""
from domain import tactics


def test_get_value_defaults_to_zero_for_an_untrained_tactic(db_conn, career_id, player_id):
    assert tactics.get_value(db_conn, career_id, player_id, "gegenpress") == 0.0


def test_apply_delta_creates_the_row_on_first_use(db_conn, career_id, player_id):
    result = tactics.apply_delta(db_conn, career_id, player_id, "gegenpress", 0.8)
    db_conn.commit()

    assert result == {"key": "gegenpress", "before": 0.0, "after": 0.8}
    assert tactics.get_value(db_conn, career_id, player_id, "gegenpress") == 0.8


def test_apply_delta_accumulates_on_the_same_row(db_conn, career_id, player_id):
    tactics.apply_delta(db_conn, career_id, player_id, "pozisyonel_oyun", 0.8)
    tactics.apply_delta(db_conn, career_id, player_id, "pozisyonel_oyun", 0.8)
    db_conn.commit()

    assert tactics.get_value(db_conn, career_id, player_id, "pozisyonel_oyun") == 1.6


def test_apply_delta_clamps_to_100(db_conn, career_id, player_id):
    tactics.apply_delta(db_conn, career_id, player_id, "derin_blok", 250)
    assert tactics.get_value(db_conn, career_id, player_id, "derin_blok") == 100.0


def test_apply_delta_clamps_to_0(db_conn, career_id, player_id):
    tactics.apply_delta(db_conn, career_id, player_id, "derin_blok", -5)
    assert tactics.get_value(db_conn, career_id, player_id, "derin_blok") == 0.0


def test_different_tactic_keys_do_not_share_a_row(db_conn, career_id, player_id):
    tactics.apply_delta(db_conn, career_id, player_id, "gegenpress", 4.0)
    tactics.apply_delta(db_conn, career_id, player_id, "derin_blok", 1.0)
    db_conn.commit()

    assert tactics.get_value(db_conn, career_id, player_id, "gegenpress") == 4.0
    assert tactics.get_value(db_conn, career_id, player_id, "derin_blok") == 1.0
