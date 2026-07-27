import redis
from app.config import redis_url
from pathlib import Path
from redisvl.index import SearchIndex

BASE_DIR = Path(__file__).resolve().parent.parent.parent #
schema_path = BASE_DIR / "schema" / "index.yaml"

def get_redis_client():
    return redis.Redis.from_url(redis_url, decode_responses=True)

def get_index():
    index = SearchIndex.from_yaml(schema_path)
    return index