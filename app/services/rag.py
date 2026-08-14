import time
import logging
from typing import List, Optional
import numpy as np
from openai import OpenAI
import json
from app.config import openai_api_key, redis_url
from app.services.redis_client import get_index, get_vector_query
from app.services.llm import generate_response, rewrite_query_with_history
from app.schema.models import HistoryTurn

#user query > embedding > search redis > get context > send to openai > get answer

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

    # vars needed for logs
    distances = [float(r["vector_distance"]) for r in results]
    avg_distance = sum(distances) / len(distances) if distances else 0.0
    prompt_t = response["usage"]["prompt_tokens"]
    completion_t = response["usage"]["completion_tokens"]
    total_t = response["usage"]["total_tokens"]

    latency = time.time() - start
    logger.info(json.dumps({    # emf format for cloudwatch metrics
        "_aws": {
            "Timestamp": int(time.time() * 1000),
            "CloudWatchMetrics": [
                {
                    "Namespace": "RAG/VectorSearch",
                    "Dimensions": [["Service"]],
                    "Metrics": [
                        {"Name": "latency_seconds", "Unit": "Seconds"},
                        {"Name": "documents_retrieved", "Unit": "Count"},
                        {"Name": "total_tokens", "Unit": "Count"},
                        {"Name": "AvgVectorDistance", "Unit": "None"}
                    ]
                }
            ]
        },
        "Service": "rag-api",
        "query": query,
        "retrieval_query": retrieval_query,
        "documents_retrieved": len(results),
        "distances": [
            r["vector_distance"]
            for r in results
        ],
        "latency_seconds": latency,
        "AvgVectorDistance": avg_distance,
        "tokens": {
            "prompt": prompt_t,
            "completion": completion_t,
            "total": total_t
        }
    }))

    return response["answer"]


