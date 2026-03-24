"""
Retrieve relevant chunks from ChromaDB using the question embedding.
"""

from app.ingestion.embedder import embed_text
from app.vectorstore.chroma_store import query_chromadb


def retrieve_context(
    question: str,
    document_id: str,
    top_k: int = 6,
) -> list[str]:
    """Return top_k chunk texts from ChromaDB for the document, ordered by similarity to question."""
    query_embedding = embed_text(question)
    return query_chromadb(
        document_id=document_id,
        query_embedding=query_embedding,
        top_k=top_k,
    )
