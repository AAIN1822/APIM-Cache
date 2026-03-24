"""
Ingestion pipeline: single PDF → load, chunk, embed, store in ChromaDB.
No Blob or Cosmos; one document_id per upload.
"""

import logging

from app.ingestion.pdf_loader import load_pdf
from app.ingestion.chunker import chunk_text
from app.ingestion.embedder import embed_texts
from app.vectorstore.chroma_store import store_in_chromadb

logger = logging.getLogger(__name__)


def ingest_pdf(document_id: str, file_bytes: bytes) -> None:
    """
    Process a single PDF: extract text, chunk, generate embeddings, store in ChromaDB.
    """
    text = load_pdf(file_bytes)
    if not text or not text.strip():
        raise ValueError("No text extracted from PDF")

    chunks = chunk_text(text)
    if not chunks:
        raise ValueError("No chunks produced from PDF")

    embeddings = embed_texts(chunks)
    store_in_chromadb(document_id=document_id, chunks=chunks, embeddings=embeddings)
    logger.info("Ingested document_id=%s (%d chunks)", document_id, len(chunks))
