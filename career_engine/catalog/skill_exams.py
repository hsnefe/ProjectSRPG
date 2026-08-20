"""§2 - the Şut / Pas / Müdahale skill exams a new career sits after creation.

This is the single, central place that decides *which attribute each exam
moves, by how much per grade, and how high it may push it*. The domain layer
(domain/skill_exams.py) reads this table and nothing else — there is no
per-exam branch anywhere in the code, so adding a fourth exam or re-tuning the
grading curve is a data edit here.

Grading is a fixed 5-level scale (MIN_LEVEL..MAX_LEVEL). The award is
`level * points_per_level`, added on top of whatever the role already granted
(worlddata/attributes.py), then capped at the exam's own `max_value`. With
points_per_level = 1.0 that means grade 5 on the shooting exam is +5 shooting.

`max_value` is the ceiling the *exam* may raise the attribute to, deliberately
separate from player_attribute's own hard 0-100 clamp: an exam that should
never on its own produce a world-class number can be capped here without
stopping later training from getting there.
"""
from api.config import ATTRIBUTE_KEYS

# The 5-level grading scale every exam is scored on.
MIN_LEVEL = 1
MAX_LEVEL = 5

SKILL_EXAMS = [
    {
        "exam_id": "shooting",
        "title": "Şut Sınavı",
        "description": "Bitiricilik ve isabet ölçümü.",
        "attribute_key": "shooting",
        "points_per_level": 1.0,
        "max_value": 100.0,
    },
    {
        "exam_id": "passing",
        "title": "Pas Sınavı",
        "description": "Kısa ve uzun pas isabeti ölçümü.",
        "attribute_key": "passing",
        "points_per_level": 1.0,
        "max_value": 100.0,
    },
    {
        "exam_id": "tackling",
        "title": "Müdahale Sınavı",
        "description": "Top kapma ve ikili mücadele ölçümü.",
        "attribute_key": "tackling",
        "points_per_level": 1.0,
        "max_value": 100.0,
    },
]

_EXAMS_BY_ID = {e["exam_id"]: e for e in SKILL_EXAMS}

EXAM_IDS = tuple(e["exam_id"] for e in SKILL_EXAMS)


def get_exam(exam_id: str):
    """Returns the exam dict, or None if exam_id isn't in the catalog."""
    return _EXAMS_BY_ID.get(exam_id)


def award_for_level(exam: dict, level: int) -> float:
    """The raw points grade `level` is worth on `exam`, before the attribute's
    current value and max_value are taken into account."""
    return level * exam["points_per_level"]


# Same "fail the import, don't serve a half-validated catalog" stance as
# catalog/__init__.validate_catalog (INV-28): these are author-controlled data
# files, so a bad key is a build error, not a runtime skip.
assert len(_EXAMS_BY_ID) == len(SKILL_EXAMS), "duplicate exam_id"
assert MIN_LEVEL >= 1 and MAX_LEVEL > MIN_LEVEL
for _exam in SKILL_EXAMS:
    assert _exam["attribute_key"] in ATTRIBUTE_KEYS, (
        f"skill_exams:{_exam['exam_id']!r} targets unknown attribute "
        f"{_exam['attribute_key']!r}"
    )
    assert 0 < _exam["max_value"] <= 100.0
