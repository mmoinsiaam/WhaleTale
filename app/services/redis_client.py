import redis
from app.config import redis_url

def get_redis_client():
    return redis.Redis(host=redis_url, port=6379, decode_responses=True)

def search(query_embedding):
    return redis.ft("marine_bio_chunks").search(query_embedding)