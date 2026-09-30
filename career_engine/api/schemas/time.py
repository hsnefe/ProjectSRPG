from typing import Literal, Optional

from pydantic import BaseModel


class ActionRequest(BaseModel):
    catalog_id: str
    result: Optional[dict] = None
    # §14.3 D84 - who the activity is done with: one of the six relationship
    # kinds the activity's `with` list allows. Required for mode 'B', optional
    # for 'S/B' (absent = alone), refused for 'S'.
    relationship_id: Optional[str] = None


class AdvanceRequest(BaseModel):
    to: Literal["next_day", "next_event"]


class PurchaseRequest(BaseModel):
    catalog_id: str
