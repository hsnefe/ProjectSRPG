"""§5.7 N1-N2."""
import sqlite3
from typing import Optional

from fastapi import APIRouter, Depends, Query

from api import config, errors, serializers
from api.deps import get_db

router = APIRouter(prefix="/careers/{career_id}/news", tags=["news"])


def _excerpt(body: str) -> str:
    return body.split("\n\n", 1)[0]


def _row_to_item(row: sqlite3.Row) -> dict:
    return {
        "news_id": row["news_id"],
        "published_at": row["published_at"],
        "category": row["category"],
        "title": row["title"],
        "source": row["source"],
        "excerpt": _excerpt(row["body"]),
        "fixture_id": row["fixture_id"],
    }


@router.get("")
def list_news(
    career_id: str,
    limit: int = Query(config.DEFAULT_PAGE_SIZE, le=config.MAX_PAGE_SIZE),
    before: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    conn: sqlite3.Connection = Depends(get_db),
):
    serializers.require_career(conn, career_id)
    sql = "SELECT * FROM news WHERE career_id = ?"
    params = [career_id]
    if before:
        # N1's `before` is literal: strictly older than this timestamp —
        # newest-first feed, unlike W3's forward-ascending fixture cursor.
        sql += " AND published_at < ?"
        params.append(before)
    if category:
        sql += " AND category = ?"
        params.append(category)
    # news_id is the tiebreak, not decoration: `before` is a strictly-
    # exclusive published_at cursor, so if two rows ever shared a timestamp
    # the order between them would be undefined AND a page boundary landing
    # inside that group would drop the rest of it from the feed forever.
    # domain/news._published_at() makes timestamps unique per career-day; a
    # hand-written publish() call (or an older career's rows) is not bound
    # by that, so the read side does not depend on it.
    sql += " ORDER BY published_at DESC, news_id DESC LIMIT ?"
    params.append(limit)

    rows = conn.execute(sql, params).fetchall()
    items = [_row_to_item(r) for r in rows]
    next_before = items[-1]["published_at"] if len(items) == limit else None
    return {"items": items, "next_before": next_before}


@router.get("/{news_id}")
def get_news_item(career_id: str, news_id: str, conn: sqlite3.Connection = Depends(get_db)):
    serializers.require_career(conn, career_id)
    row = conn.execute(
        "SELECT * FROM news WHERE career_id = ? AND news_id = ?", (career_id, news_id)
    ).fetchone()
    if row is None:
        raise errors.invalid_request(f"unknown news_id {news_id!r}")
    return {**_row_to_item(row), "body": row["body"]}
