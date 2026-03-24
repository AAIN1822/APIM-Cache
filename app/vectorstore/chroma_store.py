"""
ChromaDB vector store for document chunks and embeddings.
Replaces Cosmos DB for semantic search (single PDF per document_id).
"""

import logging
from pathlib import Path
from typing import List

import chromadb
from chromadb.config import Settings

from app.config import CHROMA_DB_DIR, CHROMA_COLLECTION_NAME

logger = logging.getLogger(__name__)

_path = Path(CHROMA_DB_DIR)
_path.mkdir(parents=True, exist_ok=True)

_client = chromadb.PersistentClient(
    path=str(_path),
    settings=Settings(anonymized_telemetry=False),
)


def _get_collection():
    return _client.get_or_create_collection(
        name=CHROMA_COLLECTION_NAME,
        metadata={"hnsw:space": "cosine"},
    )


def store_in_chromadb(
    document_id: str,
    chunks: List[str],
    embeddings: List[List[float]],
) -> None:
    """Store chunk texts and their embeddings in ChromaDB for one document."""
    if not chunks or not embeddings or len(chunks) != len(embeddings):
        raise ValueError("chunks and embeddings must be non-empty and same length")
    collection = _get_collection()
    ids = [f"{document_id}_{i}" for i in range(len(chunks))]
    metadatas = [{"document_id": document_id, "chunk_index": i} for i in range(len(chunks))]
    collection.add(
        ids=ids,
        documents=chunks,
        embeddings=embeddings,
        metadatas=metadatas,
    )
    logger.info("Stored %d chunks in ChromaDB for document_id=%s", len(chunks), document_id)


def get_all_chunks(document_id: str) -> List[dict]:
    """
    Return all stored chunks for a document as list of {chunk_index, text}.
    """
    collection = _get_collection()
    result = collection.get(
        where={"document_id": document_id},
        include=["documents", "metadatas"],
    )
    docs = result.get("documents") or []
    metadatas = result.get("metadatas") or []
    out = []
    for i, (text, meta) in enumerate(zip(docs, metadatas)):
        idx = meta.get("chunk_index", i) if meta else i
        out.append({"chunk_index": idx, "text": text})
    out.sort(key=lambda x: x["chunk_index"])
    return out


def delete_document_chunks(document_id: str) -> None:
    """Remove all chunks for a document (e.g. before re-indexing static PDF)."""
    collection = _get_collection()
    try:
        collection.delete(where={"document_id": document_id})
        logger.info("Deleted ChromaDB chunks for document_id=%s", document_id)
    except Exception as e:
        logger.warning("ChromaDB delete failed (may be empty): %s", e)


def query_chromadb(
    document_id: str,
    query_embedding: List[float],
    top_k: int = 6,
) -> List[str]:
    """Return top_k chunk texts most similar to query_embedding for the given document."""
    collection = _get_collection()
    result = collection.query(
        query_embeddings=[query_embedding],
        where={"document_id": document_id},
        n_results=min(top_k, 100),
        include=["documents"],
    )
    docs = result.get("documents")
    if not docs or not docs[0]:
        return []
    return list(docs[0])
