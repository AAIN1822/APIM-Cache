"""
Load the static PDF from disk into ChromaDB at startup (no upload API).
"""

import logging
from pathlib import Path

from app.config import STATIC_DOCUMENT_ID, STATIC_PDF_PATH
from app.ingestion.pipeline import ingest_pdf
from app.vectorstore.chroma_store import delete_document_chunks

logger = logging.getLogger(__name__)

# Project root = parent of app/
_PROJECT_ROOT = Path(__file__).resolve().parent.parent


def load_static_pdf_into_chroma() -> None:
    path = Path(STATIC_PDF_PATH)
    if not path.is_absolute():
        path = _PROJECT_ROOT / path
    if not path.is_file():
        raise FileNotFoundError(f"Static PDF not found: {path}")

    delete_document_chunks(STATIC_DOCUMENT_ID)
    with open(path, "rb") as f:
        ingest_pdf(document_id=STATIC_DOCUMENT_ID, file_bytes=f.read())
    logger.info("Static PDF indexed: %s -> document_id=%s", path, STATIC_DOCUMENT_ID)
