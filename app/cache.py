"""
Redis cache layer: exact-key cache (legacy) and semantic Q&A cache.

- Exact key: same (document_id, question) → return cached answer.
- Semantic: similar question (embedding cosine similarity above threshold) → return cached answer.
  Stores: question, question_embedding, answer, source_chunks per document_id.
"""

import hashlib
import json
import logging
import math
from typing import Any

import numpy as np

from app.config import (
    CACHE_SIMILARITY_THRESHOLD,
    CACHE_TTL_SECONDS,
    REDIS_URL,
)

logger = logging.getLogger(__name__)


_redis_client: Any = None
_connection_tried: bool = False


def _get_redis():
    """Return Redis client if available; otherwise None. Connects at most once."""
    global _redis_client, _connection_tried
    if _redis_client is not None:
        return _redis_client
    if _connection_tried:
        return None
    _connection_tried = True
    try:
        import redis
        _redis_client = redis.from_url(
            REDIS_URL,
            decode_responses=True,
            socket_connect_timeout=2,
        )
        _redis_client.ping()
        logger.info("Redis cache connected: %s", REDIS_URL)
        return _redis_client
    except Exception as e:
        logger.warning("Redis unavailable, caching disabled: %s", e)
        _redis_client = None
        return None


def build_query_cache_key(document_id: str, question: str) -> str:
    normalized = question.strip().lower()
    q_hash = hashlib.sha256(normalized.encode("utf-8")).hexdigest()[:16]
    return f"rag:query:{document_id}:{q_hash}"


def cache_get(key: str) -> str | None:
    """
    Get value from Redis. Returns None on cache miss or if Redis is unavailable.
    """
    client = _get_redis()
    if client is None:
        return None
    try:
        value = client.get(key)
        return value
    except Exception as e:
        logger.warning("Redis get failed for key %s: %s", key, e)
        return None


def cache_set(key: str, value: str, ttl_seconds: int | None = None) -> bool:
    """
    Store value in Redis with TTL. Returns True if stored, False on error or Redis unavailable.
    """
    client = _get_redis()
    if client is None:
        return False
    ttl = ttl_seconds if ttl_seconds is not None else CACHE_TTL_SECONDS
    try:
        client.setex(key, ttl, value)
        return True
    except Exception as e:
        logger.warning("Redis set failed for key %s: %s", key, e)
        return False


def get_cached_query_response(document_id: str, question: str) -> dict | None:
    """
    Cache-Aside: try to get cached JSON response for this (document_id, question).
    Returns None on miss or if Redis is unavailable.
    """
    key = build_query_cache_key(document_id, question)
    raw = cache_get(key)
    if raw is None:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


def set_cached_query_response(document_id: str, question: str, response: dict, ttl_seconds: int | None = None) -> bool:
    """
    Cache-Aside: store API response in Redis for this (document_id, question).
    """
    key = build_query_cache_key(document_id, question)
    return cache_set(key, json.dumps(response), ttl_seconds=ttl_seconds)


# ---------- Semantic cache (question embedding + answer + source_chunks) ----------


def _cosine_similarity(a: list[float], b: list[float]) -> float:
    va = np.array(a, dtype=float)
    vb = np.array(b, dtype=float)
    n = np.linalg.norm(va) * np.linalg.norm(vb)
    if n == 0:
        return 0.0
    return float(np.dot(va, vb) / n)


def _semantic_cache_key(document_id: str) -> str:
    return f"rag:qa:{document_id}"


def store_semantic_cache(
    document_id: str,
    question: str,
    question_embedding: list[float],
    answer: str,
    source_chunks: list[str],
) -> bool:
    """Append one Q&A entry to the document's semantic cache list in Redis."""
    client = _get_redis()
    if client is None:
        return False
    key = _semantic_cache_key(document_id)
    entry = {
        "question": question,
        "question_embedding": question_embedding,
        "answer": answer,
        "source_chunks": source_chunks,
    }
    try:
        raw = client.get(key)
        items: list[dict[str, Any]] = json.loads(raw) if raw else []
        items.append(entry)
        client.setex(key, CACHE_TTL_SECONDS, json.dumps(items))
        return True
    except Exception as e:
        logger.warning("Redis semantic cache set failed: %s", e)
        return False


def check_semantic_cache(
    document_id: str,
    question_embedding: list[float],
    threshold: float | None = None,
) -> dict[str, Any] | None:
    """
    Find a cached Q&A whose question_embedding is most similar to the given one.
    Returns the cached entry (with "answer", "source_chunks", etc.) if best similarity >= threshold.
    """
    client = _get_redis()
    if client is None:
        return None
    th = threshold if threshold is not None else CACHE_SIMILARITY_THRESHOLD
    key = _semantic_cache_key(document_id)
    try:
        raw = client.get(key)
        if not raw:
            return None
        items: list[dict[str, Any]] = json.loads(raw)
    except Exception as e:
        logger.warning("Redis semantic cache get failed: %s", e)
        return None

    best_entry: dict[str, Any] | None = None
    best_score = -math.inf
    for item in items:
        emb = item.get("question_embedding")
        if not emb:
            continue
        score = _cosine_similarity(question_embedding, emb)
        if score > best_score:
            best_score = score
            best_entry = item

    if best_entry is not None and best_score >= th:
        logger.info("Semantic cache HIT | doc=%s | score=%.3f", document_id, best_score)
        return best_entry
    return None
