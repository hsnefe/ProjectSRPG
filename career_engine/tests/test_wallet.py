import pytest

from api.errors import ApiError
from domain import wallet


def test_apply_updates_balance_and_writes_ledger(db_conn, career_id):
    entry = wallet.apply(db_conn, career_id, 48200, "starting_balance", "career:init", "2026-01-01")
    db_conn.commit()

    assert entry["balance_after"] == 48200
    assert wallet.get_balance(db_conn, career_id) == 48200


def test_apply_rejects_overdraft_and_writes_nothing(db_conn, career_id):
    wallet.apply(db_conn, career_id, 100, "starting_balance", "career:init", "2026-01-01")
    db_conn.commit()

    with pytest.raises(ApiError) as exc_info:
        wallet.apply(db_conn, career_id, -250, "purchase", "purchase:x", "2026-01-02")
    assert exc_info.value.code == "insufficient_funds"

    # INV-5: the failed attempt changed nothing.
    assert wallet.get_balance(db_conn, career_id) == 100
    assert wallet.ledger_total(db_conn, career_id) == 100


def test_ledger_total_matches_balance_inv19(db_conn, career_id):
    wallet.apply(db_conn, career_id, 48200, "starting_balance", "career:init", "2026-01-01")
    wallet.apply(db_conn, career_id, -250, "lifestyle", "lifestyle:ev-yemek", "2026-01-02")
    wallet.apply(db_conn, career_id, 12000, "wage", "wage:2026-W01", "2026-01-05")
    wallet.apply(db_conn, career_id, -1800, "upkeep", "upkeep:daire-merkez", "2026-01-05")
    db_conn.commit()

    assert wallet.ledger_total(db_conn, career_id) == wallet.get_balance(db_conn, career_id)
