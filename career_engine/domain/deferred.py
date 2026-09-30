"""§14.6 D94, INV-68 - consequences that come due later.

The design doc has two things that do not fit "you chose, it applied": a secret
that surfaces five weeks after you told it, and a chain where ignoring the new
signing is what puts him in the rival clique three weeks later. Both are the same
mechanism - a choice writes down *what will happen* and *when*, and the day loop
makes it happen.

Why a table and not `plan_days_ahead`'s approach (D76): a plan *locks* a day. A
consequence locks nothing - the player is free to do whatever they like for the
next five weeks, which is the whole point of a slow fuse.

**Applied exactly once (INV-68).** `apply_due` flips the row to `applied` in the
same transaction that writes its effects, and only reads `pending` rows, so an
advance that is retried, or a day processed twice, cannot pay it twice.

**Applied in a place that cannot answer back.** It runs inside the day loop, so
money losses are clamped to the balance (domain/effects.py `clamp_money`) instead
of raising `insufficient_funds` out of an advance.

Like every domain module: nothing here commits.
"""
import datetime as _dt
import json
import sqlite3
from typing import List

from api.ids import new_deferred_consequence_id
from domain import effects, triggers

PENDING = "pending"
APPLIED = "applied"


def schedule(
    conn: sqlite3.Connection, career_id: str, on_date: str, source: str, later: dict
) -> str:
    """Writes one consequence from a template option's `defer` entry."""
    consequence_id = new_deferred_consequence_id()
    due_on = (_dt.date.fromisoformat(on_date) + _dt.timedelta(days=later["days"])).isoformat()
    conn.execute(
        "INSERT INTO deferred_consequence (career_id, consequence_id, due_on, effects, source, "
        "news, followup_template, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        (
            career_id, consequence_id, due_on, json.dumps(later["effects"]), source,
            json.dumps(later["news"], ensure_ascii=False) if later.get("news") else None,
            later.get("followup"), PENDING,
        ),
    )
    return consequence_id


def list_pending(conn: sqlite3.Connection, career_id: str) -> List[dict]:
    rows = conn.execute(
        "SELECT * FROM deferred_consequence WHERE career_id = ? AND status = ? "
        "ORDER BY due_on, consequence_id",
        (career_id, PENDING),
    ).fetchall()
    return [
        {"consequence_id": r["consequence_id"], "due_on": r["due_on"], "source": r["source"],
         "effects": json.loads(r["effects"]), "followup_template": r["followup_template"]}
        for r in rows
    ]


def apply_due(conn: sqlite3.Connection, career_id: str, on_date: str) -> List[dict]:
    """Applies everything due on or before `on_date`, oldest first, and returns
    {"consequence_id", "news": dict|None} per row so the caller can write the
    headline (daytime owns _create_news; importing it here would be a cycle)."""
    rows = conn.execute(
        "SELECT * FROM deferred_consequence WHERE career_id = ? AND status = ? AND due_on <= ? "
        "ORDER BY due_on, consequence_id",
        (career_id, PENDING, on_date),
    ).fetchall()
    done = []
    for row in rows:
        effects.apply(
            conn, career_id, json.loads(row["effects"]), "lifestyle",
            f"deferred:{row['source']}", f"{on_date}T08:00:00+03:00", clamp_money=True,
        )
        if row["followup_template"]:
            triggers.enqueue(
                conn, career_id, row["followup_template"], "deferred", on_date,
                dedupe_key=f"deferred:{row['consequence_id']}",
            )
        conn.execute(
            "UPDATE deferred_consequence SET status = ?, applied_on = ? "
            "WHERE career_id = ? AND consequence_id = ?",
            (APPLIED, on_date, career_id, row["consequence_id"]),
        )
        done.append({
            "consequence_id": row["consequence_id"],
            "news": json.loads(row["news"]) if row["news"] else None,
        })
    return done
