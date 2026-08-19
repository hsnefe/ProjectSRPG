from typing import List

from pydantic import BaseModel


class InteractRequest(BaseModel):
    dialogue_id: str
    choice_path: List[str]
