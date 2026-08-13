from pydantic import BaseModel
from typing import List, Optional

class HistoryTurn(BaseModel):
    query: str
    answer: str

class UserQuery(BaseModel):
    query: str
    history: Optional[List[HistoryTurn]] = None

class QueryResponse(BaseModel):
    answer: str