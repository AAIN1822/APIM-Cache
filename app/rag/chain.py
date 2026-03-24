"""
RAG chain: semantic cache check → ChromaDB retrieval → LLM → store in cache.
Returns (answer, source) where source is "Redis Cache" or "ChromaDB".
"""

import logging
from typing import Tuple

from openai import AzureOpenAI

from app.config import (
    AZURE_OPENAI_CHAT_DEPLOYMENT,
    AZURE_OPENAI_ENDPOINT,
    AZURE_OPENAI_KEY,
)
from app.ingestion.embedder import embed_text
from app.rag.prompt import build_prompt
from app.rag.retriever import retrieve_context
from app.cache import check_semantic_cache, store_semantic_cache

logger = logging.getLogger(__name__)

_client = AzureOpenAI(
    api_key=AZURE_OPENAI_KEY,
    azure_endpoint=AZURE_OPENAI_ENDPOINT,
    api_version="2024-02-01",
)


def answer_question(question: str, document_id: str) -> Tuple[str, str]:
    """
    Run RAG: check Redis semantic cache → on miss, query ChromaDB → LLM → store in cache.
    Returns (answer, source) with source in {"Redis Cache", "ChromaDB"}.
    """
    q_embedding = embed_text(question)

    # 1) Semantic cache lookup (paraphrases count as hit)
    cached = check_semantic_cache(document_id=document_id, question_embedding=q_embedding)
    if cached:
        return (cached["answer"], "Redis Cache")

    # 2) Retrieve from ChromaDB
    chunks = retrieve_context(question=question, document_id=document_id, top_k=6)
    if not chunks:
        return (
            "No relevant information found in the uploaded document.",
            "ChromaDB",
        )

    context = "\n\n".join(chunks)
    prompt = build_prompt(context, question)

    # 3) LLM
    response = _client.chat.completions.create(
        model=AZURE_OPENAI_CHAT_DEPLOYMENT,
        messages=[
            {"role": "system", "content": "You are a helpful assistant. Answer ONLY using the provided context."},
            {"role": "user", "content": prompt},
        ],
        temperature=0.2,
    )
    answer = response.choices[0].message.content.strip()

    # 4) Store in semantic cache for future/paraphrased questions
    if not store_semantic_cache(
        document_id=document_id,
        question=question,
        question_embedding=q_embedding,
        answer=answer,
        source_chunks=chunks,
    ):
        logger.warning(
            "Semantic cache NOT stored (Redis down?). Next question will use ChromaDB again."
        )

    return (answer, "ChromaDB")
