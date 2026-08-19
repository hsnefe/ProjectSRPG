from typing import Optional

from pydantic import BaseModel


class CreateCareerRequest(BaseModel):
    player_name: str
    position: str
    team_id: str
    seed: Optional[int] = None
