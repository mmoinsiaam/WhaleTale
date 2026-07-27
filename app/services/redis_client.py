import redis
from app.config import redis_url, index_name

def get_redis_client():
    return redis.Redis(host=redis_url, port=6379, decode_responses=True)

def search(query_embedding):
    return redis.ft(index_name).search(query_embedding)