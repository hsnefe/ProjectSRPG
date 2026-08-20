from typing import List, Optional

from pydantic import BaseModel


class CreateCareerRequest(BaseModel):
    """§5.1 C1. No team_id: §3 derives the starting club from `nationality`,
    and the only club the user names is target_team_id — the one they're
    aiming at, which is stored but never played for on day one."""
    first_name: str
    last_name: str
    nationality: str          # worlddata/countries.py country_code, e.g. "TR"
    position: str             # worlddata/positions.py POSITIONS entry
    role: str                 # worlddata/positions.py role_id, must match position
    target_team_id: str
    seed: Optional[int] = None


class SkillExamResult(BaseModel):
    exam_id: str              # catalog/skill_exams.py EXAM_IDS
    level: int                # MIN_LEVEL..MAX_LEVEL


class SubmitSkillExamsRequest(BaseModel):
    """A batch rather than one exam per call: the three exams are one FE flow,
    and applying them together means a bad grade in the middle rejects the
    whole submission instead of leaving the player half-graded."""
    results: List[SkillExamResult]
