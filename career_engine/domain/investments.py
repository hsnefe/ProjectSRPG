"""§12.13 D65 - the weekly payout for owned `investment`-category shop items.
Structurally identical to sponsorship.py's pay_weekly(): same Monday gate
(the caller's, not this module's), same one wallet.apply() per row, same
reason-string shape. The only difference is the source table - a
sponsorship_deal row carries its own weekly_income, an inventory row carries
weekly_return (frozen at purchase, api/routers/time.py::post_purchase)."""
import sqlite3
from typing import List

from domain import wallet


def pay_returns(conn: sqlite3.Connection, career_id: str, on_date: str) -> List[dict]:
    entries = []
    for row in conn.execute(
        "SELECT item_id, weekly_return FROM inventory WHERE career_id = ? AND weekly_return > 0",
        (career_id,),
    ).fetchall():
        entries.append(wallet.apply(
            conn, career_id, row["weekly_return"], "investment",
            f"investment:{row['item_id']}:{on_date}",
            f"{on_date}T00:00:00+03:00",
        ))
    return entries
