from typing import Literal, Optional

from pydantic import BaseModel


class ActionRequest(BaseModel):
    catalog_id: str
    result: Optional[dict] = None


class AdvanceRequest(BaseModel):
    to: Literal["next_day", "next_event"]


class PurchaseRequest(BaseModel):
    catalog_id: str
