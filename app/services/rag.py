import numpy as np
from openai import OpenAI
from app.config import openai_api_key
from pydantic import BaseModel
from redis_client import get_redis_client, get_index, get_vector_query
from app.services.llm import generate_response

#user query > embedding > search redis > get context > send to openai > get answer
class userQuery(BaseModel):
    query: str

client = OpenAI(api_key=openai_api_key)
redis_db = get_redis_client()
index = get_index()
index.connect(redis_db)

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
    results = index.search(vq)
    context = "\n\n".join(result["content"] for result in results)
    return context

def answer(query: str) -> str:
    embedding = embed_query(query)
    context = get_context(embedding)
    answer = generate_response(query, context)
    return answer


