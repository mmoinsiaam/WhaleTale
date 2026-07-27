import redis
from app.config import redis_url, index_name

def get_redis_client():
    return redis.Redis.from_url(redis_url, decode_responses=True)

def search(index, query_embedding): #boilerplate
    return 0