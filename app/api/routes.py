from fastapi import FastAPI
from app.services.rag import userQuery, answer 

app = FastAPI()

@app.post("/query")
async def query_endpoint(queryRequest: userQuery):
    response = answer(queryRequest.query)
    return {"answer": response}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}