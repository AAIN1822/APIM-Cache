"""
DEPRECATED: Replaced by ChromaDB (chroma_store.py).
Kept for reference only; not used by the application.
"""
import os
import uuid
from azure.cosmos import CosmosClient

COSMOS_CONNECTION_STRING = os.getenv("COSMOS_CONNECTION_STRING")
COSMOS_DB_NAME = os.getenv("COSMOS_DB_NAME")
COSMOS_CONTAINER_NAME = os.getenv("COSMOS_CONTAINER_NAME")

def get_container():
    client = CosmosClient.from_connection_string(COSMOS_CONNECTION_STRING)
    db = client.get_database_client(COSMOS_DB_NAME)
    return db.get_container_client(COSMOS_CONTAINER_NAME)

def document_exists(file_hash: str) -> bool:
    container = get_container()
    query = """
        SELECT VALUE COUNT(1)
        FROM c
        WHERE c.file_hash = @hash
    """
    params = [{"name": "@hash", "value": file_hash}]

    result = list(container.query_items(
        query=query,
        parameters=params,
        enable_cross_partition_query=True
    ))
    return result[0] > 0


def get_document_id_by_hash(file_hash: str) -> str | None:
    """Return the document_id for an already-indexed file_hash, or None if not found."""
    container = get_container()
    query = """
        SELECT TOP 1 c.document_id
        FROM c
        WHERE c.file_hash = @hash
    """
    params = [{"name": "@hash", "value": file_hash}]
    items = list(container.query_items(
        query=query,
        parameters=params,
        enable_cross_partition_query=True
    ))
    return items[0]["document_id"] if items else None

def store_vectors(chunks, embeddings, metadata):
    container = get_container()

    for text, vector in zip(chunks, embeddings):
        container.upsert_item({
            "id": str(uuid.uuid4()),
            "content": text,
            "embedding": vector,
            "document_id": metadata["document_id"],
            "file_hash": metadata["file_hash"],
            "source": metadata["source"]
        })

def search_vectors(document_id: str, top_k: int):
    container = get_container()
    query = """
        SELECT TOP @k c.content
        FROM c
        WHERE c.document_id = @doc
    """
    params = [
        {"name": "@k", "value": top_k},
        {"name": "@doc", "value": document_id}
    ]

    items = list(container.query_items(
        query=query,
        parameters=params,
        enable_cross_partition_query=True
    ))

    return [i["content"] for i in items]
