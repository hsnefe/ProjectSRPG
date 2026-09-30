"""§12.13 D65 - domain.investments.pay_returns(), tested directly against the
inventory table rather than through T3's day loop (that round trip is
covered in test_time_router.py's Monday-advance tests)."""
from domain import investments


def _own(conn, career_id, item_id, weekly_return, price_paid=1000):
    conn.execute(
        "INSERT INTO inventory (career_id, item_id, purchased_at, price_paid, "
        "upkeep_weekly, weekly_return) VALUES (?, ?, '2026-08-01', ?, 0, ?)",
        (career_id, item_id, price_paid, weekly_return),
    )
    conn.commit()


def test_pay_returns_pays_every_owned_item_with_a_return(db_conn, career_id):
    _own(db_conn, career_id, "invest-bond", 11)
    _own(db_conn, career_id, "invest-gold", 3)

    entries = investments.pay_returns(db_conn, career_id, "2026-08-03")
    db_conn.commit()

    assert {e["kind"] for e in entries} == {"investment"}
    assert sorted(e["amount"] for e in entries) == [3, 11]


def test_pay_returns_skips_items_with_no_return(db_conn, career_id):
    _own(db_conn, career_id, "home-cinema", 0)  # not an investment item, no return
    entries = investments.pay_returns(db_conn, career_id, "2026-08-03")
    assert entries == []


def test_pay_returns_uses_a_distinct_reason_per_item_and_date(db_conn, career_id):
    _own(db_conn, career_id, "invest-bond", 11)
    entries = investments.pay_returns(db_conn, career_id, "2026-08-03")
    assert entries[0]["reason"] == "investment:invest-bond:2026-08-03"
