"""§12.1 M4. M2's body stays a raw dict (see api/routers/matches.py's module
docstring on why), but the coach talk is a small closed request with two
fields, so a model earns its keep here: the topic is an enum and FastAPI can
reject an unknown one before any handler code runs."""
from typing import Literal, Optional

from pydantic import BaseModel


class CoachTalkRequest(BaseModel):
    topic: Literal[
        "philosophy_accept",
        "philosophy_reject",
        "style_accept",
        "style_reject",
        "request_position",
        "request_role",
    ]

    # Only the two request topics carry one: a position name for
    # request_position, a role_id for request_role. domain/coach_talk.py
    # rejects a value on the other four rather than ignoring it.
    value: Optional[str] = None
