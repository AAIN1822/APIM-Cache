"""
Query against the static indexed PDF. document_id optional (defaults to STATIC_DOCUMENT_ID).
"""

import logging

from fastapi import APIRouter, Query
from pydantic import BaseModel

from app.config import STATIC_DOCUMENT_ID
from app.rag.chain import answer_question
from app.vectorstore.chroma_store import get_all_chunks

router = APIRouter()
logger = logging.getLogger(__name__)


class QueryRequest(BaseModel):
    question: str
    document_id: str | None = None


@router.post("/query")
async def query_document(req: QueryRequest):
    doc_id = req.document_id or STATIC_DOCUMENT_ID
    answer, source = answer_question(question=req.question, document_id=doc_id)
    logger.info("Query | source=%s", source)
    return {"answer": answer, "source": source}


@router.get("/chunks")
async def list_chunks(document_id: str | None = Query(None)):
    """Return all chunks stored in ChromaDB for the document (default: static PDF)."""
    doc_id = document_id or STATIC_DOCUMENT_ID
    chunks = get_all_chunks(document_id=doc_id)
    return {"document_id": doc_id, "count": len(chunks), "chunks": chunks}
