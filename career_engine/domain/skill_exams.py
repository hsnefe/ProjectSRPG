"""§2 - turning Şut / Pas / Müdahale / Dribling grades into player_attribute points.

All the tuning lives in catalog/skill_exams.py; this module only enforces the
rules around it: a grade must be on the 5-level scale, an exam must be known,
an exam may be sat once, and the award may not push the attribute past the
exam's own max_value.

Writes go through domain/attributes.apply_delta() rather than a direct UPDATE,
so player_attribute keeps its single write path (D30) and its 0-100 clamp.
Does not commit — the router does, once (INV-3).
"""
import sqlite3
from typing import List

from api import errors
from catalog.skill_exams import MAX_LEVEL, MIN_LEVEL, SKILL_EXAMS, get_exam
from domain import attributes


def submitted_exam_ids(conn: sqlite3.Connection, career_id: str, player_id: str) -> set:
    rows = conn.execute(
        "SELECT exam_id FROM skill_exam_result WHERE career_id = ? AND player_id = ?",
        (career_id, player_id),
    ).fetchall()
    return {r["exam_id"] for r in rows}


def apply_results(
    conn: sqlite3.Connection,
    career_id: str,
    player_id: str,
    results: List[dict],
    applied_at: str,
) -> List[dict]:
    """`results` is a list of {"exam_id": str, "level": int}. Validates the
    whole batch before writing anything, so a bad grade on the third exam
    doesn't leave the first two applied (INV-3 in spirit — the router's single
    commit only helps if nothing half-writes first).

    Returns one dict per exam: exam_id, level, attribute_key, before, after,
    applied (the points that actually landed after max_value and the 0-100
    clamp, which is not always level * points_per_level).
    """
    if not results:
        raise errors.invalid_request("results must not be empty")

    seen = set()
    validated = []
    for entry in results:
        exam_id = entry["exam_id"]
        level = entry["level"]

        exam = get_exam(exam_id)
        if exam is None:
            known = tuple(e["exam_id"] for e in SKILL_EXAMS)
            raise errors.invalid_request(f"unknown exam_id {exam_id!r}, expected one of {known}")
        if exam_id in seen:
            raise errors.invalid_request(f"exam_id {exam_id!r} appears twice in one request")
        seen.add(exam_id)

        if not isinstance(level, int) or isinstance(level, bool):
            raise errors.invalid_request(f"level for {exam_id!r} must be an integer")
        if not MIN_LEVEL <= level <= MAX_LEVEL:
            raise errors.invalid_request(
                f"level for {exam_id!r} must be between {MIN_LEVEL} and {MAX_LEVEL}, got {level}"
            )
        validated.append((exam, level))

    already = submitted_exam_ids(conn, career_id, player_id) & seen
    if already:
        raise errors.skill_exam_already_taken(sorted(already))

    changes = []
    for exam, level in validated:
        key = exam["attribute_key"]
        current = attributes.get_value(conn, career_id, player_id, key)
        award = level * exam["points_per_level"]
        # The exam's own ceiling, on top of apply_delta's 0-100 clamp: an exam
        # never drags an attribute down, so a player already above max_value
        # simply gains nothing rather than being pulled back to it.
        target = min(current + award, exam["max_value"])
        delta = max(0.0, target - current)

        change = attributes.apply_delta(conn, career_id, player_id, key, delta)
        conn.execute(
            "INSERT INTO skill_exam_result (career_id, player_id, exam_id, level, applied_at) "
            "VALUES (?, ?, ?, ?, ?)",
            (career_id, player_id, exam["exam_id"], level, applied_at),
        )
        changes.append({
            "exam_id": exam["exam_id"],
            "level": level,
            "attribute_key": key,
            "before": change["before"],
            "after": change["after"],
            "applied": change["after"] - change["before"],
        })
    return changes
