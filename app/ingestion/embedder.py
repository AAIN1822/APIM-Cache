from openai import AzureOpenAI
from app.config import (
    AZURE_OPENAI_KEY,
    AZURE_OPENAI_ENDPOINT,
    AZURE_OPENAI_EMBED_DEPLOYMENT
)

client = AzureOpenAI(
    api_key=AZURE_OPENAI_KEY,
    azure_endpoint=AZURE_OPENAI_ENDPOINT,
    api_version="2024-02-01"
)

# ---------- DOCUMENT EMBEDDING ----------
def embed_texts(texts: list[str]) -> list[list[float]]:
    """
    Used ONLY during ingestion.
    """
    response = client.embeddings.create(
        model=AZURE_OPENAI_EMBED_DEPLOYMENT,
        input=texts
    )
    return [item.embedding for item in response.data]

# ---------- QUERY EMBEDDING ----------
def embed_text(text: str) -> list[float]:
    """
    Used ONLY during querying.
    Embeds a single question.
    """
    response = client.embeddings.create(
        model=AZURE_OPENAI_EMBED_DEPLOYMENT,
        input=[text]
    )
    return response.data[0].embedding
