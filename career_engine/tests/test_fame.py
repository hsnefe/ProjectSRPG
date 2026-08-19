from domain import fame


def test_apply_creates_row_when_none_exists(db_conn, career_id):
    result = fame.apply(db_conn, career_id, "p_user", 5.0, "lifestyle:sos-taraftar", "2026-01-01")
    db_conn.commit()

    assert result["value_after"] == 5.0
    assert fame.get_value(db_conn, career_id, "p_user") == 5.0


def test_apply_accumulates_and_logs_events(db_conn, career_id):
    fame.apply(db_conn, career_id, "p_user", 5.0, "a", "2026-01-01")
    fame.apply(db_conn, career_id, "p_user", 2.5, "b", "2026-01-02")
    fame.apply(db_conn, career_id, "p_user", -1.0, "c", "2026-01-03")
    db_conn.commit()

    assert fame.get_value(db_conn, career_id, "p_user") == 6.5

    events = db_conn.execute(
        "SELECT COUNT(*) AS n FROM fame_event WHERE career_id = ? AND player_id = ?",
        (career_id, "p_user"),
    ).fetchone()
    assert events["n"] == 3


def test_get_value_defaults_to_zero(db_conn, career_id):
    assert fame.get_value(db_conn, career_id, "p_user") == 0.0
