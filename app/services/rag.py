from openai import OpenAI
from app.config import openai_api_key
from pydantic import BaseModel
from redis_client import get_redis_client, search
from redisvl.query import VectorQuery

#user query > embedding > search redis > get context > send to openai > get answer
class userQuery(BaseModel):
    query: str

client = OpenAI(api_key=openai_api_key)
redis_db = get_redis_client()
index = SearchIndex.from_yaml(
    "schema/redis_index.yaml"
)

def embed_query(query: str):
    response = client.embeddings.create(
        model = "text-embedding-3-small",
        input = query,
    )

    return response.data[0].embedding





