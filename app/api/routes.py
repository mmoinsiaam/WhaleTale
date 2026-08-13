from fastapi import FastAPI
from app.schema.models import UserQuery, QueryResponse
from app.services.rag import answer 




app = FastAPI()

@app.post("/query", response_model=QueryResponse)
def query_endpoint(queryRequest: UserQuery):
    response = answer(queryRequest.query, queryRequest.history)
    return QueryResponse(answer=response)

@app.get("/health")
def health_check():
    return {"status": "healthy"}