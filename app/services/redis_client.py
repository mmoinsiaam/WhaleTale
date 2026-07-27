import redis
from app.config import redis_url, index_name

def get_redis_client():
    return redis.Redis(host=redis_url, port=6379, decode_responses=True)

def search(redis_client, query_embedding):
    return redis_client.ft(index_name).search(query_embedding)