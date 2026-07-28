from fastapi import FastAPI
from pydantic import BaseModel
from app.services.rag import UserQuery, answer 


class QueryResponse(BaseModel):
    answer: str

app = FastAPI()

@app.post("/query", response_model=QueryResponse)
def query_endpoint(queryRequest: UserQuery):
    response = answer(queryRequest.query)
    return QueryResponse(answer=response)

@app.get("/health")
def health_check():
    return {"status": "healthy"}