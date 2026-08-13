from ast import List
import time
import logging
from typing import Optional
import numpy as np
from openai import OpenAI
from app.config import openai_api_key, redis_url
from pydantic import BaseModel
from app.services.redis_client import get_index, get_vector_query
from app.services.llm import generate_response, rewrite_query_with_history

#user query > embedding > search redis > get context > send to openai > get answer

class HistoryTurn(BaseModel):
    query: str
    answer: str

class UserQuery(BaseModel):
    query: str
    history: Optional[List[HistoryTurn]] = None

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s"
)

client = OpenAI(api_key=openai_api_key)
#redis_db = get_redis_client()
index = get_index()
index.connect(redis_url)  # Connect to Redis using the URL from config
logger = logging.getLogger(__name__)

def embed_query(query: str):
    response = client.embeddings.create(
        model = "text-embedding-3-small",
        input = query,
    )
    query_vector = response.data[0].embedding
    query_vector_bytes = np.array(query_vector, dtype=np.float32).tobytes() #encouraged by redis-vl to convert to bytes for storage and retrieval
    return query_vector_bytes

def get_context(query_embedding: bytes):
    vq = get_vector_query(query_embedding)
    results = index.query(vq)
    context = "\n\n".join(result["content"] for result in results)
    return {
        "context": context,
        "results": results
    }

def answer(query: str, history: Optional[List[HistoryTurn]] = None) -> str:
    start = time.time()
    retrieval_query = rewrite_query_with_history(query, history)

    embedding = embed_query(retrieval_query)
    context_object = get_context(embedding)
    context = context_object["context"]
    results = context_object["results"]
    response = generate_response(query, context, history)

    latency = time.time() - start
    logger.info({
        "query": query,
        "retrieval_query": retrieval_query,
        "documents_retrieved": len(results),
        "distances": [
            r["vector_distance"]
            for r in results
        ],
        "latency_seconds": latency,
        "tokens": response["usage"]
    })
    return response["answer"]


